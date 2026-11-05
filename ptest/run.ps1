$ErrorActionPreference = 'Stop'
$e = $null; [void][System.Management.Automation.Language.Parser]::ParseFile("$PWD\windows\sermon-audio.ps1", [ref]$null, [ref]$e)
if ($e.Count) { $e | % { Write-Host "PARSE $($_.Extent.StartLineNumber): $($_.Message)" }; exit 1 } else { Write-Host 'parse ok' }
# ffmpeg
Invoke-WebRequest https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip -OutFile ff.zip -UseBasicParsing
Expand-Archive ff.zip ff; $ff = (Get-ChildItem ff -Recurse -Filter ffmpeg.exe | Select -First 1).FullName
$work = Join-Path $env:RUNNER_TEMP 'w'; New-Item -ItemType Directory -Force $work, "$work\fonts" | Out-Null
Copy-Item reels\fonts\*.ttf "$work\fonts"
& $ff -hide_banner -loglevel error -f lavfi -i "testsrc2=s=1920x1080:d=4" -f lavfi -i "sine=d=4" -shortest "$work\src.mp4"
$src = Get-Item "$work\src.mp4"
# the pieces of sermon-audio.ps1 the cover step uses
$script = Get-Content windows\sermon-audio.ps1 -Raw
foreach ($fn in 'Quote-Arg', 'Run-Tool', 'Last-Line') { $m = [regex]::Match($script, "(?s)function $fn[ (].*?\n\}\r?\n"); Invoke-Expression $m.Value }
$Tools = Split-Path $ff; $ToolsDir = $Tools
function Log([string]$m) { Write-Host "LOG $m"; $script:logged += $m }
$Server = 'http://localhost:8787'; $Code = 'tnbc-x'
$job = Get-Content ptest\coverjob.json -Raw | ConvertFrom-Json
$srv = Start-Process node -ArgumentList "$PWD\ptest\fake.js" -PassThru; Start-Sleep 2
$block = [regex]::Match($script, '(?s)  if \(\$job\.cover\) \{.*?\n  \}\r?\n').Value
Write-Host "cover block: $($block.Length) chars"
Invoke-Expression $block
$ok = 0; $bad = 0
function T($n, $c) { if ($c) { $script:ok++; Write-Host "ok   $n" } else { $script:bad++; Write-Host "FAIL $n" } }
T 'cover.jpg made' ((Test-Path "$work\cover.jpg") -and (Get-Item "$work\cover.jpg").Length -gt 20000)
T 'uploaded to /api/reels/cover as JPEG' ((Get-Content got.txt -Raw) -match 'PUT /api/reels/cover\?id=VIDEO000001&n=1 \d+ image/jpeg')
T 'no cover problem logged' (-not $script:logged)
Stop-Process -Id $srv.Id
Write-Host "$ok passed, $bad failed"; if ($bad) { exit 1 }
