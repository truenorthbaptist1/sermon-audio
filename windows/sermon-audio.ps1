# True North Baptist Church - Sermon audio maker (runs on the church's home computer)
#
# Every hour while the computer is on (and a few minutes after signing in), Windows runs this script.
# It asks the YouTube Manager which sermons need audio, and for each one:
#   1. downloads only the audio track from YouTube (yt-dlp),
#   2. finds the dead air at the start and end and trims it (or uses the trim times set on the admin page),
#   3. evens out the volume and saves a small MP3 named after the video title (ffmpeg),
#   4. sends the MP3 to the YouTube Manager, which stores it and adds it to the website and podcast,
#   5. deletes its working files.
# It also makes Instagram reels (see "reels" below): it fetches YouTube's word-by-word captions so the
# YouTube Manager can pick the teaching moments, then renders each moment as a vertical video with subtitles.
# Nothing is kept on this computer except the program, its tools, two fonts and a short log (log.txt).
#
# Run it by hand to test:  right-click "Run now.cmd"  (or: powershell -ExecutionPolicy Bypass -File sermon-audio.ps1 -Show)
#
# Three jobs run side by side (1.5.0): this copy makes the sermon audio and starts two helpers, one for the
# sermon reels and one for the Scripture & question posts (the same file with -Part reels / -Part posts).
# While the audio part is busy, the helpers check every minute for new work, so a reel asked for in the
# middle of a long audio run is made within a couple of minutes.

param([switch]$Show, [ValidateSet('audio', 'reels', 'posts')][string]$Part = 'audio')

$Version = '1.6.0'
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Inv = [Globalization.CultureInfo]::InvariantCulture

$Me = $MyInvocation.MyCommand.Path
$Dir = Split-Path -Parent $Me
$Tools = Join-Path $Dir 'tools'
$LogFile = Join-Path $Dir 'log.txt'
$env:PATH = "$Tools;$env:PATH"   # yt-dlp finds deno (needed for YouTube) here too

function Log([string]$m) {
  $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m
  # three parts share the log: if another one is writing this instant, wait a moment and try again
  for ($i = 0; $i -lt 20; $i++) {
    try { [IO.File]::AppendAllText($LogFile, $line + "`r`n", (New-Object Text.UTF8Encoding($false))); break } catch { Start-Sleep -Milliseconds 150 }
  }
  if ($Show) { Write-Host $line }
  Status-FromLog $m
}

# ---------- status for the icon by the clock (status-tray.ps1 reads status.json) ----------
# the audio part writes status.json; the helpers write status-reels.json and status-posts.json
$StatusFile = if ($Part -eq 'audio') { Join-Path $Dir 'status.json' } else { Join-Path $Dir "status-$Part.json" }
$St = @{ version = $Version; part = $Part; state = 'running'; startedAt = (Get-Date -Format o); current = 'Starting'; audio = 0; reels = 0 }
try { $old = Get-Content $StatusFile -Raw -Encoding UTF8 | ConvertFrom-Json; if ($old.lastProblem) { $St.lastProblem = $old.lastProblem; $St.lastProblemAt = $old.lastProblemAt } } catch {}
function Save-Status {
  try {
    $tmp = $StatusFile + '.tmp'
    [IO.File]::WriteAllText($tmp, ($St | ConvertTo-Json -Compress), (New-Object Text.UTF8Encoding($false)))
    Move-Item -Path $tmp -Destination $StatusFile -Force
  } catch {}
}
function Status-FromLog([string]$m) {
  $t = $m.Trim()
  if ($t -match '^Working on: (.+)$') { $St.current = 'Making audio: ' + $Matches[1] }
  elseif ($t -match '^Reels: getting captions for (.+)$') { $St.current = 'Getting captions: ' + $Matches[1] }
  elseif ($t -match '^Reels: making reel #(\d+) from (.+)$') { $St.current = "Making reel #$($Matches[1]): $($Matches[2])" }
  elseif ($t -match '^Posts: making the (.+)$') { $St.current = 'Making the ' + $Matches[1] }
  elseif ($t -match '^Done: ') { $St.audio++ }
  elseif ($t -match '^Reel #\d+ made|^Made \d+ file') { $St.reels++ }
  elseif ($t -match '^(Problem|Reel problem)[^:]*: (.+)$|^Could not ask|doesn.t accept this computer') { $St.lastProblem = $t; $St.lastProblemAt = (Get-Date -Format o) }
  else { return }
  Save-Status
}

# Keep the log short (the audio part only, before the helpers start)
if ($Part -eq 'audio' -and (Test-Path $LogFile) -and (Get-Item $LogFile).Length -gt 1MB) {
  $keep = Get-Content $LogFile -Tail 3000
  Set-Content -Path $LogFile -Value $keep -Encoding UTF8
}

