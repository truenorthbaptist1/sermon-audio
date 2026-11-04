# True North Baptist Church - Sermon audio: set up (or remove) the program on this Windows computer.
# Double-click Install.cmd to run this. No administrator rights needed.
#
# What it does:
#   - puts the program in  %LOCALAPPDATA%\TNBC Sermon Audio
#   - downloads its free tools: yt-dlp (YouTube audio), ffmpeg (MP3), deno (needed by yt-dlp for YouTube)
#   - asks for the computer code from the YouTube Manager admin page (Sermon audio -> Add a computer)
#     and saves it encrypted for this Windows user only
#   - tells Windows to run it a few minutes after you sign in, and every hour while the computer is on
# Running it again is safe: it updates the program and tools, and can take a new code.

param([switch]$Remove)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Server = 'https://youtube-manager.truenorthbaptist1.workers.dev'
$TaskName = 'TNBC Sermon Audio'
$Dir = Join-Path $env:LOCALAPPDATA 'TNBC Sermon Audio'
$Tools = Join-Path $Dir 'tools'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Raw = 'https://raw.githubusercontent.com/truenorthbaptist1/sermon-audio/main/windows'

function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }

if ($Remove) {
  Say 'Removing the sermon audio program from this computer...'
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
  if (Test-Path $Dir) { Remove-Item $Dir -Recurse -Force }
  Say 'Done. Also remove this computer on the YouTube Manager admin page (Sermon audio -> Computers).' 'Green'
  exit 0
}

Say ''
Say '  True North Baptist Church - Sermon audio setup' 'Cyan'
Say ''

New-Item -ItemType Directory -Force -Path $Tools | Out-Null

# 1. The program itself
Say '1/4  Copying the program...'
$local = Join-Path $Here 'sermon-audio.ps1'
if (Test-Path $local) { Copy-Item $local (Join-Path $Dir 'sermon-audio.ps1') -Force }
else { Invoke-WebRequest "$Raw/sermon-audio.ps1" -OutFile (Join-Path $Dir 'sermon-audio.ps1') -UseBasicParsing }
foreach ($f in 'Run now.cmd') {
  $p = Join-Path $Here $f
  if (Test-Path $p) { Copy-Item $p (Join-Path $Dir $f) -Force }
}

# 2. Tools (official downloads from each project's GitHub releases)
Say '2/4  Downloading tools (about 150 MB, a few minutes)...'
$tmp = Join-Path ([IO.Path]::GetTempPath()) 'tnbc-audio-setup'
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
  Say '     yt-dlp'
  Invoke-WebRequest 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe' -OutFile (Join-Path $Tools 'yt-dlp.exe') -UseBasicParsing

  Say '     ffmpeg'
  $zip = Join-Path $tmp 'ffmpeg.zip'
  Invoke-WebRequest 'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip' -OutFile $zip -UseBasicParsing
  Expand-Archive $zip -DestinationPath (Join-Path $tmp 'ffmpeg') -Force
  foreach ($exe in 'ffmpeg.exe', 'ffprobe.exe') {
    $found = Get-ChildItem (Join-Path $tmp 'ffmpeg') -Recurse -Filter $exe | Select-Object -First 1
    Copy-Item $found.FullName (Join-Path $Tools $exe) -Force
  }

  Say '     deno'
  $zip = Join-Path $tmp 'deno.zip'
  Invoke-WebRequest 'https://github.com/denoland/deno/releases/latest/download/deno-x86_64-pc-windows-msvc.zip' -OutFile $zip -UseBasicParsing
  Expand-Archive $zip -DestinationPath $Tools -Force
} catch {
  Say "Downloading the tools failed: $($_.Exception.Message)" 'Red'
  Say 'Check the internet connection and run Install.cmd again.' 'Red'
  exit 1
} finally {
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
Set-Content -Path (Join-Path $Tools 'last-update.txt') -Value (Get-Date -Format o)

# 3. The computer code
Say '3/4  Computer code'
$cfgPath = Join-Path $Dir 'config.json'
$keep = $false
if (Test-Path $cfgPath) {
  $ans = Read-Host '     This computer already has a code. Keep it? (Y/n)'
  $keep = $ans -notmatch '^\s*n'
}
if (-not $keep) {
  Say '     On the YouTube Manager admin page: Sermon audio -> Add a computer. Copy the code it shows.'
  for (;;) {
    $code = (Read-Host '     Paste the code here').Trim()
    if ($code -notmatch '^tnbc-[0-9a-f]{48}$') { Say '     That does not look like a computer code (it starts with "tnbc-"). Try again.' 'Yellow'; continue }
    try {
      $hello = Invoke-RestMethod -Method Post -Uri "$Server/api/audio/hello" -Headers @{ Authorization = "Bearer $code" } `
        -ContentType 'application/json' -Body '{"version":"setup"}' -UseBasicParsing -TimeoutSec 60
      Say "     Code accepted for ""$($hello.name)""." 'Green'
      break
    } catch {
      Say '     The YouTube Manager did not accept that code. Check it was copied fully, or add the computer again.' 'Yellow'
    }
  }
  $enc = ConvertTo-SecureString $code -AsPlainText -Force | ConvertFrom-SecureString  # encrypted for this Windows user
  @{ server = $Server; code = $enc } | ConvertTo-Json | Set-Content -Path $cfgPath -Encoding UTF8
}

# 4. Schedule: a few minutes after signing in, then every hour while the computer is on
Say '4/4  Setting it to run on its own...'
$script = Join-Path $Dir 'sermon-audio.ps1'
$psArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
$build = [Environment]::OSVersion.Version.Build
if ($build -ge 18362) {
  # conhost --headless keeps any window from flashing up every hour
  $action = New-ScheduledTaskAction -Execute 'conhost.exe' -Argument "--headless powershell.exe $psArgs" -WorkingDirectory $Dir
} else {
  $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $psArgs -WorkingDirectory $Dir
}
$user = "$env:USERDOMAIN\$env:USERNAME"
$atLogon = New-ScheduledTaskTrigger -AtLogOn -User $user
$atLogon.Delay = 'PT5M'
try { $hourly = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(15) -RepetitionInterval (New-TimeSpan -Hours 1) }
catch { $hourly = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(15) -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Days 9999) }
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 4) -Priority 7
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger @($atLogon, $hourly) -Settings $settings -Principal $principal `
  -Description 'Makes MP3s of True North Baptist Church sermons for the website and podcast. Set up by Install.cmd; remove with Uninstall.cmd.' -Force | Out-Null

Say ''
Say 'All set. The program will run on its own while this computer is on.' 'Green'
Say "It lives in: $Dir   (log: log.txt)"
Say ''
$now = Read-Host 'Make the first sermon now to test it? (Y/n)'
if ($now -notmatch '^\s*n') {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script -Show
}
