$ErrorActionPreference = 'Stop'
Write-Host "1 parse"
$e = $null; [void][System.Management.Automation.Language.Parser]::ParseFile("$PWD\windows\sermon-audio.ps1", [ref]$null, [ref]$e)
if ($e.Count) { $e | % { Write-Host "PARSE $($_.Extent.StartLineNumber): $($_.Message)" }; exit 1 } else { Write-Host 'parse ok' }
Write-Host "2 ffmpeg download"
Invoke-WebRequest https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip -OutFile ff.zip -UseBasicParsing -TimeoutSec 300
Write-Host "3 unzip"
Add-Type -AssemblyName System.IO.Compression.FileSystem; [IO.Compression.ZipFile]::ExtractToDirectory("$PWD\ff.zip", "$PWD\ff")
$ff = (Get-ChildItem ff -Recurse -Filter ffmpeg.exe | Select -First 1).FullName
$Tools = Split-Path $ff
Copy-Item "$env:WINDIR\System32\where.exe" (Join-Path $Tools 'yt-dlp.exe')   # a stand-in that just fails; the captions file is already there
$work = Join-Path $env:RUNNER_TEMP 'w'; New-Item -ItemType Directory -Force $work, "$work\fonts" | Out-Null
Copy-Item reels\fonts\*.ttf "$work\fonts"
Write-Host "4 test video"
& $ff -nostdin -hide_banner -loglevel error -f lavfi -i "testsrc2=s=1920x1080:d=4" -f lavfi -i "sine=d=4" -shortest "$work\src.mp4"
$src = Get-Item "$work\src.mp4"
$script = Get-Content windows\sermon-audio.ps1 -Raw
foreach ($fn in 'Quote-Arg', 'Run-Tool', 'Last-Line', 'Caption-Words', 'Send-Words') { $m = [regex]::Match($script, "(?s)\nfunction $fn[ (].*?\n\}\r?\n"); if (-not $m.Success) { Write-Host "missing $fn"; exit 1 }; Invoke-Expression $m.Value }
$Inv = [Globalization.CultureInfo]::InvariantCulture
$script:logged = @()
function Log([string]$m) { Write-Host "LOG $m"; $script:logged += $m }
$Server = 'http://localhost:8787'; $Code = 'tnbc-x'
$job = Get-Content ptest\coverjob.json -Raw | ConvertFrom-Json
$srv = Start-Process node -ArgumentList "$PWD\ptest\fake.js" -WorkingDirectory "$PWD" -PassThru -WindowStyle Hidden; Start-Sleep 2
Write-Host "5 cover block"
$block = [regex]::Match($script, '(?s)  if \(\$job\.cover\) \{.*?\n  \}\r?\n').Value
Invoke-Expression $block
$ok = 0; $bad = 0
function T($n, $c) { if ($c) { $script:ok++; Write-Host "ok   $n" } else { $script:bad++; Write-Host "FAIL $n" } }
$got = Get-Content got.txt -Raw
Write-Host $got
T 'cover.jpg made' ((Test-Path "$work\cover.jpg") -and (Get-Item "$work\cover.jpg").Length -gt 20000)
T 'cover uploaded as JPEG' ($got -match 'PUT /api/reels/cover\?id=VIDEO000001&n=1 \d+ image/jpeg')
T 'no cover problem logged' (-not ($script:logged -match 'Cover'))
T 'tried maxresdefault, then used hq720' ($got -match 'GET /vi/X/maxresdefault.jpg' -and $got -match 'GET /vi/X/hq720.jpg')
Stop-Process -Id $srv.Id
Write-Host "$ok passed, $bad failed"; if ($bad) { exit 1 }