# Only one copy of each part at a time
$MainMutex = 'Local\TNBCSermonAudio'
$mutexName = if ($Part -eq 'audio') { $MainMutex } else { "$MainMutex-$Part" }
$mutex = New-Object System.Threading.Mutex($false, $mutexName)
# a part stopped from the status icon leaves its mutex "abandoned": taking it over is fine
$got = $false
try { $got = $mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $got = $true }
if (-not $got) { if ($Show) { Write-Host 'Already running.' }; exit 0 }
function Main-Running {
  $m = $null
  if ([System.Threading.Mutex]::TryOpenExisting($MainMutex, [ref]$m)) { $m.Dispose(); return $true }
  return $false
}
Save-Status

# Stay out of the way of whatever else the computer is doing
try { (Get-Process -Id $PID).PriorityClass = 'BelowNormal' } catch {}

# ---------- settings ----------
$cfgPath = Join-Path $Dir 'config.json'
if (-not (Test-Path $cfgPath)) { Log 'Not set up yet: run Install.cmd.'; exit 1 }
$cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
$Server = $cfg.server.TrimEnd('/')
try {
  $sec = $cfg.code | ConvertTo-SecureString
  $Code = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
} catch {
  Log 'The saved computer code could not be read (was the program copied from another Windows user?). Run Install.cmd again.'
  exit 1
}

# ---------- helpers ----------
function Quote-Arg([string]$a) {
  if ($a -eq '') { return '""' }
  if ($a -notmatch '[\s"]') { return $a }
  $e = $a -replace '(\\*)"', '$1$1\"'
  $e = $e -replace '(\\+)$', '$1$1'
  return '"' + $e + '"'
}

# Runs a tool, waits, and returns @{ code; out; err }  ($cwd: folder to run it in)
function Run-Tool([string]$exe, [string[]]$argList, [string]$cwd = '') {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = Join-Path $Tools $exe
  if ($cwd) { $psi.WorkingDirectory = $cwd }
  $psi.Arguments = ($argList | ForEach-Object { Quote-Arg $_ }) -join ' '
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
  $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  [void]$p.Start()
  try { $p.PriorityClass = 'BelowNormal' } catch {}
  $o = $p.StandardOutput.ReadToEndAsync()
  $e = $p.StandardError.ReadToEndAsync()
  $p.WaitForExit()
  return @{ code = $p.ExitCode; out = $o.Result; err = $e.Result }
}

