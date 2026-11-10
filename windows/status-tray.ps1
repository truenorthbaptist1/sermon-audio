# True North Baptist Church - Sermon Manager on the home computer (status icon by the clock + its window)
#
# The coloured dot by the clock shows at a glance whether the program is working, idle, or had a problem.
# Click it (or open "TNBC Sermon Manager" from the Start menu or the desktop) for the window: what each part is
# doing right now, what is lined up next (asked from the manager), what waits for someone to review, recent
# activity, and buttons for Run now, Stop, and the manager page. It looks like the manager page online.
# Started automatically when you sign in; the main program (sermon-audio.ps1) installs and updates this file by
# itself. "Hide the icon until tomorrow" takes it away for the day.
#
# Keep this file plain ASCII: Windows PowerShell 5.1 reads scripts without a BOM as ANSI. Special characters are
# made with [char] codes or XML entities.
#
# TrayVersion 2.2.0
param([switch]$Show)

$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
try { Add-Type -AssemblyName WindowsFormsIntegration } catch {}
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

$Dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Me = $MyInvocation.MyCommand.Path
$StatusFile = Join-Path $Dir 'status.json'
$LogFile = Join-Path $Dir 'log.txt'
$TaskName = 'TNBC Sermon Audio'
$Manager = 'https://youtube-manager.truenorthbaptist1.workers.dev'
$Mid = [string][char]0x00B7      # middle dot
$Ell = [string][char]0x2026      # ...

# Only one icon at a time. Opening the shortcut while it runs just asks the running one to show its window.
$trayMutex = New-Object System.Threading.Mutex($false, 'Local\TNBCSermonAudioTray')
$got = $false
try { $got = $trayMutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $got = $true }
$showEvent = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::AutoReset, 'Local\TNBCSermonAudioTrayShow')
if (-not $got) { if ($Show) { [void]$showEvent.Set() }; exit 0 }
$myStamp = (Get-Item $Me).LastWriteTime

