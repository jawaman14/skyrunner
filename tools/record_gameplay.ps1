param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [string]$CaptureDirectory = (Join-Path $env:TEMP 'skyrunner-gameplay-captures')
)
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path $PSScriptRoot -Parent
$mediaDirectory = Join-Path $projectDirectory 'docs/media'
New-Item -ItemType Directory -Force -Path $CaptureDirectory, $mediaDirectory | Out-Null
$clips = @(
    @{Name='services'; Script='services_tour'; Args=@()},
    @{Name='opening'; Script='employment_tour'; Args=@()},
    @{Name='interface'; Script='ui_tour'; Args=@()},
    @{Name='coast-logistics'; Script='city_tour'; Args=@()},
    @{Name='turf-war'; Script='ground_tour'; Args=@()},
    @{Name='flight-police'; Script='demo'; Args=@('--','west','all_in','evasive','101','low','90','16.5','clear')}
)
foreach ($clip in $clips) {
    $rawPath = Join-Path $CaptureDirectory ($clip.Name + '.avi')
    $logPath = Join-Path $CaptureDirectory ($clip.Name + '.log')
    $outputPath = Join-Path $mediaDirectory ($clip.Name + '.mp4')
    Write-Output "Recording $($clip.Name)"
    & $Godot --path $projectDirectory --rendering-method gl_compatibility --resolution 1280x720 --write-movie $rawPath --fixed-fps 15 --script "res://tools/$($clip.Script).gd" @($clip.Args) *> $logPath
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $logPath -Pattern 'SCRIPT ERROR|Parse Error|Assertion failed' -Quiet)) {
        throw "Capture failed: $logPath"
    }
    & ffmpeg -hide_banner -loglevel error -y -i $rawPath -an -c:v libx264 -crf 26 -preset medium -pix_fmt yuv420p -movflags +faststart $outputPath
    if ($LASTEXITCODE -ne 0) { throw "Encoding failed: $outputPath" }
    & ffprobe -v error -show_entries format=duration,size -of json $outputPath
    if ($LASTEXITCODE -ne 0) { throw "Media verification failed: $outputPath" }
}

$manifestClips = @()
foreach ($clip in $clips) {
    $videoPath = Join-Path $mediaDirectory ($clip.Name + '.mp4')
    $metadata = (& ffprobe -v error -show_entries format=duration,size:stream=codec_name,width,height,r_frame_rate -of json $videoPath) | ConvertFrom-Json
    $posterPath = Join-Path $mediaDirectory ($clip.Name + '.jpg')
    $posterTime = [double]::Parse($metadata.format.duration, [Globalization.CultureInfo]::InvariantCulture) * 0.4
    & ffmpeg -hide_banner -loglevel error -y -ss $posterTime.ToString([Globalization.CultureInfo]::InvariantCulture) -i $videoPath -vf 'scale=640:-1' -frames:v 1 $posterPath
    if ($LASTEXITCODE -ne 0) { throw "Poster failed: $posterPath" }
    $manifestClips += @{file=($clip.Name + '.mp4'); sha256=(Get-FileHash -LiteralPath $videoPath -Algorithm SHA256).Hash.ToLower(); format=$metadata.format; streams=$metadata.streams}
}
$manifest = @{date=(Get-Date -Format 'yyyy-MM-dd'); baseline=(git -C $projectDirectory rev-parse HEAD); renderer='gl_compatibility'; scripted=$true; audio=$false; clips=$manifestClips}
$manifest | ConvertTo-Json -Depth 10 | Set-Content -Encoding utf8 (Join-Path $mediaDirectory 'manifest.json')