function Api([string]$path, $body) {
  $json = if ($null -eq $body) { '{}' } else { $body | ConvertTo-Json -Compress -Depth 6 }
  $bytes = [Text.Encoding]::UTF8.GetBytes($json)
  $res = Invoke-WebRequest -Method Post -Uri ($Server + $path) -Headers @{ Authorization = "Bearer $Code" } `
    -ContentType 'application/json; charset=utf-8' -Body $bytes -TimeoutSec 600 -UseBasicParsing
  # Always read the reply as UTF-8 (Windows PowerShell 5.1 otherwise guesses Latin-1 and garbles curly quotes)
  return ([Text.Encoding]::UTF8.GetString($res.RawContentStream.ToArray()) | ConvertFrom-Json)
}

function ApiError($err) {
  try { if ($err.ErrorDetails -and $err.ErrorDetails.Message) { $j = $err.ErrorDetails.Message | ConvertFrom-Json; if ($j.error) { return $j.error } } } catch {}
  try {
    $r = $err.Exception.Response
    if ($r) {
      $sr = New-Object IO.StreamReader($r.GetResponseStream())
      $j = $sr.ReadToEnd() | ConvertFrom-Json
      if ($j.error) { return $j.error }
    }
  } catch {}
  return $err.Exception.Message
}

function Clock([double]$sec) { $t = [TimeSpan]::FromSeconds([Math]::Round($sec)); if ($t.Hours) { return $t.ToString('h\:mm\:ss') } return $t.ToString('m\:ss') }
function Num([string]$s) { return [double]::Parse($s, $Inv) }
function Str([double]$n) { return $n.ToString('0.###', $Inv) }

function Last-Line([string]$text) {
  $lines = $text -split "`r?`n" | Where-Object { $_ -match '\S' -and $_ -notmatch '^\[download\]|^\[youtube\]|^\[info\]' }
  if ($lines) { return ($lines | Select-Object -Last 2) -join ' ' }
  return 'no details'
}

# ---------- finding the sermon inside a whole-service recording ----------
# Singing and instruments are almost continuous sound; preaching has constant short pauses between phrases.
# Every 2 seconds we measure how much of the time is "pause" (compared to the loudness around it), smooth that
# over 10 seconds, and take the longest stretch of speaking (short breaks of up to 30 seconds allowed).
# That stretch is the sermon. If there is no stretch of at least 15 minutes, nothing is cut but the silence.
Add-Type -Language CSharp -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.IO;
public static class SermonFinder {
  static int ReadFull(Stream s, byte[] b) {
    int got = 0;
    while (got < b.Length) { int r = s.Read(b, got, b.Length - got); if (r <= 0) break; got += r; }
    return got;
  }
  // pcm: 16-bit mono little-endian at sampleRate. Returns {start, end} in seconds, or null.
  public static double[] Find(string pcm, int sampleRate) {
    int fl = sampleRate / 40;
    List<float> en = new List<float>();
    byte[] buf = new byte[fl * 2];
    using (FileStream fs = File.OpenRead(pcm)) {
      BufferedStream bs = new BufferedStream(fs, 1 << 20);
      while (ReadFull(bs, buf) == buf.Length) {
        double sum = 0;
        for (int i = 0; i < fl; i++) { short v = (short)(buf[2 * i] | (buf[2 * i + 1] << 8)); double d = v / 32768.0; sum += d * d; }
        en.Add((float)(10 * Math.Log10(sum / fl + 1e-10)));
      }
    }
    int n = en.Count, S = 80, W = 400, m = n / S;
    if (m < 10) return null;
    double[] pause = new double[m], loud = new double[m];
    for (int k = 0; k < m; k++) {
      int c = k * S + S / 2, lo = Math.Max(0, c - W / 2), hi = Math.Min(n, c + W / 2);
      float[] ctx = new float[hi - lo];
      for (int i = lo; i < hi; i++) ctx[i - lo] = en[i];
      Array.Sort(ctx);
      double pos = (ctx.Length - 1) * 0.9; int ip = (int)Math.Floor(pos);
      double p90 = ip + 1 < ctx.Length ? ctx[ip] + (ctx[ip + 1] - ctx[ip]) * (pos - ip) : ctx[ip];
      int below = 0;
      for (int i = k * S; i < (k + 1) * S; i++) if (en[i] < p90 - 18) below++;
      pause[k] = (double)below / S; loud[k] = p90;
    }
    bool[] speech = new bool[m];
    for (int k = 0; k < m; k++) {
      double t = 0; for (int j = k - 2; j <= k + 2; j++) if (j >= 0 && j < m) t += pause[j];
      speech[k] = t / 5 >= 0.10 && loud[k] > -50;
    }
    int bestA = -1, bestB = -1, start = -1, last = -1, gap = 0;
    for (int k = 0; k <= m; k++) {
      bool sp = k < m && speech[k];
      if (sp) { if (start < 0) start = k; gap = 0; last = k; }
      else if (start >= 0) {
        gap++;
        if (gap > 15 || k == m) { if (last - start > bestB - bestA) { bestA = start; bestB = last; } start = -1; }
      }
    }
    if (bestA < 0 || (bestB + 1 - bestA) * 2 < 900) return null;
    return new double[] { bestA * 2.0, (bestB + 1) * 2.0 };
  }
}
"@

# ---------- the status icon by the clock (status-tray.ps1): keep it installed, up to date and running ----------
$TrayFile = Join-Path $Dir 'status-tray.ps1'
function Update-Tray {
  try {
    $tmp = Join-Path $Dir 'status-tray.new.ps1'
    Invoke-WebRequest 'https://raw.githubusercontent.com/truenorthbaptist1/sermon-audio/main/windows/status-tray.ps1' -OutFile $tmp -UseBasicParsing -TimeoutSec 60
    $new = Get-Content $tmp -Raw
    $have = if (Test-Path $TrayFile) { Get-Content $TrayFile -Raw } else { '' }
    $nv = if ($new -match 'TrayVersion ([\d.]+)') { [version]$Matches[1] } else { $null }
    $hv = if ($have -match 'TrayVersion ([\d.]+)') { [version]$Matches[1] } else { [version]'0.0' }
    if ($nv -and $nv -gt $hv -and $new -match 'Application\]::Run') { Copy-Item $tmp $TrayFile -Force; Log "Status icon updated to version $nv." }
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
  } catch {}
}
function Start-Tray {
  try {
    if (-not (Test-Path $TrayFile)) { Update-Tray }
    if (-not (Test-Path $TrayFile)) { return }
    $off = Join-Path $Dir 'tray-off.txt'
    if ((Test-Path $off) -and ((Get-Content $off -Raw).Trim() -eq (Get-Date -Format 'yyyy-MM-dd'))) { return }
    $psArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File `"$TrayFile`""
    # start it when you sign in
    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $cmd = "powershell.exe $psArgs"
    if ((Get-ItemProperty -Path $runKey -Name 'TNBC Sermon Audio status' -ErrorAction SilentlyContinue).'TNBC Sermon Audio status' -ne $cmd) {
      Set-ItemProperty -Path $runKey -Name 'TNBC Sermon Audio status' -Value $cmd
    }
    # and now, if it isn't showing
    $m = $null
    if ([System.Threading.Mutex]::TryOpenExisting('Local\TNBCSermonAudioTray', [ref]$m)) { $m.Dispose(); return }
    Start-Process powershell.exe -ArgumentList $psArgs -WindowStyle Hidden
  } catch {}
}

