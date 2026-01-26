$ErrorActionPreference = 'Stop';
$packageName= 'vibee'
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$url64      = 'https://github.com/gHashTag/vibee-lang/releases/download/v1.0.0/vibee-windows-x64.zip'

$packageArgs = @{
  packageName   = $packageName
  unzipLocation = $toolsDir
  url64bit      = $url64
  checksum64    = 'REPLACE_WITH_ACTUAL_SHA256'
  checksumType64= 'sha256'
}

Install-ChocolateyZipPackage @packageArgs

$binPath = Join-Path $toolsDir 'vibee.exe'
Install-ChocolateyPath $toolsDir 'Machine'
