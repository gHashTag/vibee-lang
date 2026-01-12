# VIBEE Chocolatey Install Script

$ErrorActionPreference = 'Stop'

$packageName = 'vibee'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$version = '1.0.0'

# Detect architecture
$arch = $env:PROCESSOR_ARCHITECTURE
switch ($arch) {
    "AMD64" { $archType = "x86_64" }
    "ARM64" { $archType = "aarch64" }
    default {
        throw "Unsupported architecture: $arch"
    }
}

$url = "https://github.com/gleam-lang/gleam/releases/download/v$version/gleam-v$version-$archType-pc-windows-msvc.zip"

$packageArgs = @{
    packageName   = $packageName
    unzipLocation = $toolsDir
    url           = $url
    checksum      = 'REPLACE_WITH_ACTUAL_CHECKSUM'
    checksumType  = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs

# Create vibee.exe symlink
$gleamExe = Join-Path $toolsDir "gleam.exe"
$vibeeExe = Join-Path $toolsDir "vibee.exe"

if (Test-Path $gleamExe) {
    Copy-Item $gleamExe $vibeeExe -Force
    Write-Host "VIBEE installed successfully!" -ForegroundColor Green
} else {
    throw "Installation failed: gleam.exe not found"
}