if ($Part -eq 'audio') {
# ---------- keep this program up to date (checks once a day; new version runs next time) ----------
$selfStamp = Join-Path $Dir 'last-self-update.txt'
if (-not (Test-Path $selfStamp) -or ((Get-Date) - (Get-Item $selfStamp).LastWriteTime).TotalHours -ge 20) {
  try {
    $newTmp = Join-Path $Dir 'sermon-audio.new.ps1'
    Invoke-WebRequest 'https://raw.githubusercontent.com/truenorthbaptist1/sermon-audio/main/windows/sermon-audio.ps1' -OutFile $newTmp -UseBasicParsing -TimeoutSec 60
    $newText = Get-Content $newTmp -Raw
    $mine = $MyInvocation.MyCommand.Path
    if ($newText -match "Version = '([\d.]+)'" -and ([version]$Matches[1] -gt [version]$Version) -and $newText -match 'SermonAudioEnd') {
      Copy-Item $newTmp $mine -Force
      Log "Program updated to version $($Matches[1]) (used from the next run)."
    }
    Remove-Item $newTmp -Force -ErrorAction SilentlyContinue
  } catch {}
  Update-Tray
  Set-Content -Path $selfStamp -Value (Get-Date -Format o)
}
Start-Tray

# ---------- keep yt-dlp up to date (YouTube changes often) ----------
$stamp = Join-Path $Tools 'last-update.txt'
$needUpdate = -not (Test-Path $stamp) -or ((Get-Date) - (Get-Item $stamp).LastWriteTime).TotalDays -ge 7
if ($needUpdate) {
  $u = Run-Tool 'yt-dlp.exe' @('-U')
  Log ('Checked for a yt-dlp update: ' + (Last-Line ($u.out + "`n" + $u.err)))
  Set-Content -Path $stamp -Value (Get-Date -Format o)
}

# ---------- say hello (also checks the internet is there) ----------
$ytv = (Run-Tool 'yt-dlp.exe' @('--version')).out.Trim()
try {
  $hello = Api '/api/audio/hello' @{ version = $Version; tools = "yt-dlp $ytv" }
} catch {
  $msg = ApiError $_
  if ($msg -match 'not valid') { Log "The YouTube Manager doesn't accept this computer's code: $msg" }
  elseif ($Show) { Log "Couldn't reach the YouTube Manager (no internet?): $msg" }
  exit 0
}
$limit = [int]$hello.perSession
if ($limit -lt 1) { $limit = 10 }
}

