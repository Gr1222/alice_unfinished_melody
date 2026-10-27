param(
    [string]$GodotPath = 'C:/Users/sophi/Desktop/Godot_v4.7.2-stable_win64_console.exe'
)
$ErrorActionPreference = 'Stop'
$projectPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Godot executable not found.' }
Push-Location -LiteralPath $projectPath
try {
    & $GodotPath --headless --editor --path . --import
    if ($LASTEXITCODE -ne 0) { throw 'Source import failed.' }
    & $GodotPath --path . res://scenes/art/ForestStudy.tscn -- --bake-forest-2d
    if ($LASTEXITCODE -ne 0) { throw 'Layer bake failed.' }
    & $GodotPath --headless --editor --path . --import
    if ($LASTEXITCODE -ne 0) { throw 'Image import failed.' }
    Write-Output 'Ready: open scenes/art/ForestPrerender2D.tscn and press F6.'
} finally {
    Pop-Location
}
