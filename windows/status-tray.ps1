# True North Baptist Church - Sermon audio: status icon by the clock (notification area)
#
# Shows at a glance whether the sermon audio / reels program is working, idle, or had a problem.
# Click the icon for details (what it's doing now, recent activity) and buttons for Run now, the log and the
# YouTube Manager. Started automatically when you sign in; the main program (sermon-audio.ps1) installs and
# updates this file by itself. "Hide until tomorrow" in its menu takes it away for the day.
#
# TrayVersion 1.1.0

$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Me = $MyInvocation.MyCommand.Path
$StatusFile = Join-Path $Dir 'status.json'
$LogFile = Join-Path $Dir 'log.txt'
$TaskName = 'TNBC Sermon Audio'
$Manager = 'https://youtube-manager.truenorthbaptist1.workers.dev'

# Only one icon at a time
$trayMutex = New-Object System.Threading.Mutex($false, 'Local\TNBCSermonAudioTray')
if (-not $trayMutex.WaitOne(0)) { exit 0 }
$myStamp = (Get-Item $Me).LastWriteTime

function Part-Running([string]$name) {
  # each part holds its own mutex while it runs (open the handle only for a moment)
  $m = $null
  if ([System.Threading.Mutex]::TryOpenExisting($name, [ref]$m)) { $m.Dispose(); return $true }
  return $false
}
function Is-Running {
  return (Part-Running 'Local\TNBCSermonAudio') -or (Part-Running 'Local\TNBCSermonAudio-reels') -or (Part-Running 'Local\TNBCSermonAudio-posts')
}

function Read-Status {
  try { return (Get-Content $StatusFile -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return $null }
}
# the reels and posts helpers (program 1.5.0+) each keep their own status file
function Read-Helper([string]$part) {
  try { return (Get-Content (Join-Path $Dir "status-$part.json") -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return $null }
}
function Now-Lines {
  $out = @()
  $s = Read-Status
  if ((Part-Running 'Local\TNBCSermonAudio') -and $s -and $s.state -eq 'running' -and $s.current) { $out += 'Audio: ' + $s.current }
  foreach ($p in @('reels', 'posts')) {
    $h = Read-Helper $p
    if ((Part-Running "Local\TNBCSermonAudio-$p") -and $h -and $h.current) { $out += $(if ($p -eq 'reels') { 'Reels: ' } else { 'Posts: ' }) + $h.current }
  }
  return $out
}
# the newest problem from any part
function Last-Problem {
  $best = $null
  foreach ($x in @((Read-Status), (Read-Helper 'reels'), (Read-Helper 'posts'))) {
    if ($x -and $x.lastProblem -and $x.lastProblemAt -and (-not $best -or [datetime]::Parse($x.lastProblemAt) -gt [datetime]::Parse($best.lastProblemAt))) { $best = $x }
  }
  return $best
}

function When([string]$iso) {
  if (-not $iso) { return '' }
  try {
    $t = [datetime]::Parse($iso)
    if ($t.Date -eq (Get-Date).Date) { return $t.ToString('h:mm tt') }
    if ($t.Date -eq (Get-Date).Date.AddDays(-1)) { return 'yesterday ' + $t.ToString('h:mm tt') }
    return $t.ToString('MMM d, h:mm tt')
  } catch { return $iso }
}

function Next-Check {
  try { $i = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction Stop; if ($i.NextRunTime) { return $i.NextRunTime.ToString('h:mm tt') } } catch {}
  return $null
}

function Dot([System.Drawing.Color]$c) {
  $b = New-Object System.Drawing.Bitmap 16, 16
  $g = [System.Drawing.Graphics]::FromImage($b)
  $g.SmoothingMode = 'AntiAlias'
  $g.Clear([System.Drawing.Color]::Transparent)
  $g.FillEllipse((New-Object System.Drawing.SolidBrush $c), 1, 1, 14, 14)
  $g.DrawEllipse((New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 1.5), 1, 1, 13.5, 13.5)
  $g.Dispose()
  return [System.Drawing.Icon]::FromHandle($b.GetHicon())
}
$Green = [System.Drawing.Color]::FromArgb(46, 160, 67)
$Blue = [System.Drawing.Color]::FromArgb(40, 110, 220)
$Orange = [System.Drawing.Color]::FromArgb(230, 140, 20)
$Gray = [System.Drawing.Color]::FromArgb(130, 130, 130)
$Icons = @{ working = (Dot $Blue); ok = (Dot $Green); problem = (Dot $Orange); unknown = (Dot $Gray) }

# What to show: returns @{ kind; headline; detail }
function Summary {
  $s = Read-Status
  $running = Is-Running
  $lp = Last-Problem
  $problemToday = $lp -and ([datetime]::Parse($lp.lastProblemAt) -gt (Get-Date).AddHours(-3))
  if ($running) {
    $nl = @(Now-Lines)
    $now = if ($nl.Count) { $nl -join "`r`n" } else { 'Checking for work' }
    return @{ kind = 'working'; headline = 'Working'; detail = $now }
  }
  if (-not $s) { return @{ kind = 'unknown'; headline = 'Waiting for its first run'; detail = 'It runs a few minutes after you sign in, then every hour.' } }
  $ended = if ($s.finishedAt) { $s.finishedAt } else { (Get-Item $StatusFile).LastWriteTime.ToString('o') }
  $line = 'Last run ended ' + (When $ended)
  if ($s.summary) { $line += ': ' + $s.summary }
  if ($problemToday) { return @{ kind = 'problem'; headline = 'Idle, but there was a problem'; detail = $line } }
  return @{ kind = 'ok'; headline = 'Idle, all good'; detail = $line }
}

# ---------- the status window ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Sermon audio - True North Baptist Church'
$form.Size = New-Object System.Drawing.Size(620, 520)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.ShowInTaskbar = $true
$form.Icon = $Icons.ok
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)

$head = New-Object System.Windows.Forms.Label
$head.Location = '16,14'; $head.Size = '570,30'
$head.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
$form.Controls.Add($head)

$detail = New-Object System.Windows.Forms.Label
$detail.Location = '16,48'; $detail.Size = '570,64'
$form.Controls.Add($detail)

$info = New-Object System.Windows.Forms.Label
$info.Location = '16,114'; $info.Size = '570,64'
$info.ForeColor = [System.Drawing.Color]::FromArgb(90, 90, 90)
$form.Controls.Add($info)

$logLabel = New-Object System.Windows.Forms.Label
$logLabel.Location = '16,182'; $logLabel.Size = '300,20'; $logLabel.Text = 'Recent activity'
$logLabel.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10)
$form.Controls.Add($logLabel)