# ---------- reading the program's state ----------
function Part-Running([string]$name) {
  # each part holds its own mutex while it runs (open the handle only for a moment)
  $m = $null
  if ([System.Threading.Mutex]::TryOpenExisting($name, [ref]$m)) { $m.Dispose(); return $true }
  return $false
}
$MutexOf = @{ audio = 'Local\TNBCSermonAudio'; reels = 'Local\TNBCSermonAudio-reels'; posts = 'Local\TNBCSermonAudio-posts' }
function Is-Running { return (Part-Running $MutexOf.audio) -or (Part-Running $MutexOf.reels) -or (Part-Running $MutexOf.posts) }
function Read-Json([string]$path) { try { return (Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return $null } }
function Read-Status { return Read-Json $StatusFile }
function Read-Helper([string]$part) { return Read-Json (Join-Path $Dir "status-$part.json") }
function Read-Part([string]$part) { if ($part -eq 'audio') { return Read-Status } else { return Read-Helper $part } }

# the newest problem from any part
function Last-Problem {
  $best = $null
  foreach ($x in @((Read-Status), (Read-Helper 'reels'), (Read-Helper 'posts'))) {
    if ($x -and $x.lastProblem -and $x.lastProblemAt -and (-not $best -or [datetime]::Parse($x.lastProblemAt) -gt [datetime]::Parse($best.lastProblemAt))) { $best = $x }
  }
  return $best
}

# 2.1.0: say in plain words what a problem means. Returns @{ kind = internet|youtube|video|disk|other; head; text }
function Explain-Problem([string]$raw) {
  $r = [string]$raw
  $where = if ($r -match '^Could not ask|\(upload\)|workers\.dev') { 'the online manager' } elseif ($r -match 'youtube') { 'YouTube' } elseif ($r -match 'instagram|facebook|graph\.') { 'Instagram/Facebook' } else { 'the internet' }
  $job = if ($r -match '^Reel') { 'make the reel' } elseif ($r -match '\(upload\)') { 'send the finished sermon audio' } elseif ($r -match '^Could not ask') { 'ask what to work on next' } else { 'download the sermon video' }
  if ($r -match 'getaddrinfo failed|Failed to resolve|could not be resolved|No such host is known|Name or service not known|Temporary failure in name resolution|Unable to connect to the remote server|Network is unreachable|No connection could be made|No route to host') {
    return @{ kind = 'internet'; head = 'The internet was down'
      text = "This computer couldn't connect to $where, so it couldn't $job. That means the Wi-Fi or internet connection dropped. Nothing is wrong with the program or the sermon: it stopped for now and tries again at its next hourly check." }
  }
  if ($r -match 'timed out|forcibly closed|connection was closed|Connection reset|ConnectionResetError|Read timed out') {
    return @{ kind = 'internet'; head = 'The internet connection was too slow or cut out'
      text = "The connection to $where stopped partway through, so it couldn't $job. Usually the Wi-Fi was weak or dropped for a moment. It tries again at its next hourly check." }
  }
  if ($r -match 'confirm you.re not a bot|Sign in to confirm') {
    return @{ kind = 'youtube'; head = 'YouTube is blocking downloads for now'
      text = "YouTube asked this computer to prove it isn't a robot, so it stopped downloading. This usually clears up by itself within a day. If it keeps happening, lower 'Past sermons a day' on the manager page." }
  }
  if ($r -match 'HTTP Error 429|Too Many Requests') {
    return @{ kind = 'youtube'; head = 'YouTube is slowing down downloads'
      text = "YouTube said this computer was downloading too much too fast, so it stopped for now. It tries again at its next hourly check. If it keeps happening, lower 'Past sermons a day' on the manager page." }
  }
  if ($r -match 'Private video|Video unavailable|has been removed|This video is not available|members-only') {
    return @{ kind = 'video'; head = "That video can't be downloaded"
      text = "YouTube says this video is private, members-only or was removed, so there's nothing to download. Make it public on YouTube if it should have audio; otherwise it's skipped after a few tries." }
  }
  if ($r -match 'No space left|not enough space|disk is full|There is not enough space') {
    return @{ kind = 'disk'; head = "This computer's drive is full"
      text = "There isn't enough free space on this computer to work on the sermon. Free up some space (empty the Recycle Bin, delete old downloads), and it carries on at its next hourly check." }
  }
  if ($r -match 'Converting to MP3 failed') {
    return @{ kind = 'other'; head = "Couldn't make the MP3"
      text = "The video downloaded, but turning it into an MP3 didn't work. It tries this sermon again later. Details: $r" }
  }
  return @{ kind = 'other'; head = 'Last problem'; text = $r }
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

$FbStages = @{ download = 'Downloading from YouTube'; encode = 'Editing the video'; upload = 'Uploading to Facebook'; processing = 'Facebook is processing it' }
# What one part is doing: @{ state = working|watching|idle; text; pct (Facebook video only) }
function Part-State([string]$part) {
  $s = Read-Part $part
  if (Part-Running $MutexOf[$part]) {
    $cur = if ($s -and $s.current) { [string]$s.current } else { 'Starting' }
    # 2.2.0: the full Facebook video's progress, like the bar on the manager (program 1.9.8+ writes it)
    $fb = if ($s -and $s.fb -and $s.fb.stage) { @{ stage = [string]$s.fb.stage; pct = [int]$s.fb.pct } } else { $null }
    # a helper from before 1.9.8 doesn't write it: use the manager's figures (the window asks once a minute)
    if (-not $fb -and $part -eq 'posts' -and $script:Overview -and $script:Overview.facebook.progress) {
      $op = @($script:Overview.facebook.progress)[0]
      if ($op -and $op.stage) { $fb = @{ stage = [string]$op.stage; pct = [int]$op.pct }; if ($cur -notmatch '^Facebook video') { $cur = 'Facebook video: ' + [string]$op.title } }
    }
    if ($fb) {
      $label = if ($FbStages[$fb.stage]) { $FbStages[$fb.stage] } else { $fb.stage }
      return @{ state = 'working'; text = $cur + ' ' + $Mid + ' ' + $label + ' ' + $Mid + ' ' + $fb.pct + '%'; pct = $fb.pct }
    }
    if ($cur -match '^(Watching for new|Checking for) ') { return @{ state = 'watching'; text = 'Waiting for new work (it looks once a minute)' } }
    if ($cur -eq 'Starting') { return @{ state = 'working'; text = 'Starting' } }
    return @{ state = 'working'; text = $cur }
  }
  if ($s -and $s.finishedAt) { return @{ state = 'idle'; text = 'Not running ' + $Mid + ' last finished ' + (When $s.finishedAt) } }
  return @{ state = 'idle'; text = 'Not running' }
}

# The overall state: @{ kind; headline; detail }
function Summary {
  $s = Read-Status
  $lp = Last-Problem
  $problemRecent = $lp -and -not $lp.lastProblemFixedAt -and ([datetime]::Parse($lp.lastProblemAt) -gt (Get-Date).AddHours(-3))
  if (Is-Running) {
    $busy = @(@('audio', 'reels', 'posts') | Where-Object { (Part-State $_).state -eq 'working' })
    $what = if ($busy.Count) { 'Busy with: ' + (($busy | ForEach-Object { @{ audio = 'sermon audio'; reels = 'reels'; posts = 'posts and Facebook videos' }[$_] }) -join ', ') } else { 'Checking for work' }
    return @{ kind = 'working'; headline = 'Working on it'; detail = $what }
  }
  if (-not $s) { return @{ kind = 'unknown'; headline = 'Waiting for its first run'; detail = 'It runs a few minutes after you sign in, then every hour.' } }
  $ended = if ($s.finishedAt) { $s.finishedAt } else { (Get-Item $StatusFile).LastWriteTime.ToString('o') }
  $line = 'Last run ended ' + (When $ended)
  if ($s.summary) { $line += ': ' + $s.summary }
  if ($problemRecent) {
    $ex = Explain-Problem ([string]$lp.lastProblem)
    if ($ex.kind -eq 'internet') { return @{ kind = 'problem'; headline = 'Idle: the internet was down'; detail = $line } }
    return @{ kind = 'problem'; headline = 'Idle, but there was a problem'; detail = $line }
  }
  return @{ kind = 'ok'; headline = 'Idle, all good'; detail = $line }
}

# ---------- what is lined up (asked from the manager, without freezing the window) ----------
$Cfg = Read-Json (Join-Path $Dir 'config.json')
$Code = $null
try { $sec = $Cfg.code | ConvertTo-SecureString; $Code = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)) } catch {}
$Server = if ($Cfg -and $Cfg.server) { ([string]$Cfg.server).TrimEnd('/') } else { $Manager }
$Overview = $null; $OverviewAt = $null; $OverviewErr = $null; $OverviewTask = $null; $OverviewClient = $null
function Ask-Overview {
  if ($script:OverviewTask -or -not $Code) { return }
  try {
    $wc = New-Object System.Net.WebClient
    $wc.Encoding = [Text.Encoding]::UTF8
    $wc.Headers.Add('Authorization', "Bearer $Code")
    $script:OverviewClient = $wc
    $script:OverviewTask = $wc.DownloadStringTaskAsync($Server + '/api/pc/overview')
  } catch { $script:OverviewErr = $_.Exception.Message }
}
# called from the timer: picks up a finished answer (no callbacks into PowerShell from other threads)
function Take-Overview {
  $t = $script:OverviewTask
  if (-not $t -or -not $t.IsCompleted) { return $false }
  $script:OverviewTask = $null
  try { $script:OverviewClient.Dispose() } catch {}
  if ($t.IsFaulted -or $t.IsCanceled) { $script:OverviewErr = 'no answer'; return $true }
  try { $script:Overview = $t.Result | ConvertFrom-Json; $script:OverviewAt = Get-Date; $script:OverviewErr = $null } catch { $script:OverviewErr = 'unreadable answer' }
  return $true
}

