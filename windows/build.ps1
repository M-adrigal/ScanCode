$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$solution = Join-Path $root 'ScanCode.Windows.sln'
$tests = Join-Path $root 'tests\ScanCode.Core.Tests\ScanCode.Core.Tests.csproj'
$app = Join-Path $root 'src\ScanCode.App\ScanCode.App.csproj'
$dist = Join-Path $root 'dist'

dotnet restore $solution
dotnet build $solution -c Release --no-restore
dotnet test $tests -c Release --no-build

if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
dotnet publish $app -c Release -r win-x64 --self-contained true `
  -p:PublishSingleFile=false -p:PublishReadyToRun=false -o $dist

$zip = Join-Path $root 'ScanCode-win-x64.zip'
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $dist '*') -DestinationPath $zip -Force

Write-Host "built: $zip"
