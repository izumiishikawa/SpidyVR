# Builds Spidy and copies the launcher, the game modules and the Python tools into a Spidy folder
# already extracted on this PC, to play a change at once. The first run keeps that folder's own
# files in backup-original\ there; -Restore puts them back.
#   .\tools\deploy-local.ps1                     # build, test, copy
#   .\tools\deploy-local.ps1 -NoBuild            # copy what build\windows-ninja holds
#   .\tools\deploy-local.ps1 -Restore            # the folder's own files again
param([string]$Target = (Join-Path $env:USERPROFILE 'Downloads\Spidy-0.3.6-win64\Spidy-0.3.6'),
      [switch]$NoBuild, [switch]$Restore)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $Target 'Spidy Launcher.exe'))) {
    throw "No Spidy in $Target. Pass the folder that holds 'Spidy Launcher.exe' as -Target."
}
if (Get-Process -Name 'Spider-Man', 'spidy_launcher', 'Spidy Launcher' -ErrorAction SilentlyContinue) {
    throw 'Close the game and the Spidy launcher first: Windows keeps their files in use.'
}
$modules = @('spidy_headset_probe.exe', 'spidy_bridge.dll', 'spidy_render_probe.dll', 'spidy_ray_bridge.dll',
             'spidy_movement_bridge.dll', 'spidy_stereo_probe.dll', 'spidy_render_memory.dll')
# Where each file goes in the extracted folder, from where it comes in this checkout.
$files = [ordered]@{ 'Spidy Launcher.exe' = 'build\windows-ninja\spidy_launcher.exe' }
foreach ($module in $modules) { $files["build\windows-ninja\$module"] = "build\windows-ninja\$module" }
foreach ($tool in Get-ChildItem -LiteralPath (Join-Path $root 'tools') -Filter '*.py') {
    $files["tools\$($tool.Name)"] = "tools\$($tool.Name)"
}
$backup = Join-Path $Target 'backup-original'

if ($Restore) {
    if (-not (Test-Path -LiteralPath $backup)) { throw "No backup in $backup." }
    foreach ($file in Get-ChildItem -LiteralPath $backup -Recurse -File) {
        $relative = $file.FullName.Substring($backup.Length + 1)
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $Target $relative) -Force
    }
    Write-Output "Restored Spidy's own files in $Target."
    return
}

if (-not $NoBuild) {
    & (Join-Path $PSScriptRoot 'build.ps1') -Observer
    if ($LASTEXITCODE) { throw 'Build or tests failed: nothing copied.' }
}
if (-not (Test-Path -LiteralPath $backup)) {
    foreach ($relative in $files.Keys) {
        $source = Join-Path $Target $relative
        if (Test-Path -LiteralPath $source) {
            $destination = Join-Path $backup $relative
            New-Item -ItemType Directory -Force (Split-Path -Parent $destination) | Out-Null
            Copy-Item -LiteralPath $source -Destination $destination
        }
    }
    Write-Output "Kept Spidy's own files in $backup."
}
foreach ($entry in $files.GetEnumerator()) {
    $source = Join-Path $root $entry.Value
    if (-not (Test-Path -LiteralPath $source)) { throw "Missing $($entry.Value). Build first." }
    Copy-Item -LiteralPath $source -Destination (Join-Path $Target $entry.Key) -Force
}
# The web aim's settings (game_tracking's WristAim): the player's own once there.
$aim = Join-Path $Target 'aim.ini'
if (-not (Test-Path -LiteralPath $aim)) { Copy-Item -LiteralPath (Join-Path $root 'docs\aim.ini') -Destination $aim }
Write-Output "Copied this build into $Target. Start 'Spidy Launcher.exe' there."