# ---------- pictures ----------
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
$Icons = @{
  working = (Dot ([System.Drawing.Color]::FromArgb(40, 110, 220))); ok = (Dot ([System.Drawing.Color]::FromArgb(46, 160, 67)))
  problem = (Dot ([System.Drawing.Color]::FromArgb(230, 140, 20))); unknown = (Dot ([System.Drawing.Color]::FromArgb(130, 130, 130)))
}
# the manager's app icon: navy rounded square with a white play button
function Brand-Bitmap([int]$n, [int[]]$rgb = @(31, 58, 95)) {
  $b = New-Object System.Drawing.Bitmap $n, $n
  $g = [System.Drawing.Graphics]::FromImage($b)
  $g.SmoothingMode = 'AntiAlias'
  $g.Clear([System.Drawing.Color]::Transparent)
  $r = [int]($n * 0.22); $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $p.AddArc(0, 0, 2 * $r, 2 * $r, 180, 90); $p.AddArc($n - 2 * $r - 1, 0, 2 * $r, 2 * $r, 270, 90)
  $p.AddArc($n - 2 * $r - 1, $n - 2 * $r - 1, 2 * $r, 2 * $r, 0, 90); $p.AddArc(0, $n - 2 * $r - 1, 2 * $r, 2 * $r, 90, 90); $p.CloseFigure()
  $g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($rgb[0], $rgb[1], $rgb[2]))), $p)
  $tri = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF ($n * 0.38), ($n * 0.28)), (New-Object System.Drawing.PointF ($n * 0.38), ($n * 0.72)), (New-Object System.Drawing.PointF ($n * 0.74), ($n * 0.5)))
  $g.FillPolygon([System.Drawing.Brushes]::White, $tri)
  $g.Dispose()
  return $b
}
function To-WpfImage([System.Drawing.Bitmap]$b) {
  $ms = New-Object IO.MemoryStream
  $b.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); $ms.Position = 0
  $img = New-Object System.Windows.Media.Imaging.BitmapImage
  $img.BeginInit(); $img.CacheOption = 'OnLoad'; $img.StreamSource = $ms; $img.EndInit(); $img.Freeze()
  return $img
}

# ---------- Start menu and desktop shortcuts that open the window ----------
function Ensure-Shortcuts {
  try {
    $ico = Join-Path $Dir 'manager.ico'
    if (-not (Test-Path $ico)) {
      $ms = New-Object IO.MemoryStream; (Brand-Bitmap 256).Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); $png = $ms.ToArray()
      $out = New-Object IO.MemoryStream; $w = New-Object IO.BinaryWriter($out)
      $w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]1)
      $w.Write([byte]0); $w.Write([byte]0); $w.Write([byte]0); $w.Write([byte]0)
      $w.Write([uint16]1); $w.Write([uint16]32); $w.Write([uint32]$png.Length); $w.Write([uint32]22); $w.Write($png); $w.Flush()
      [IO.File]::WriteAllBytes($ico, $out.ToArray())
    }
    $ps = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $psArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File `"$Me`" -Show"
    $shell = New-Object -ComObject WScript.Shell
    $places = @(Join-Path ([Environment]::GetFolderPath('Programs')) 'TNBC Sermon Manager.lnk')
    # the desktop one only once: if it is deleted, it stays deleted
    $mark = Join-Path $Dir 'desktop-shortcut.txt'
    if (-not (Test-Path $mark)) { $places += (Join-Path ([Environment]::GetFolderPath('Desktop')) 'TNBC Sermon Manager.lnk'); Set-Content -Path $mark -Value (Get-Date -Format o) }
    foreach ($lnk in $places) {
      if ((Test-Path $lnk) -and ($shell.CreateShortcut($lnk).Arguments -eq $psArgs)) { continue }
      $sc = $shell.CreateShortcut($lnk)
      $sc.TargetPath = $ps; $sc.Arguments = $psArgs; $sc.WorkingDirectory = $Dir; $sc.IconLocation = "$ico,0"
      $sc.WindowStyle = 7; $sc.Description = 'Sermon Manager on this computer: what it is doing and what is coming up'
      $sc.Save()
    }
  } catch {}
}