# ---------- Instagram reels and posts (made by the two helpers, side by side with the audio) ----------
$FontDir = Join-Path $Dir 'reels-fonts'
function Reel-Captions($job, [string]$work) {
  # YouTube's captions with a time for every word (json3), English, automatic ones if nobody typed any
  $cap = Run-Tool 'yt-dlp.exe' @('--skip-download', '--write-subs', '--write-auto-subs', '--sub-langs', 'en-orig,en,en-US,en-GB',
    '--sub-format', 'json3', '--no-playlist', '--retries', '10', '--socket-timeout', '30',
    '-o', (Join-Path $work 'cap.%(ext)s'), ('https://www.youtube.com/watch?v=' + $job.id))
  $files = @(Get-ChildItem -Path $work -Filter 'cap*.json3')
  if (-not $files.Count) {
    if ($cap.code -ne 0) { throw ('Getting the captions failed: ' + (Last-Line $cap.err)) }
    throw 'YouTube has no English captions for this video yet.'
  }
  $file = ($files | Sort-Object { if ($_.Name -like '*en-orig*') { 0 } elseif ($_.Name -like '*.en.*') { 1 } else { 2 } } | Select-Object -First 1)
  $j = [IO.File]::ReadAllText($file.FullName, [Text.Encoding]::UTF8) | ConvertFrom-Json
  $sb = New-Object Text.StringBuilder
  $count = 0
  foreach ($ev in $j.events) {
    if (-not $ev.segs) { continue }
    $t0 = [double]$ev.tStartMs
    $dur = if ($ev.dDurationMs) { [double]$ev.dDurationMs } else { 2000 }
    $segs = @($ev.segs | Where-Object { $_.utf8 -and $_.utf8.Trim() })
    for ($k = 0; $k -lt $segs.Count; $k++) {
      $st = $t0 + [double]$segs[$k].tOffsetMs
      $en = if ($k + 1 -lt $segs.Count) { $t0 + [double]$segs[$k + 1].tOffsetMs } else { $t0 + $dur }
      $ws = @($segs[$k].utf8.Trim() -split '\s+' | Where-Object { $_ })
      for ($q = 0; $q -lt $ws.Count; $q++) {
        $wt = $st + ($en - $st) * $q / $ws.Count
        [void]$sb.Append(([Math]::Round($wt)).ToString($Inv)).Append("`t").Append($ws[$q]).Append("`n")
        $count++
      }
    }
  }
  if ($count -lt 200) { throw "The captions have only $count words." }
  $bytes = [Text.Encoding]::UTF8.GetBytes($sb.ToString())
  $res = Invoke-RestMethod -Method Put -Uri ($Server + '/api/reels/captions?id=' + $job.id) -Headers @{ Authorization = "Bearer $Code" } `
    -ContentType 'text/plain; charset=utf-8' -Body $bytes -TimeoutSec 600 -UseBasicParsing
  Log "  Captions sent ($count words). Moments picked: $($res.clips)."
}

# Fonts (kept between runs) and the church logo, copied into the job's working folder
function Prepare-Art($job, [string]$work) {
  if (-not (Test-Path $FontDir)) { New-Item -ItemType Directory -Path $FontDir | Out-Null }
  $fonts = Join-Path $work 'fonts'
  New-Item -ItemType Directory -Path $fonts | Out-Null
  foreach ($f in $job.fonts) {
    $have = Join-Path $FontDir $f.name
    if (-not (Test-Path $have) -or (Get-Item $have).Length -lt 10000) { Invoke-WebRequest -Uri $f.url -OutFile $have -TimeoutSec 120 -UseBasicParsing }
    Copy-Item $have (Join-Path $fonts $f.name)
  }
  $logo = Join-Path $work 'logo.png'
  try { Invoke-WebRequest -Uri $job.logo -OutFile $logo -TimeoutSec 60 -UseBasicParsing } catch {}
  if (-not (Test-Path $logo) -or (Get-Item $logo).Length -lt 500) {
    [void](Run-Tool 'ffmpeg.exe' @('-hide_banner', '-y', '-f', 'lavfi', '-i', 'color=c=black@0.0:s=8x8,format=rgba', '-frames:v', '1', $logo))
  }
}

# Scripture and question posts: images, carousel slides or a short reel, drawn exactly as the manager says
function Post-Render($job, [string]$work) {
  Prepare-Art $job $work
  if ($job.bg) { Invoke-WebRequest -Uri $job.bg -OutFile (Join-Path $work 'bg.mp4') -TimeoutSec 600 -UseBasicParsing }
  if ($job.music) { Invoke-WebRequest -Uri $job.music -OutFile (Join-Path $work 'music.m4a') -TimeoutSec 300 -UseBasicParsing }
  $assets = @()
  $v2 = [bool]$job.v2   # 1.5.1: upload every file, then tell the manager once (a quick post can outrun its storage)
  foreach ($o in $job.outputs) {
    [IO.File]::WriteAllText((Join-Path $work ('s' + $o.i + '.ass')), [string]$o.ass, (New-Object Text.UTF8Encoding($false)))
    $enc = Run-Tool 'ffmpeg.exe' ([string[]]$o.args) $work
    $file = Join-Path $work ('out' + $o.i + '.' + $o.ext)
    if ($enc.code -ne 0 -or -not (Test-Path $file) -or (Get-Item $file).Length -lt 5000) { throw ('Making the picture failed: ' + (Last-Line $enc.err)) }
    $type = if ($o.ext -eq 'jpg') { 'image/jpeg' } else { 'video/mp4' }
    for ($try = 1; ; $try++) {
      try {
        $uri = $Server + '/api/posts/upload?id=' + [uri]::EscapeDataString($job.id) + '&i=' + $o.i + $(if ($v2) { '&v=2' } else { '' })
        $res = Invoke-WebRequest -Method Put -Uri $uri -InFile $file -ContentType $type `
          -Headers @{ Authorization = "Bearer $Code" } -TimeoutSec 1800 -UseBasicParsing
        if ($v2) { $assets += ([Text.Encoding]::UTF8.GetString($res.RawContentStream.ToArray()) | ConvertFrom-Json).asset }
        break
      } catch {
        $httpStatus = 0; try { $httpStatus = [int]$_.Exception.Response.StatusCode } catch {}
        if ($try -ge 4 -or ($httpStatus -ge 400 -and $httpStatus -lt 500)) { throw }
        Start-Sleep -Seconds (30 * $try)
      }
    }
  }
  if ($v2) { Api '/api/posts/done' @{ id = $job.id; job = $job.job; assets = $assets } | Out-Null }
  Log "  Made $($job.outputs.Count) file(s) for $($job.title)."
}

