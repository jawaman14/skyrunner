param(
    [string]$Godot = "",
    [string]$Output = ""
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
# Lock the entire Godot run.
if ($env:SKYRUNNER_CAPTURE_LOCKED -ne '1') {
    $env:SKYRUNNER_CAPTURE_LOCKED = '1'
    try {
        Push-Location $root
        $runnerArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath)
        if ($Godot -ne '') { $runnerArgs += @('-Godot', $Godot) }
        if ($Output -ne '') { $runnerArgs += @('-Output', $Output) }
        python tools/collab/run_locked.py -- powershell @runnerArgs
        if ($LASTEXITCODE -ne 0) { throw "Vehicle capture failed (exit $LASTEXITCODE)." }
    } finally {
        Pop-Location
        Remove-Item Env:SKYRUNNER_CAPTURE_LOCKED -ErrorAction SilentlyContinue
    }
    return
}

if ($Godot -eq '') { $Godot = $env:GODOT }
if ($Godot -eq '') { throw 'Godot path is missing; pass -Godot or configure SKYRUNNER_GODOT.' }
if ($Output -eq '') {
    $Output = Join-Path $root ('.build/visual-audit/vehicles-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Path $Output -Force | Out-Null
$Output = (Resolve-Path -LiteralPath $Output).Path

try {
    Push-Location $root
    & $Godot --rendering-method gl_compatibility --rendering-driver opengl3 --audio-driver Dummy --path $root --script res://tools/capture_period_vehicles.gd -- $Output
    if ($LASTEXITCODE -ne 0) {
        throw "Vehicle capture failed (exit $LASTEXITCODE)."
    }
    $images = @(Get-ChildItem -LiteralPath $Output -Filter '*.png' -File)
    if ($images.Count -ne 16) {
        throw "Vehicle capture produced $($images.Count) images; expected 16."
    }
    Write-Output "Captured 16 vehicle images in $Output"
} finally {
    Pop-Location
}