# ---------- the window ----------
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
  Title="Sermon Manager - True North Baptist Church" Width="660" Height="880" MinWidth="520" MinHeight="420"
  WindowStartupLocation="CenterScreen" Background="#F6F7F9" FontFamily="Segoe UI" FontSize="14" Foreground="#1D2433"
  UseLayoutRounding="True" SnapsToDevicePixels="True" TextOptions.TextFormattingMode="Display">
  <Window.Resources>
    <Style x:Key="Card" TargetType="Border">
      <Setter Property="Background" Value="White"/><Setter Property="BorderBrush" Value="#E3E6EC"/><Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="14"/><Setter Property="Padding" Value="18,16"/><Setter Property="Margin" Value="0,0,0,14"/>
    </Style>
    <Style x:Key="H2" TargetType="TextBlock"><Setter Property="FontSize" Value="17"/><Setter Property="FontWeight" Value="SemiBold"/><Setter Property="Margin" Value="0,0,0,10"/></Style>
    <Style x:Key="Link" TargetType="TextBlock">
      <Setter Property="Foreground" Value="#1F3A5F"/><Setter Property="Cursor" Value="Hand"/><Setter Property="FontWeight" Value="SemiBold"/>
      <Style.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter Property="TextDecorations" Value="Underline"/></Trigger></Style.Triggers>
    </Style>
    <Style x:Key="Primary" TargetType="Button">
      <Setter Property="Foreground" Value="White"/><Setter Property="Background" Value="#1F3A5F"/><Setter Property="BorderBrush" Value="#1F3A5F"/>
      <Setter Property="Padding" Value="18,9"/><Setter Property="FontSize" Value="14"/><Setter Property="FontWeight" Value="SemiBold"/><Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template"><Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="B" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="10" Padding="{TemplateBinding Padding}">
            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="B" Property="Opacity" Value="0.88"/></Trigger>
            <Trigger Property="IsPressed" Value="True"><Setter TargetName="B" Property="Opacity" Value="0.72"/></Trigger>
            <Trigger Property="IsEnabled" Value="False"><Setter TargetName="B" Property="Opacity" Value="0.4"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value></Setter>
    </Style>
    <Style x:Key="Secondary" TargetType="Button" BasedOn="{StaticResource Primary}">
      <Setter Property="Foreground" Value="#1F3A5F"/><Setter Property="Background" Value="White"/>
    </Style>
  </Window.Resources>
  <DockPanel>
    <Border DockPanel.Dock="Top" Background="#1F3A5F" Padding="18,14">
      <DockPanel>
        <Border x:Name="HeadPill" DockPanel.Dock="Right" CornerRadius="99" Padding="12,5" VerticalAlignment="Center" Background="#2EFFFFFF">
          <StackPanel Orientation="Horizontal">
            <Ellipse x:Name="HeadDot" Width="9" Height="9" Margin="0,0,7,0" VerticalAlignment="Center" Fill="White"/>
            <TextBlock x:Name="HeadPillText" Foreground="White" FontWeight="SemiBold" FontSize="13"/>
          </StackPanel>
        </Border>
        <Image x:Name="Logo" DockPanel.Dock="Left" Width="36" Height="36" Margin="0,0,12,0"/>
        <StackPanel VerticalAlignment="Center">
          <TextBlock Text="Sermon Manager" Foreground="White" FontSize="19" FontWeight="SemiBold"/>
          <TextBlock x:Name="HeadSub" Foreground="#C9D4E4" FontSize="12.5"/>
        </StackPanel>
      </DockPanel>
    </Border>
    <ScrollViewer VerticalScrollBarVisibility="Auto">
      <StackPanel x:Name="Content" Margin="16,16,16,6">
        <Border x:Name="StatusCard" Style="{StaticResource Card}">
          <StackPanel>
            <TextBlock x:Name="StatusHead" FontSize="21" FontWeight="SemiBold"/>
            <TextBlock x:Name="StatusDetail" TextWrapping="Wrap" Margin="0,4,0,0"/>
            <TextBlock x:Name="StatusMeta" TextWrapping="Wrap" Foreground="#5B6475" FontSize="13" Margin="0,6,0,0"/>
            <WrapPanel Margin="0,14,0,0">
              <Button x:Name="RunBtn" Style="{StaticResource Primary}" Content="Run now" Margin="0,0,10,0"/>
              <Button x:Name="StopBtn" Style="{StaticResource Secondary}" Content="Stop this run"/>
            </WrapPanel>
          </StackPanel>
        </Border>
        <Border x:Name="ProblemCard" Visibility="Collapsed" Background="#FDECEC" BorderBrush="#9B1C1C" BorderThickness="4,0,0,0" CornerRadius="8" Padding="14,10" Margin="0,0,0,14">
          <StackPanel>
            <TextBlock x:Name="ProblemHead" FontWeight="SemiBold" Foreground="#9B1C1C"/>
            <TextBlock x:Name="ProblemText" TextWrapping="Wrap" Margin="0,3,0,0"/>
          </StackPanel>
        </Border>
        <Border Style="{StaticResource Card}">
          <StackPanel>
            <TextBlock Text="In progress" Style="{StaticResource H2}"/>
            <StackPanel x:Name="Parts"/>
            <TextBlock x:Name="RunCounts" Foreground="#5B6475" FontSize="13" Margin="0,8,0,0" TextWrapping="Wrap"/>
          </StackPanel>
        </Border>
        <Border Style="{StaticResource Card}">
          <StackPanel>
            <DockPanel>
              <TextBlock x:Name="QueueWhen" DockPanel.Dock="Right" Foreground="#5B6475" FontSize="12.5" VerticalAlignment="Top" Margin="0,3,0,0"/>
              <TextBlock Text="Coming up for this computer" Style="{StaticResource H2}"/>
            </DockPanel>
            <StackPanel x:Name="Queue"/>
          </StackPanel>
        </Border>
        <Border Style="{StaticResource Card}">
          <StackPanel>
            <TextBlock Text="Waiting for you" Style="{StaticResource H2}"/>
            <StackPanel x:Name="Review"/>
            <WrapPanel Margin="0,12,0,0">
              <Button x:Name="ReviewBtn" Style="{StaticResource Primary}" Content="Review now" Margin="0,0,10,0"/>
              <Button x:Name="ManagerBtn" Style="{StaticResource Secondary}" Content="Open the manager page"/>
            </WrapPanel>
          </StackPanel>
        </Border>
        <Border Style="{StaticResource Card}">
          <StackPanel>
            <DockPanel>
              <TextBlock x:Name="LogLink" DockPanel.Dock="Right" Text="Open full log" Style="{StaticResource Link}" FontSize="13" Margin="0,3,0,0"/>
              <TextBlock Text="Recent activity" Style="{StaticResource H2}"/>
            </DockPanel>
            <StackPanel x:Name="Activity"/>
          </StackPanel>
        </Border>
        <DockPanel Margin="4,0,4,10">
          <TextBlock x:Name="HideLink" DockPanel.Dock="Right" Text="Hide the icon until tomorrow" Style="{StaticResource Link}" FontWeight="Normal" FontSize="12.5"/>
          <TextBlock x:Name="Foot" Foreground="#5B6475" FontSize="12.5"/>
        </DockPanel>
      </StackPanel>
    </ScrollViewer>
  </DockPanel>
</Window>
'@
$win = [Windows.Markup.XamlReader]::Parse($xaml)
$UI = @{}
foreach ($n in 'HeadPill', 'HeadDot', 'HeadPillText', 'Logo', 'HeadSub', 'StatusCard', 'StatusHead', 'StatusDetail', 'StatusMeta', 'RunBtn', 'StopBtn', 'ProblemCard', 'ProblemHead', 'ProblemText',
  'Parts', 'RunCounts', 'Content', 'QueueWhen', 'Queue', 'Review', 'ReviewBtn', 'ManagerBtn', 'LogLink', 'Activity', 'HideLink', 'Foot') { $UI[$n] = $win.FindName($n) }
$brandImg = To-WpfImage (Brand-Bitmap 64)
$win.Icon = $brandImg
$UI.Logo.Source = To-WpfImage (Brand-Bitmap 72 @(58, 92, 138))   # a lighter square so it shows on the navy header
$UI.HeadSub.Text = 'Home computer ' + $Mid + ' ' + $env:COMPUTERNAME
try { [System.Windows.Forms.Integration.ElementHost]::EnableModelessKeyboardInterop($win) } catch {}