function Reel-Render($job, [string]$work) {
  Prepare-Art $job $work
  [IO.File]::WriteAllText((Join-Path $work 'clip.ass'), [string]$job.ass, (New-Object Text.UTF8Encoding($false)))

  # just this part of the video, up to 1080p
  $section = '*' + (Str ([double]$job.start)) + '-' + (Str ([double]$job.end))
  $dl = Run-Tool 'yt-dlp.exe' @(
    '-f', 'bv*[height<=1080][vcodec^=avc1]+ba[ext=m4a]/bv*[height<=1080]+ba/b[height<=1080]/b',
    '--download-sections', $section, '--force-keyframes-at-cuts', '--merge-output-format', 'mp4',
    '--no-playlist', '--no-progress', '--no-part', '--retries', '20', '--fragment-retries', '20', '--socket-timeout', '30',
    '-o', (Join-Path $work 'src.%(ext)s'), ('https://www.youtube.com/watch?v=' + $job.id))
  $src = Get-ChildItem -Path $work -Filter 'src.*' | Select-Object -First 1
  if ($dl.code -ne 0 -or -not $src) { throw ('YouTube download failed: ' + (Last-Line $dl.err)) }

  # a very soft hymn underneath (when the manager asks for one)
  $musicArgs = @()
  if ($job.music) {
    Invoke-WebRequest -Uri $job.music -OutFile (Join-Path $work 'music.m4a') -TimeoutSec 300 -UseBasicParsing
    $musicArgs = @('-stream_loop', '-1', '-i', 'music.m4a')
  }
  $out = Join-Path $work 'reel.mp4'
  $enc = Run-Tool 'ffmpeg.exe' (@('-hide_banner', '-nostats', '-y', '-i', $src.Name, '-i', 'logo.png') + $musicArgs + @(
    '-filter_complex', [string]$job.filter, '-map', '[v]', '-map', '[a]', '-t', (Str ([double]$job.duration)),
    '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '21', '-profile:v', 'high', '-level', '4.1',
    '-c:a', 'aac', '-b:a', '128k', '-ar', '48000', '-movflags', '+faststart', 'reel.mp4')) $work
  if ($enc.code -ne 0 -or -not (Test-Path $out) -or (Get-Item $out).Length -lt 50000) { throw ('Making the video failed: ' + (Last-Line $enc.err)) }

  # 1.6.0: the cover picture for the Instagram grid (a still of the preacher with the reel's title); sent before
  # the video. A cover problem never stops the reel: Instagram then uses the first frame as before.
  if ($job.cover) {
    try {
      [IO.File]::WriteAllText((Join-Path $work 'cover.ass'), [string]$job.cover.ass, (New-Object Text.UTF8Encoding($false)))
      $cargs = [string[]]@($job.cover.args | ForEach-Object { if ($_ -eq 'SRC') { $src.Name } else { [string]$_ } })
      $cv = Run-Tool 'ffmpeg.exe' $cargs $work
      $cfile = Join-Path $work 'cover.jpg'
      if ($cv.code -ne 0 -or -not (Test-Path $cfile)) { throw ('ffmpeg: ' + (Last-Line $cv.err)) }
      Invoke-WebRequest -Method Put -Uri ($Server + '/api/reels/cover?id=' + $job.id + '&n=' + $job.n) -InFile $cfile -ContentType 'image/jpeg' `
        -Headers @{ Authorization = "Bearer $Code" } -TimeoutSec 300 -UseBasicParsing | Out-Null
    } catch { Log ('  Cover picture skipped: ' + $_.Exception.Message) }
  }

  for ($try = 1; ; $try++) {
    try {
      Invoke-WebRequest -Method Put -Uri ($Server + '/api/reels/upload?id=' + $job.id + '&n=' + $job.n) -InFile $out -ContentType 'video/mp4' `
        -Headers @{ Authorization = "Bearer $Code" } -TimeoutSec 1800 -UseBasicParsing | Out-Null
      break
    } catch {
      $httpStatus = 0; try { $httpStatus = [int]$_.Exception.Response.StatusCode } catch {}
      if ($try -ge 4 -or ($httpStatus -ge 400 -and $httpStatus -lt 500)) { throw }
      Start-Sleep -Seconds (30 * $try)
    }
  }
  Log "  Reel #$($job.n) made: $([Math]::Round([double]$job.duration)) seconds, $([Math]::Round((Get-Item $out).Length / 1MB, 1)) MB."
}

# Makes reels/posts until none are left. $only: 'reels', 'posts' or '' (both, the old way).
# Sets $script:LastCheck to the manager's clock at the last look, so the helper knows when new work arrived.
$script:LastCheck = 0
$script:PauseUntil = Get-Date
function Reel-Work([string]$only) {
  if ($Part -ne 'audio') { $St.current = 'Checking for ' + $Part; Save-Status }
  $q = if ($only) { '?only=' + $only } else { '' }
  for ($n = 0; $n -lt 30; $n++) {
    try { $r = Api ('/api/reels/next' + $q) @{ version = $Version } } catch { if ($Show) { Log ('Reels: ' + (ApiError $_)) }; break }
    if ($r.now) { $script:LastCheck = [double]$r.now }
    $job = $r.job
    if (-not $job) { break }
    $work = Join-Path ([IO.Path]::GetTempPath()) ('tnbc-reel-' + ($job.id -replace '[^\w-]', ''))
    try {
      if (Test-Path $work) { Remove-Item $work -Recurse -Force }
      New-Item -ItemType Directory -Path $work | Out-Null
      if ($job.type -eq 'captions') { Log "Reels: getting captions for $($job.title)"; Reel-Captions $job $work }
      elseif ($job.type -eq 'render') { Log "Reels: making reel #$($job.n) from $($job.title)"; Reel-Render $job $work }
      elseif ($job.type -eq 'post') { Log "Posts: making the $($job.title)"; Post-Render $job $work }
      else { break }
    } catch {
      $msg = ApiError $_
      Log "  Reel problem: $msg"
      $body = @{ id = $job.id; error = $msg }
      if ($job.type -eq 'render') { $body.n = $job.n }
      $failPath = if ($job.type -eq 'post') { '/api/posts/fail' } else { '/api/reels/fail' }
      try { Api $failPath $body | Out-Null } catch {}
      if ($msg -match 'download failed|captions failed') { $script:PauseUntil = (Get-Date).AddMinutes(45); break }  # YouTube is probably blocking; try again later
    } finally {
      if (Test-Path $work) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
    }
  }
  if ($Part -ne 'audio') { $St.current = 'Watching for new ' + $Part; Save-Status }
}

