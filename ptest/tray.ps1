$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$D = Join-Path $env:RUNNER_TEMP 'tnbc'; New-Item -ItemType Directory -Force $D | Out-Null
Copy-Item windows\status-tray.ps1 $D
$now = Get-Date
function J($o, $f) { [IO.File]::WriteAllText((Join-Path $D $f), ($o | ConvertTo-Json -Compress)) }
J @{ version = '1.9.0'; part = 'audio'; state = 'running'; startedAt = $now.AddMinutes(-14).ToString('o'); current = 'Making audio: Ruth - Redeemed and Restored, Pt. 4'; audio = 3; reels = 0; lastProblem = 'Problem with Jonah 2: the download stopped (will try again)'; lastProblemAt = $now.AddHours(-5).ToString('o') } 'status.json'
J @{ version = '1.9.0'; part = 'reels'; state = 'running'; startedAt = $now.AddMinutes(-13).ToString('o'); current = 'Making reel #3: Faith That Works'; audio = 0; reels = 2 } 'status-reels.json'
J @{ version = '1.9.0'; part = 'posts'; state = 'running'; startedAt = $now.AddMinutes(-13).ToString('o'); current = 'Watching for new posts'; audio = 0; reels = 1 } 'status-posts.json'
$log = @()
$msgs = 'Program 1.9.0 starting.', 'Asked the manager: 12 sermons need audio.', 'Working on: Jonah 1 - Running From God', 'Done: Jonah 1 - Running From God (41:12)', 'Reels: making reel #1 from Faith That Works', 'Reel #1 made (18 s).', 'Posts: making the Question carousel for Nov 10', 'Made 5 files for the Question carousel.', 'Working on: Ruth - Redeemed and Restored, Pt. 4'
$i = 0; foreach ($m in $msgs) { $log += ('{0}  {1}' -f $now.AddMinutes(-14 + $i).ToString('yyyy-MM-dd HH:mm:ss'), $m); $i++ }
[IO.File]::WriteAllLines((Join-Path $D 'log.txt'), $log)
$sec = ConvertTo-SecureString 'tnbc-000000000000000000000000000000000000000000000000' -AsPlainText -Force | ConvertFrom-SecureString
J @{ server = 'http://127.0.0.1:8787'; code = $sec } 'config.json'

# fake manager
Start-Process node -ArgumentList 'ptest\overview-fake.js' -WindowStyle Hidden
# hold the three parts' mutexes, like a real run
$hold = Join-Path $env:RUNNER_TEMP 'hold.ps1'
Set-Content $hold @'
$a = New-Object Threading.Mutex($false, 'Local\TNBCSermonAudio'); [void]$a.WaitOne()
$b = New-Object Threading.Mutex($false, 'Local\TNBCSermonAudio-reels'); [void]$b.WaitOne()
$c = New-Object Threading.Mutex($false, 'Local\TNBCSermonAudio-posts'); [void]$c.WaitOne()
Start-Sleep 600
'@
$holder = Start-Process powershell -ArgumentList '-NoProfile', '-File', $hold -PassThru -WindowStyle Hidden
Start-Sleep 3

$env:TNBC_TRAY_SNAP = Join-Path $PWD 'full.png'
$tray = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', (Join-Path $D 'status-tray.ps1'), '-Show' -PassThru -RedirectStandardError (Join-Path $PWD 'tray-err.txt') -RedirectStandardOutput (Join-Path $PWD 'tray-out.txt')
function Shot($name) {
  $s = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $b = New-Object Drawing.Bitmap $s.Width, $s.Height
  $g = [Drawing.Graphics]::FromImage($b); $g.CopyFromScreen($s.Location, [Drawing.Point]::Empty, $s.Size); $g.Dispose()
  $b.Save((Join-Path $PWD $name)); Write-Host "shot $name $($s.Width)x$($s.Height)"
}
Start-Sleep 14
Shot 'working.png'; Copy-Item full.png full-working.png
Write-Host ('tray alive: ' + -not $tray.HasExited)

# a second start with -Show only signals the first one and leaves
$second = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', (Join-Path $D 'status-tray.ps1'), '-Show' -PassThru
$second.WaitForExit(15000) | Out-Null
Write-Host ('second copy left: ' + $second.HasExited)

# idle with a fresh problem
Stop-Process -Id $holder.Id -Force
J @{ version = '1.9.0'; part = 'audio'; state = 'done'; startedAt = $now.AddMinutes(-30).ToString('o'); finishedAt = (Get-Date).ToString('o'); current = $null; audio = 4; reels = 0; summary = '4 sermons made'; lastProblem = 'Reel problem: ffmpeg could not read the video'; lastProblemAt = (Get-Date).AddMinutes(-20).ToString('o') } 'status.json'
Start-Sleep 8
Shot 'idle.png'; Copy-Item full.png full-idle.png
$lnk = Join-Path ([Environment]::GetFolderPath('Programs')) 'TNBC Sermon Manager.lnk'
Write-Host ('start menu shortcut: ' + (Test-Path $lnk)); Write-Host ('desktop shortcut: ' + (Test-Path (Join-Path ([Environment]::GetFolderPath('Desktop')) 'TNBC Sermon Manager.lnk')))
Write-Host ('ico: ' + (Test-Path (Join-Path $D 'manager.ico')))
Write-Host '--- tray stderr ---'; Get-Content tray-err.txt -ErrorAction SilentlyContinue | Select-Object -First 60
Write-Host '--- tray stdout ---'; Get-Content tray-out.txt -ErrorAction SilentlyContinue | Select-Object -First 30
Write-Host ('tray alive at end: ' + -not $tray.HasExited)