$Conv = New-Object System.Windows.Media.BrushConverter
function B([string]$hex) { return $Conv.ConvertFromString($hex) }
$Muted = B '#5B6475'
$Kinds = @{
  working = @{ bg = '#EAF1FB'; line = '#C3D5EE'; ink = '#1F3A5F'; dot = '#4D9BFF'; pill = 'Working' }
  ok      = @{ bg = '#E9F6EE'; line = '#B9DFC6'; ink = '#1D6B3A'; dot = '#5BD17F'; pill = 'Idle' }
  problem = @{ bg = '#FFF6E5'; line = '#F1D29B'; ink = '#9A5B00'; dot = '#FFB547'; pill = 'Needs a look' }
  unknown = @{ bg = '#FFFFFF'; line = '#E3E6EC'; ink = '#5B6475'; dot = '#B8BFCC'; pill = 'Not started' }
}

function T([string]$text, [double]$size = 14, [string]$weight = 'Normal', $color = $null) {
  $t = New-Object System.Windows.Controls.TextBlock
  $t.Text = $text; $t.FontSize = $size; $t.TextWrapping = 'Wrap'
  if ($weight -ne 'Normal') { $t.FontWeight = [System.Windows.FontWeights]::$weight }
  if ($color) { $t.Foreground = $(if ($color -is [string]) { B $color } else { $color }) }
  return $t
}
function Pill([string]$text, [string]$bg, [string]$fg) {
  $b = New-Object System.Windows.Controls.Border
  $b.CornerRadius = New-Object System.Windows.CornerRadius 99
  $b.Padding = New-Object System.Windows.Thickness 10, 2, 10, 3
  $b.Background = B $bg; $b.VerticalAlignment = 'Top'
  $t = T $text 12 'SemiBold' $fg
  $t.TextWrapping = 'NoWrap'
  $b.Child = $t
  return $b
}
function Spot([string]$hex, [double]$size = 10) {
  $e = New-Object System.Windows.Shapes.Ellipse
  $e.Width = $size; $e.Height = $size; $e.Fill = B $hex; $e.VerticalAlignment = 'Top'
  $e.Margin = New-Object System.Windows.Thickness 0, 6, 12, 0
  return $e
}
function Rule {
  $r = New-Object System.Windows.Controls.Border
  $r.Height = 1; $r.Background = B '#E3E6EC'; $r.Margin = New-Object System.Windows.Thickness 0, 10, 0, 10
  return $r
}
function Add([System.Windows.Controls.Panel]$p, $child) { [void]$p.Children.Add($child) }

# one row: dot | title + text (+ list) | pill
function Row([string]$dot, [string]$title, [string]$text, $pill, [string[]]$items = @(), [int]$more = 0, [switch]$Busy, [int]$Pct = -1) {
  $d = New-Object System.Windows.Controls.DockPanel
  $d.LastChildFill = $true
  if ($pill) { [System.Windows.Controls.DockPanel]::SetDock($pill, 'Right'); Add $d $pill }
  $sp = Spot $dot; [System.Windows.Controls.DockPanel]::SetDock($sp, 'Left'); Add $d $sp
  $st = New-Object System.Windows.Controls.StackPanel
  Add $st (T $title 14.5 'SemiBold')
  if ($text) { $x = T $text 13.5 'Normal' $Muted; $x.Margin = New-Object System.Windows.Thickness 0, 1, 8, 0; Add $st $x }
  foreach ($i in $items) { $x = T ('    ' + $Mid + '  ' + $i) 13 'Normal' '#1D2433'; $x.Margin = New-Object System.Windows.Thickness 0, 2, 8, 0; Add $st $x }
  if ($more -gt 0) { $x = T ("    and $more more") 13 'Normal' $Muted; $x.Margin = New-Object System.Windows.Thickness 0, 2, 0, 0; Add $st $x }
  if ($Busy) {
    $pb = New-Object System.Windows.Controls.ProgressBar
    if ($Pct -ge 0) { $pb.Minimum = 0; $pb.Maximum = 100; $pb.Value = $Pct; $pb.Height = 8 } else { $pb.IsIndeterminate = $true; $pb.Height = 4 }
    $pb.Margin = New-Object System.Windows.Thickness 0, 7, 8, 0
    $pb.Foreground = B '#4D7FC0'; $pb.Background = B '#E6ECF4'; $pb.BorderThickness = New-Object System.Windows.Thickness 0
    Add $st $pb
  }
  Add $d $st
  return $d
}

# ---------- filling it in ----------
$Seen = @{}
function Changed([string]$key, [string]$value) { if ($script:Seen[$key] -eq $value) { return $false }; $script:Seen[$key] = $value; return $true }

function Fill-Status($sum) {
  $k = $Kinds[$sum.kind]
  $UI.StatusCard.Background = B $k.bg; $UI.StatusCard.BorderBrush = B $k.line
  $UI.StatusHead.Text = $sum.headline; $UI.StatusHead.Foreground = B $k.ink
  $UI.StatusDetail.Text = $sum.detail
  $UI.HeadPillText.Text = $k.pill; $UI.HeadDot.Fill = B $k.dot
  $s = Read-Status
  $nc = Next-Check
  $v = if ($s -and $s.version) { 'Program ' + $s.version } else { 'Program version unknown' }
  $UI.StatusMeta.Text = $v + ' ' + $Mid + ' ' + $(if ($sum.kind -eq 'working') { 'checks every hour while the computer is on' } elseif ($nc) { "next check at $nc" } else { 'checks every hour while the computer is on' })
  $UI.RunBtn.IsEnabled = $sum.kind -ne 'working'
  $UI.StopBtn.IsEnabled = $sum.kind -eq 'working'
  $lp = Last-Problem
  if ($lp -and ([datetime]::Parse($lp.lastProblemAt) -gt (Get-Date).AddHours(-24))) {
    $ex = Explain-Problem ([string]$lp.lastProblem)
    $UI.ProblemCard.Visibility = 'Visible'
    $head = $ex.head + ' ' + $Mid + ' ' + (When $lp.lastProblemAt)
    $text = $ex.text
    if ($lp.lastProblemFixedAt) {
      # something worked after it: say so, in green
      $ink = '#1E6B3A'; $bg = '#E9F6EE'
      $head += ' ' + $Mid + ' working again since ' + (When $lp.lastProblemFixedAt)
      $text += ' It has worked fine since then, so there is nothing to do.'
    } elseif ($ex.kind -eq 'internet') { $ink = '#8A5A00'; $bg = '#FFF5E0' }
    else { $ink = '#9B1C1C'; $bg = '#FDECEC' }
    $UI.ProblemCard.Background = B $bg; $UI.ProblemCard.BorderBrush = B $ink; $UI.ProblemHead.Foreground = B $ink
    $UI.ProblemHead.Text = $head
    $UI.ProblemText.Text = $text
    # the exact error stays one hover away (for Claude or anyone fixing it)
    $UI.ProblemCard.ToolTip = if ($ex.kind -ne 'other') { 'Exact error: ' + [string]$lp.lastProblem } else { $null }
  } else { $UI.ProblemCard.Visibility = 'Collapsed' }
}