$log = New-Object System.Windows.Forms.TextBox
$log.Location = '16,204'; $log.Size = '572,212'
$log.Multiline = $true; $log.ReadOnly = $true; $log.ScrollBars = 'Vertical'; $log.WordWrap = $false
$log.Font = New-Object System.Drawing.Font('Consolas', 9)
$log.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($log)

function Button([string]$text, [int]$x, [scriptblock]$click) {
  $b = New-Object System.Windows.Forms.Button
  $b.Text = $text; $b.Location = "$x,430"; $b.Size = '134,34'
  $b.Add_Click($click)
  $form.Controls.Add($b)
  return $b
}
$runBtn = Button 'Run now' 16 { Run-Now }
[void](Button 'Open full log' 160 { Start-Process notepad.exe $LogFile })
[void](Button 'Manager page' 304 { Start-Process $Manager })
[void](Button 'Close' 454 { $form.Hide() })
$form.Add_FormClosing({ param($s, $e) if ($e.CloseReason -eq 'UserClosing') { $e.Cancel = $true; $form.Hide() } })

function Run-Now {
  if (Is-Running) { [System.Windows.Forms.MessageBox]::Show('It is already working. It will pick up everything waiting before it stops.', 'Sermon audio') | Out-Null; return }
  try { Start-ScheduledTask -TaskName $TaskName -ErrorAction Stop; $tray.ShowBalloonTip(3000, 'Sermon audio', 'Starting now.', 'Info') }
  catch { [System.Windows.Forms.MessageBox]::Show('Could not start it: ' + $_.Exception.Message, 'Sermon audio') | Out-Null }
}

