$ErrorActionPreference = 'Stop'
Write-Host "1 parse"
$e = $null; [void][System.Management.Automation.Language.Parser]::ParseFile("$PWD\windows\sermon-audio.ps1", [ref]$null, [ref]$e)
if ($e.Count) { $e | % { Write-Host "PARSE $($_.Extent.StartLineNumber): $($_.Message)" }; exit 1 } else { Write-Host 'parse ok' }
Write-Host "2 ffmpeg download"
Invoke-WebRequest https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip -OutFile ff.zip -UseBasicParsing -TimeoutSec 300
Add-Type -AssemblyName System.IO.Compression.FileSystem; [IO.Compression.ZipFile]::ExtractToDirectory("$PWD\ff.zip", "$PWD\ff")
$ff = (Get-ChildItem ff -Recurse -Filter ffmpeg.exe | Select -First 1).FullName
$Tools = Split-Path $ff
$work = Join-Path $env:RUNNER_TEMP 'w'; New-Item -ItemType Directory -Force $work | Out-Null
$FontDir = Join-Path $env:RUNNER_TEMP 'fonts'
Write-Host "3 test video (75 s) and logo"
& $ff -nostdin -hide_banner -loglevel error -f lavfi -i "testsrc2=s=1280x720:r=30:d=75" -f lavfi -i "sine=d=75" -shortest -c:v libx264 -preset ultrafast "$env:RUNNER_TEMP\sermon.mp4"
& $ff -nostdin -hide_banner -loglevel error -f lavfi -i "color=c=white:s=400x400" -frames:v 1 "$PWD\ptest\logo.png"
$script = Get-Content windows\sermon-audio.ps1 -Raw
foreach ($fn in 'Quote-Arg', 'Run-Tool', 'Last-Line', 'Api', 'ApiError', 'Str', 'Prepare-Art', 'Fb-Form', 'FB-Video') { $m = [regex]::Match($script, "(?s)\nfunction $fn[ (].*?\n\}\r?\n"); if (-not $m.Success) { Write-Host "missing $fn"; exit 1 }; Invoke-Expression $m.Value }
# yt-dlp stand-in: "download" the test video to where the program asks
${function:Run-Tool0} = ${function:Run-Tool}
function Run-Tool([string]$exe, [string[]]$argList, [string]$cwd = '') {
  if ($exe -eq 'yt-dlp.exe') { $script:ytargs = $argList; $o = $argList[[array]::IndexOf($argList, '-o') + 1] -replace '%\(ext\)s', 'mp4'; Copy-Item "$env:RUNNER_TEMP\sermon.mp4" $o; return @{ code = 0; out = ''; err = '' } }
  return Run-Tool0 $exe $argList $cwd
}
$Inv = [Globalization.CultureInfo]::InvariantCulture
$script:logged = @()
function Log([string]$m) { Write-Host "LOG $m"; $script:logged += $m }
$Server = 'http://localhost:8787'; $Code = 'tnbc-x'
$job = [IO.File]::ReadAllText("$PWD\ptest\fbjob.json", [Text.Encoding]::UTF8) | ConvertFrom-Json
$srv = Start-Process node -ArgumentList "`"$PWD\ptest\fbfake.js`"" -WorkingDirectory "$PWD" -PassThru -WindowStyle Hidden -RedirectStandardError "$PWD\node-err.txt"
for ($i = 0; $i -lt 30; $i++) { try { Invoke-WebRequest http://localhost:8787/ping -UseBasicParsing -TimeoutSec 2 | Out-Null; break } catch { Start-Sleep 1 } }
Write-Host "4 FB-Video"
$t0 = Get-Date
FB-Video $job $work
Write-Host "took $([int]((Get-Date) - $t0).TotalSeconds) s"
if (Test-Path node-err.txt) { Get-Content node-err.txt }
$ok = 0; $bad = 0
function T($n, $c) { if ($c) { $script:ok++; Write-Host "ok   $n" } else { $script:bad++; Write-Host "FAIL $n" } }
$got = Get-Content got.txt -Raw
Write-Host $got
$out = Join-Path $work 'fb.mp4'
$d = [double](& (Join-Path $Tools 'ffprobe.exe') -v error -show_entries format=duration -of 'default=nw=1:nk=1' $out)
$wh = (& (Join-Path $Tools 'ffprobe.exe') -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 $out)
T "asked YouTube for just the sermon part" (($script:ytargs -join ' ') -match '--download-sections \*0-70')
T "video is 1280x720 ($wh)" ($wh -eq '1280,720')
T "sermon plus a 6-second end card ($d s)" ($d -gt 80 -and $d -lt 82)
T 'uploaded in pieces, every byte' ($got -match 'start (\d+)' -and $got -match "received=$($Matches[1])" -and ([regex]::Matches($got, 'transfer ').Count -ge 2))
T 'finished with the title and the website in the caption' ($got -match 'finish title="\\"Ephesians\.\\" -Study#38-' -and $got -match 'desc=listen')
T 'cover: maxres missing, used hq720, set as preferred' ($got -match 'GET /vi/X/maxresdefault.jpg 404' -and $got -match 'thumbnail preferred')
T 'told the manager' ($got -match 'done .*FBV1')
# a frame from the end card, to look at
& $ff -nostdin -hide_banner -loglevel error -ss ($d - 3) -i $out -frames:v 1 -y "$PWD\endcard.png"
& $ff -nostdin -hide_banner -loglevel error -ss 5 -i $out -frames:v 1 -y "$PWD\sermon.png"
Stop-Process -Id $srv.Id
Write-Host "$ok passed, $bad failed"; if ($bad) { exit 1 }