$PartNames = [ordered]@{ audio = 'Sermon audio'; reels = 'Instagram reels'; posts = 'Posts and Facebook videos' }
function Fill-Parts {
  $rows = @()
  foreach ($p in $PartNames.Keys) { $ps = Part-State $p; $rows += @{ p = $p; st = $ps.state; text = $ps.text; pct = $(if ($null -ne $ps.pct) { [int]$ps.pct } else { -1 }) } }
  $s = Read-Status; $hr = Read-Helper 'reels'; $hp = Read-Helper 'posts'
  $counts = ''
  if ($s -and $s.state -eq 'running') {
    $made = [int]$s.reels + [int]$(if ($hr -and $hr.startedAt -ge $s.startedAt) { $hr.reels } else { 0 }) + [int]$(if ($hp -and $hp.startedAt -ge $s.startedAt) { $hp.reels } else { 0 })
    $counts = "This run (started $(When $s.startedAt)): $([int]$s.audio) sermon(s) and $made reel(s) or post(s) made so far"
  } elseif ($s -and $s.summary) { $counts = 'Last run: ' + $s.summary }
  if (-not (Changed 'parts' (($rows | ForEach-Object { $_.p + $_.st + $_.text }) -join '|'))) { $UI.RunCounts.Text = $counts; return }
  $UI.Parts.Children.Clear()
  $first = $true
  foreach ($r in $rows) {
    if (-not $first) { Add $UI.Parts (Rule) }; $first = $false
    switch ($r.st) {
      'working' { Add $UI.Parts (Row '#2E6EDC' $PartNames[$r.p] $r.text (Pill 'Working' '#EAF1FB' '#1F3A5F') -Busy -Pct $r.pct) }
      'watching' { Add $UI.Parts (Row '#7FA6D9' $PartNames[$r.p] $r.text (Pill 'Ready' '#EEF2F7' '#3D5577')) }
      default { Add $UI.Parts (Row '#B8BFCC' $PartNames[$r.p] $r.text (Pill 'Idle' '#F0F2F5' '#5B6475')) }
    }
  }
  $UI.RunCounts.Text = $counts
}

function Count-Pill([int]$n, [string]$word) {
  if ($n -le 0) { return (Pill 'none' '#F0F2F5' '#5B6475') }
  return (Pill "$n $word" '#EAF1FB' '#1F3A5F')
}
function Fill-Queue {
  $o = $script:Overview
  $UI.QueueWhen.Text = $(if ($script:OverviewAt) { 'updated ' + $script:OverviewAt.ToString('h:mm tt') } else { '' })
  $sig = if ($o) { $o | ConvertTo-Json -Depth 6 -Compress } elseif (-not $Code) { 'nocode' } else { 'err' + $script:OverviewErr }
  if (-not (Changed 'queue' $sig)) { return }
  $UI.Queue.Children.Clear(); $UI.Review.Children.Clear()
  if (-not $o) {
    $msg = if (-not $Code) { 'This computer has no manager code, so it cannot ask what is coming up.' } elseif ($script:OverviewErr) { 'The manager could not be reached just now (is the internet on?). It tries again in a minute.' } else { 'Asking the manager' + $Ell }
    Add $UI.Queue (T $msg 13.5 'Normal' $Muted)
    Add $UI.Review (T $msg 13.5 'Normal' $Muted)
    $UI.ReviewBtn.Visibility = 'Collapsed'
    return
  }
  $blocks = @(
    @{ t = 'Sermon audio'; now = @($o.audio.making); next = @($o.audio.next); n = [int]$o.audio.waiting; w = 'waiting'; extra = $(if ([int]$o.audio.failed) { "$($o.audio.failed) could not be made (see the manager)" } else { '' }) },
    @{ t = 'Instagram reels'; now = @($o.reels.making.items); next = @($o.reels.toMake.items); n = [int]$o.reels.toMake.count; w = 'to make'; extra = '' },
    @{ t = 'Scripture and question posts'; now = @($o.posts.making.items); next = @($o.posts.toMake.items); n = [int]$o.posts.toMake.count; w = 'to make'; extra = '' },
    @{ t = 'Full sermons for Facebook'; now = @($o.facebook.making.items); next = @($o.facebook.waiting.items); n = [int]$o.facebook.waiting.count; w = 'waiting'; extra = '' }
  )
  $first = $true
  $any = $false
  foreach ($bk in $blocks) {
    if (-not $first) { Add $UI.Queue (Rule) }; $first = $false
    $items = @(); foreach ($x in $bk.now) { if ($x) { $items += 'Now: ' + $x } }
    $shown = @($bk.next | Where-Object { $_ } | Select-Object -First 4)
    $items += $shown
    $more = [Math]::Max(0, $bk.n - $shown.Count)
    $text = if ($bk.n -eq 0 -and -not @($bk.now | Where-Object { $_ }).Count) { 'Nothing waiting' } elseif ($bk.extra) { $bk.extra } else { '' }
    if ($bk.n -gt 0 -or @($bk.now | Where-Object { $_ }).Count) { $any = $true }
    $dot = if (@($bk.now | Where-Object { $_ }).Count) { '#2E6EDC' } elseif ($bk.n -gt 0) { '#7FA6D9' } else { '#B8BFCC' }
    Add $UI.Queue (Row $dot $bk.t $text (Count-Pill $bk.n $bk.w) $items $more)
  }
  if ($any -and -not (Is-Running)) {
    $nc = Next-Check
    $x = T ('It picks these up at the next check' + $(if ($nc) { " ($nc)" } else { '' }) + ', or click Run now.') 13 'Normal' $Muted
    $x.Margin = New-Object System.Windows.Thickness 0, 12, 0, 0
    Add $UI.Queue $x
  }

  # waiting for a person
  $rr = [int]$o.review.reels.count; $rp = [int]$o.review.posts.count
  if ($rr + $rp -eq 0) {
    Add $UI.Review (Row '#5BD17F' 'Nothing to review' $(if ([int]$o.approved) { "$($o.approved) approved and waiting for their posting day" } else { 'New reels and posts show up here when they are ready.' }) $null)
    $UI.ReviewBtn.Visibility = 'Collapsed'
  } else {
    $items = @(@($o.review.reels.items) + @($o.review.posts.items) | Where-Object { $_ } | Select-Object -First 6)
    $parts = @(); if ($rr) { $parts += "$rr reel$(if ($rr -ne 1) { 's' })" }; if ($rp) { $parts += "$rp post$(if ($rp -ne 1) { 's' })" }
    $sub = if ([int]$o.approved) { "$($o.approved) more approved and waiting for their posting day" } else { 'Approve them on the manager before they go out.' }
    Add $UI.Review (Row '#FFB547' (($parts -join ' and ') + ' to review') $sub (Pill 'To review' '#FFF6E5' '#9A5B00') $items ([Math]::Max(0, $rr + $rp - $items.Count)))
    $UI.ReviewBtn.Visibility = 'Visible'
  }
}