# ---------- the reels and posts helpers ----------
if ($Part -ne 'audio') {
  Reel-Work $Part
  # keep looking (one small check a minute) while the audio part is still working, at most 12 hours
  $until = (Get-Date).AddHours(12)
  while ((Get-Date) -lt $until -and (Main-Running)) {
    Start-Sleep -Seconds 60
    if ((Get-Date) -lt $script:PauseUntil) { continue }
    try { $pk = Api ('/api/reels/peek?part=' + $Part) @{} } catch { continue }
    if ([double]$pk.poke -gt $script:LastCheck) { Reel-Work $Part }
  }
  $St.summary = if ($St.reels) { "made $($St.reels) $Part" } else { 'nothing waiting' }
  $St.state = 'done'; $St.current = $null; $St.finishedAt = (Get-Date -Format o)
  Save-Status
  $mutex.ReleaseMutex()
  exit 0
}

# ---------- audio part: start the two helpers, so reels and posts are made at the same time as the audio ----------
$helpersOk = $true
foreach ($h in @('reels', 'posts')) {
  try {
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Me`" -Part $h")
  } catch { $helpersOk = $false; Log "Couldn't start the $h helper ($($_.Exception.Message)); making them here first." }
}
if (-not $helpersOk) { Reel-Work '' }

# ---------- make audio ----------
$made = 0
for ($n = 0; $n -lt $limit; $n++) {
  try { $r = Api '/api/audio/next' @{ version = $Version; tools = "yt-dlp $ytv" } }
  catch { Log ('Could not ask for the next sermon: ' + (ApiError $_)); break }
  $job = $r.job
  if (-not $job) { break }

  $work = Join-Path ([IO.Path]::GetTempPath()) ('tnbc-audio-' + $job.id)
  $stage = 'starting'
  $stopAfter = $false
  try {
    if (Test-Path $work) { Remove-Item $work -Recurse -Force }
    New-Item -ItemType Directory -Path $work | Out-Null
    Log "Working on: $($job.title)"

    # 1. audio only from YouTube
    $stage = 'download'
    $dl = Run-Tool 'yt-dlp.exe' @(
      '-f', 'bestaudio[ext=m4a]/bestaudio/best', '--no-playlist', '--no-progress', '--no-part',
      '--retries', '20', '--fragment-retries', '20', '--retry-sleep', '5', '--socket-timeout', '30',
      '-o', (Join-Path $work 'source.%(ext)s'), ('https://www.youtube.com/watch?v=' + $job.id))
    $src = Get-ChildItem -Path $work -Filter 'source.*' | Select-Object -First 1
    if ($dl.code -ne 0 -or -not $src) {
      $stopAfter = $true  # if YouTube is blocking downloads, the next ones would fail too
      throw ('YouTube download failed: ' + (Last-Line $dl.err))
    }

    # 2. where the sermon starts and ends
    $stage = 'trim'
    $probe = Run-Tool 'ffprobe.exe' @('-v', 'error', '-show_entries', 'format=duration', '-of', 'default=nw=1:nk=1', $src.FullName)
    $total = Num ($probe.out.Trim())
    $start = 0.0
    $end = $total
    $how = 'silence only'
    if ($null -eq $job.start -or $null -eq $job.end) {
      # whole-service recordings: keep only the sermon
      $pcm = Join-Path $work 'pcm.raw'
      $pc = Run-Tool 'ffmpeg.exe' @('-hide_banner', '-nostats', '-y', '-i', $src.FullName, '-ac', '1', '-ar', '8000', '-f', 's16le', $pcm)
      $found = $null
      if ($pc.code -eq 0) { try { $found = [SermonFinder]::Find($pcm, 8000) } catch { Log "  Couldn't look for the sermon: $($_.Exception.Message)" } }
      Remove-Item $pcm -Force -ErrorAction SilentlyContinue
      if ($found) {
        $start = [Math]::Max(0, $found[0] - 1)
        $end = [Math]::Min($total, $found[1] + 2)
        $how = 'sermon found'
      } else {
        $sd = Run-Tool 'ffmpeg.exe' @('-hide_banner', '-nostats', '-i', $src.FullName, '-af', 'silencedetect=noise=-45dB:d=3', '-f', 'null', '-')
        $starts = @([regex]::Matches($sd.err, 'silence_start: ([\d.]+)') | ForEach-Object { Num $_.Groups[1].Value })
        $ends = @([regex]::Matches($sd.err, 'silence_end: ([\d.]+)') | ForEach-Object { Num $_.Groups[1].Value })
        # dead air right at the start
        if ($starts.Count -and $ends.Count -and $starts[0] -lt 1) { $start = [Math]::Max(0, $ends[0] - 1) }
        # dead air that runs to the very end
        if ($starts.Count) {
          $trailing = ($starts.Count -gt $ends.Count) -or ($ends.Count -and $ends[-1] -ge $total - 1)
          if ($trailing -and $starts[-1] -gt $start + 60) { $end = [Math]::Min($total, $starts[-1] + 1.5) }
        }
      }
    } else { $how = 'trim times from the admin page' }
    if ($null -ne $job.start) { $start = [double]$job.start }
    if ($null -ne $job.end) { $end = [Math]::Min($total, [double]$job.end) }
    if ($end - $start -lt 30 -and $null -eq $job.start -and $null -eq $job.end) { $start = 0; $end = $total }  # safety: never cut a sermon to nothing
    if ($end -le $start) { throw "The trim times leave nothing (start $(Str $start)s, end $(Str $end)s). Fix them on the admin page." }

    # Artwork for the MP3: the series thumbnail (or the church cover), placed on a square background
    $artFile = Join-Path $work 'art.jpg'
    $haveArt = $false
    foreach ($u in @($job.art, $job.artFallback)) {
      if (-not $u -or $haveArt) { continue }
      try { Invoke-WebRequest -Uri $u -OutFile $artFile -TimeoutSec 60 -UseBasicParsing; $haveArt = (Get-Item $artFile).Length -gt 2000 } catch {}
    }

    # 3. MP3: mono 64 kbps (good for speech, ~30 MB an hour), volume evened out, title and series inside the file
    $stage = 'convert'
    $out = Join-Path $work 'sermon.mp3'
    $artArgs = @()
    if ($haveArt) {
      $artArgs = @('-i', $artFile, '-map', '0:a', '-map', '1:v', '-c:v', 'mjpeg', '-q:v', '3',
        '-vf', 'scale=1000:1000:force_original_aspect_ratio=decrease,pad=1000:1000:(ow-iw)/2:(oh-ih)/2:color=0x13233a',
        '-disposition:v:0', 'attached_pic', '-metadata:s:v', 'title=Album cover', '-metadata:s:v', 'comment=Cover (front)')
    }
    $enc = Run-Tool 'ffmpeg.exe' (@(
      '-hide_banner', '-nostats', '-y', '-ss', (Str $start), '-to', (Str $end), '-i', $src.FullName) + $artArgs + @(
      '-af', 'loudnorm=I=-19:TP=-1.5:LRA=11', '-ac', '1', '-ar', '44100', '-c:a', 'libmp3lame', '-b:a', '64k',
      '-id3v2_version', '3', '-write_xing', '1',
      '-metadata', ('title=' + $job.title), '-metadata', ('artist=' + $job.artist), '-metadata', ('album_artist=' + $job.artist),
      '-metadata', ('album=' + $job.album), '-metadata', ('date=' + ([string]$job.date + '    ').Substring(0, 4).Trim()),
      '-metadata', ('comment=' + $job.comment), '-metadata', 'genre=Sermon', $out))
    if ($enc.code -ne 0 -or -not (Test-Path $out) -or (Get-Item $out).Length -lt 20000) {
      throw ('Converting to MP3 failed: ' + (Last-Line $enc.err))
    }
    # A copy under the video's own title, in case anyone opens the working folder
    $named = Join-Path $work $job.filename
    try { Copy-Item $out $named -ErrorAction SilentlyContinue } catch {}

    # 4. send it
    $stage = 'upload'
    $q = 'id=' + $job.id + '&duration=' + (Str ($end - $start)) + '&start=' + (Str $start) + '&end=' + (Str $end)
    # a short internet drop shouldn't waste the work: try the upload up to 5 times, waiting longer each time
    for ($try = 1; ; $try++) {
      try {
        $res = Invoke-WebRequest -Method Put -Uri ($Server + '/api/audio/upload?' + $q) -InFile $out -ContentType 'audio/mpeg' `
          -Headers @{ Authorization = "Bearer $Code" } -TimeoutSec 1800 -UseBasicParsing
        break
      } catch {
        $why = ApiError $_
        $httpStatus = 0; try { $httpStatus = [int]$_.Exception.Response.StatusCode } catch {}
        if ($try -ge 5 -or ($httpStatus -ge 400 -and $httpStatus -lt 500)) { throw }
        Log "  Upload didn't go through ($why); trying again in $(30 * $try) seconds..."
        Start-Sleep -Seconds (30 * $try)
      }
    }
    $mb = [Math]::Round((Get-Item $out).Length / 1MB, 1)
    $mins = [Math]::Round(($end - $start) / 60)
    Log "  Done: $mins min, $mb MB. Kept $(Clock $start) to $(Clock $end) of the video ($how)."
    $made++
  } catch {
    $msg = if ($stage -eq 'upload') { ApiError $_ } else { $_.Exception.Message }
    Log "  Problem ($stage): $msg"
    try { Api '/api/audio/fail' @{ id = $job.id; error = "$stage`: $msg" } | Out-Null } catch {}
    if ($stopAfter) { Log '  Stopping for now; will try again next hour.'; break }
  } finally {
    if (Test-Path $work) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
  }
}
if ($made -or $Show) { Log "Finished: $made sermon(s) made this time." }
$parts = @()
if ($St.audio) { $parts += "$($St.audio) sermon(s)" }
if ($St.reels) { $parts += "$($St.reels) reel(s) or post(s)" }
$St.summary = if ($parts.Count) { 'made ' + ($parts -join ' and ') } else { 'nothing waiting' }
$St.state = 'done'; $St.current = $null; $St.finishedAt = (Get-Date -Format o)
Save-Status
$mutex.ReleaseMutex()
# SermonAudioEnd (marks a complete download of this file)