function Refresh-Window {
  $sum = Summary
  $s = Read-Status
  $head.Text = $sum.headline
  $head.ForeColor = switch ($sum.kind) { 'working' { $Blue } 'ok' { $Green } 'problem' { $Orange } default { $Gray } }
  $detail.Text = $sum.detail
  $lines = @()
  $v = if ($s -and $s.version) { "Version $($s.version)" } else { 'Version unknown' }
  $nc = Next-Check
  $lines += $v + $(if ($nc) { " - runs every hour, next at $nc" } else { ' - runs every hour while the computer is on' })
  $hr = Read-Helper 'reels'; $hp = Read-Helper 'posts'
  $made = [int]$(if ($s) { $s.reels } else { 0 }) + [int]$(if ($hr -and $s -and $hr.startedAt -ge $s.startedAt) { $hr.reels } else { 0 }) + [int]$(if ($hp -and $s -and $hp.startedAt -ge $s.startedAt) { $hp.reels } else { 0 })
  if ($s -and $s.state -eq 'running') { $lines += "This run (started $(When $s.startedAt)): $($s.audio) sermon(s), $made reel(s) or post(s) so far" }
  $lp = Last-Problem
  if ($lp) { $lines += "Last problem ($(When $lp.lastProblemAt)): $($lp.lastProblem)" }
  $info.Text = $lines -join "`r`n"
  $runBtn.Enabled = $sum.kind -ne 'working'
  try {
    $tail = Get-Content $LogFile -Tail 40 -Encoding UTF8 -ErrorAction Stop
    $text = ($tail | ForEach-Object { $_ }) -join "`r`n"
    if ($log.Text -ne $text) { $log.Text = $text; $log.SelectionStart = $log.Text.Length; $log.ScrollToCaret() }
  } catch { $log.Text = '(no log yet)' }
}

function Show-Window { Refresh-Window; $form.Show(); $form.WindowState = 'Normal'; $form.Activate() }

# ---------- the icon ----------
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = $Icons.unknown
$tray.Text = 'Sermon audio'
$tray.Visible = $true
$menu = New-Object System.Windows.Forms.ContextMenuStrip
[void]$menu.Items.Add('Show status', $null, { Show-Window })
[void]$menu.Items.Add('Run now', $null, { Run-Now })
[void]$menu.Items.Add('Open full log', $null, { Start-Process notepad.exe $LogFile })
[void]$menu.Items.Add('Manager page', $null, { Start-Process $Manager })
[void]$menu.Items.Add('-')
[void]$menu.Items.Add('Hide until tomorrow', $null, {
    Set-Content -Path (Join-Path $Dir 'tray-off.txt') -Value (Get-Date -Format 'yyyy-MM-dd')
    $tray.Visible = $false
    [System.Windows.Forms.Application]::Exit()
  })
$tray.ContextMenuStrip = $menu
$tray.Add_MouseClick({ param($s, $e) if ($e.Button -eq 'Left') { Show-Window } })

$lastKind = ''
function Tick {
  # a newer copy of this file was installed: start it and leave
  try {
    if ((Get-Item $Me).LastWriteTime -ne $myStamp) {
      $tray.Visible = $false
      $trayMutex.ReleaseMutex()
      Start-Process powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-STA', '-File', "`"$Me`"") -WindowStyle Hidden
      [System.Windows.Forms.Application]::Exit()
      return
    }
  } catch {}
  $sum = Summary
  $tray.Icon = $Icons[$sum.kind]
  $tip = 'Sermon audio: ' + $sum.headline
  if ($sum.kind -eq 'working' -and $sum.detail) { $tip += ' - ' + ($sum.detail -replace "`r`n", ' / ') }
  if ($tip.Length -gt 63) { $tip = $tip.Substring(0, 60) + '...' }
  $tray.Text = $tip
  if ($script:lastKind -eq 'working' -and $sum.kind -eq 'problem') { $tray.ShowBalloonTip(5000, 'Sermon audio', $sum.detail, 'Warning') }
  $script:lastKind = $sum.kind
  if ($form.Visible) { Refresh-Window }
}
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000
$timer.Add_Tick({ Tick })
$timer.Start()
Tick

[System.Windows.Forms.Application]::Run()
$tray.Visible = $false
$tray.Dispose()