function Fill-Activity {
  try { $tail = @(Get-Content $LogFile -Tail 30 -Encoding UTF8 -ErrorAction Stop) } catch { $tail = @() }
  if (-not (Changed 'log' ($tail -join "`n"))) { return }
  $UI.Activity.Children.Clear()
  if (-not $tail.Count) { Add $UI.Activity (T 'Nothing yet.' 13.5 'Normal' $Muted); return }
  [array]::Reverse($tail)
  $n = 0
  foreach ($line in $tail) {
    if ($n -ge 18) { break }
    if (-not $line.Trim()) { continue }
    $time = ''; $msg = $line
    if ($line -match '^(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)\s+(.*)$') { $time = When ([datetime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', $null).ToString('o')); $msg = $Matches[2] }
    $bad = $msg -match '(?i)problem|could not|failed|error'
    $good = $msg -match '^(Done:|Reel #\d+ made|Made \d+ file|Uploaded)'
    $d = New-Object System.Windows.Controls.DockPanel
    $d.Margin = New-Object System.Windows.Thickness 0, 0, 0, 7
    $tt = T $time 12.5 'Normal' $Muted; $tt.Width = 118; $tt.TextWrapping = 'NoWrap'
    [System.Windows.Controls.DockPanel]::SetDock($tt, 'Left'); Add $d $tt
    $mt = T $msg 13 $(if ($good) { 'SemiBold' } else { 'Normal' }) $(if ($bad) { '#9B1C1C' } elseif ($good) { '#1D6B3A' } else { '#1D2433' })
    Add $d $mt
    Add $UI.Activity $d
    $n++
  }
}

function Refresh-Window {
  $sum = Summary
  Fill-Status $sum
  Fill-Parts
  Fill-Queue
  Fill-Activity
  $UI.Foot.Text = 'True North Baptist Church ' + $Mid + ' this window updates by itself'
  # for the Windows test only: save the whole window content as a picture
  if ($env:TNBC_TRAY_SNAP) {
    try {
      $c = $UI.Content; $c.UpdateLayout()
      $rt = New-Object System.Windows.Media.Imaging.RenderTargetBitmap ([int]$c.ActualWidth + 32), ([int]$c.ActualHeight + 22), 96, 96, ([System.Windows.Media.PixelFormats]::Pbgra32)
      $dv = New-Object System.Windows.Media.DrawingVisual; $dc = $dv.RenderOpen()
      $dc.DrawRectangle((B '#F6F7F9'), $null, (New-Object System.Windows.Rect 0, 0, ($c.ActualWidth + 32), ($c.ActualHeight + 22)))
      $dc.DrawRectangle((New-Object System.Windows.Media.VisualBrush $c), $null, (New-Object System.Windows.Rect 16, 16, $c.ActualWidth, $c.ActualHeight)); $dc.Close()
      $rt.Render($dv)
      $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder; $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rt))
      $fs = [IO.File]::Create($env:TNBC_TRAY_SNAP); $enc.Save($fs); $fs.Close()
    } catch {}
  }
}

$LastAsk = [datetime]::MinValue
function Show-Window {
  $script:LastAsk = Get-Date; Ask-Overview
  Refresh-Window
  $wa = [System.Windows.SystemParameters]::WorkArea
  if ($win.Height -gt $wa.Height - 20) { $win.Height = $wa.Height - 20 }
  $win.Show(); $win.WindowState = 'Normal'; [void]$win.Activate()
}
$win.Add_Closing({ param($s, $e) $e.Cancel = $true; $win.Hide() })

# ---------- actions ----------
function Run-Now {
  if (Is-Running) { [System.Windows.MessageBox]::Show('It is already working. It will pick up everything waiting before it stops.', 'Sermon Manager') | Out-Null; return }
  try { Start-ScheduledTask -TaskName $TaskName -ErrorAction Stop; $tray.ShowBalloonTip(3000, 'Sermon Manager', 'Starting now.', 'Info') }
  catch { [System.Windows.MessageBox]::Show('Could not start it: ' + $_.Exception.Message, 'Sermon Manager') | Out-Null }
}

# Stop: ends all three parts and the programs they started (ffmpeg, yt-dlp), then tells the manager, which hands
# any half-made sermon, reel or post straight back so the next run starts it again.
function Stop-Run {
  if (-not (Is-Running)) { return }
  $ok = [System.Windows.MessageBox]::Show('Stop what it is doing now? Anything half-made goes back on the list for the next run.', 'Sermon Manager', 'YesNo', 'Question')
  if ([string]$ok -ne 'Yes') { return }
  $procs = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -match 'sermon-audio\.ps1' })
  $ids = @($procs | ForEach-Object { [int]$_.ProcessId })
  $kids = @(Get-CimInstance Win32_Process | Where-Object { $ids -contains [int]$_.ParentProcessId })
  foreach ($p in $ids) { Stop-Process -Id $p -Force -ErrorAction SilentlyContinue }
  foreach ($k in $kids) { Stop-Process -Id ([int]$k.ProcessId) -Force -ErrorAction SilentlyContinue }
  $now = Get-Date -Format o
  foreach ($f in @('status.json', 'status-reels.json', 'status-posts.json')) {
    $path = Join-Path $Dir $f
    try {
      $x = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($x.state -eq 'running') {
        $x.state = 'stopped'; $x.current = $null
        $x | Add-Member -NotePropertyName finishedAt -NotePropertyValue $now -Force
        $x | Add-Member -NotePropertyName summary -NotePropertyValue 'stopped from the status window' -Force
        [IO.File]::WriteAllText($path, ($x | ConvertTo-Json -Compress), (New-Object Text.UTF8Encoding($false)))
      }
    } catch {}
  }
  $msg = 'Stopped.'
  try {
    $r = Invoke-RestMethod -Method Post -Uri ($Server + '/api/pc/release') -Headers @{ Authorization = "Bearer $Code" } -ContentType 'application/json' -Body '{}' -TimeoutSec 30
    if ($r.released) { $msg = "Stopped. $($r.released) half-made item(s) went back on the list." }
  } catch { $msg = 'Stopped. (The manager could not be told; half-made items come back on their own within 30 minutes.)' }
  try { [IO.File]::AppendAllText($LogFile, ('{0}  Stopped from the status window. {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) + "`r`n", (New-Object Text.UTF8Encoding($false))) } catch {}
  $tray.ShowBalloonTip(4000, 'Sermon Manager', $msg, 'Info')
  $script:LastAsk = Get-Date; Ask-Overview
  Refresh-Window
}
function Hide-Today {
  Set-Content -Path (Join-Path $Dir 'tray-off.txt') -Value (Get-Date -Format 'yyyy-MM-dd')
  $tray.Visible = $false
  $win.Hide()
  [System.Windows.Forms.Application]::Exit()
}

$UI.RunBtn.Add_Click({ Run-Now; Refresh-Window })
$UI.StopBtn.Add_Click({ Stop-Run })
$UI.ReviewBtn.Add_Click({ Start-Process ($Manager + '/review') })
$UI.ManagerBtn.Add_Click({ Start-Process $Manager })
$UI.LogLink.Add_MouseLeftButtonUp({ Start-Process notepad.exe $LogFile })
$UI.HideLink.Add_MouseLeftButtonUp({ Hide-Today })

# ---------- the icon ----------
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = $Icons.unknown
$tray.Text = 'Sermon Manager'
$tray.Visible = $true
$menu = New-Object System.Windows.Forms.ContextMenuStrip
[void]$menu.Items.Add('Open the Sermon Manager window', $null, { Show-Window })
[void]$menu.Items.Add('Run now', $null, { Run-Now })
[void]$menu.Items.Add('Stop this run', $null, { Stop-Run })
[void]$menu.Items.Add('Review reels and posts', $null, { Start-Process ($Manager + '/review') })
[void]$menu.Items.Add('Manager page', $null, { Start-Process $Manager })
[void]$menu.Items.Add('Open full log', $null, { Start-Process notepad.exe $LogFile })
[void]$menu.Items.Add('-')
[void]$menu.Items.Add('Hide the icon until tomorrow', $null, { Hide-Today })
$tray.ContextMenuStrip = $menu
$tray.Add_MouseClick({ param($s, $e) if ($e.Button -eq 'Left') { Show-Window } })

$lastKind = ''
function Tick {
  # a newer copy of this file was installed: start it (showing the window again if it was open) and leave
  try {
    if ((Get-Item $Me).LastWriteTime -ne $myStamp) {
      $tray.Visible = $false
      $trayMutex.ReleaseMutex()
      $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-STA', '-File', "`"$Me`"")
      if ($win.IsVisible) { $a += '-Show' }
      Start-Process powershell.exe -ArgumentList $a -WindowStyle Hidden
      [System.Windows.Forms.Application]::Exit()
      return
    }
  } catch {}
  $sum = Summary
  $tray.Icon = $Icons[$sum.kind]
  $tip = 'Sermon Manager: ' + $sum.headline
  if ($tip.Length -gt 63) { $tip = $tip.Substring(0, 60) + '...' }
  $tray.Text = $tip
  if ($script:lastKind -eq 'working' -and $sum.kind -eq 'problem') { $tray.ShowBalloonTip(5000, 'Sermon Manager', $sum.detail, 'Warning') }
  $script:lastKind = $sum.kind
  if ($win.IsVisible) {
    if (((Get-Date) - $script:LastAsk).TotalSeconds -ge 60) { $script:LastAsk = Get-Date; Ask-Overview }
    Refresh-Window
  }
}
# a short timer: shortcut clicks and the manager's answer show up at once
$fast = New-Object System.Windows.Forms.Timer
$fast.Interval = 400
$fast.Add_Tick({
    if ($showEvent.WaitOne(0)) { Show-Window }
    if ((Take-Overview) -and $win.IsVisible) { Fill-Queue }
  })
$fast.Start()
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000
$timer.Add_Tick({ Tick })
$timer.Start()
Ensure-Shortcuts
Tick
if ($Show) { Show-Window }

[System.Windows.Forms.Application]::Run()
$tray.Visible = $false
$tray.Dispose()
