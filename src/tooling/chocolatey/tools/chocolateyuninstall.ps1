# VIBEE Chocolatey Uninstall Script

$ErrorActionPreference = 'Stop'

$packageName = 'vibee'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

# Remove executables
$gleamExe = Join-Path $toolsDir "gleam.exe"
$vibeeExe = Join-Path $toolsDir "vibee.exe"

if (Test-Path $gleamExe) {
    Remove-Item $gleamExe -Force
}

if (Test-Path $vibeeExe) {
    Remove-Item $vibeeExe -Force
}

Write-Host "VIBEE uninstalled successfully!" -ForegroundColor Green
