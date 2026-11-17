<#
  扫码助手 · Windows 打包脚本
  ============================================================
  用法（在 windows 目录或仓库根目录执行都可以，路径已自动处理）：

      powershell -ExecutionPolicy Bypass -File windows\build.ps1

  可选参数：
      -Configuration Debug|Release   默认 Release
      -Runtime win-x64|win-arm64      默认 win-x64
      -SkipTests                      跳过 Core 单元测试
      -FrameworkDependent             生成依赖 .NET 10 运行时的瘦 exe（几 MB，用户需先装运行时）
      -NoZip                          不压缩 zip

  产物：
      windows\dist\ScanCode.exe                     单文件 exe（默认自带运行时，用户无需装 .NET）
      windows\ScanCode-win-x64.exe.sha256           exe 的 SHA256 校验值
      windows\ScanCode-win-x64.zip                  单文件 exe 打成的发布包
#>
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',

    [ValidateSet('win-x64', 'win-arm64')]
    [string]$Runtime = 'win-x64',

    [switch]$SkipTests,
    [switch]$FrameworkDependent,
    [switch]$NoZip
)

$ErrorActionPreference = 'Stop'

$root     = Split-Path -Parent $MyInvocation.MyCommand.Path
$solution = Join-Path $root 'ScanCode.Windows.sln'
$tests    = Join-Path $root 'tests\ScanCode.Core.Tests\ScanCode.Core.Tests.csproj'
$app      = Join-Path $root 'src\ScanCode.App\ScanCode.App.csproj'
$dist     = Join-Path $root 'dist'
$exe      = Join-Path $dist 'ScanCode.exe'
$zip      = Join-Path $root "ScanCode-$Runtime.zip"
$sha      = Join-Path $root "ScanCode-$Runtime.exe.sha256"

function Step([string]$text) {
    Write-Host ''
    Write-Host "==> $text" -ForegroundColor Cyan
}

function Assert-LastExitCode([string]$what) {
    if ($LASTEXITCODE -ne 0) { throw "$what 失败（退出码 $LASTEXITCODE）" }
}

if ($PSVersionTable.PSVersion.Major -lt 5) {
    throw '需要 PowerShell 5.1 或更高版本。'
}

Step '1/5 检查 .NET SDK'
dotnet --version
Assert-LastExitCode '读取 .NET SDK 版本'
Write-Host '提示：需要 .NET 10 SDK；如果提示找不到 dotnet，先装 https://dotnet.microsoft.com/download/dotnet/10.0' -ForegroundColor DarkGray

Step '2/5 还原依赖'
dotnet restore $solution
Assert-LastExitCode '还原依赖'

Step "3/5 编译（$Configuration）"
dotnet build $solution -c $Configuration --no-restore
Assert-LastExitCode '编译'

if (-not $SkipTests) {
    Step '4/5 跑 Core 单元测试'
    dotnet run --project $tests -c $Configuration --no-build
    Assert-LastExitCode '单元测试'
}
else {
    Step '4/5 跳过单元测试'
}

$selfContained = if ($FrameworkDependent) { 'false' } else { 'true' }
Step "5/5 发布单文件 exe（$Runtime，self-contained=$selfContained）"

if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }

dotnet publish $app `
    -c $Configuration `
    -r $Runtime `
    -o $dist `
    -p:SelfContained=$selfContained `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:EnableCompressionInSingleFile=true `
    -p:PublishReadyToRun=false `
    -p:DebugType=None `
    -p:DebugSymbols=false
Assert-LastExitCode '发布'

if (-not (Test-Path $exe)) {
    # 万一 apphost 没生成（例如 RID 拼错），明确报错而不是静默继续。
    throw "没有生成 $exe，请检查上面的 publish 输出。"
}

$info   = Get-Item $exe
$sizeMb = [math]::Round($info.Length / 1MB, 1)
$hash   = (Get-FileHash $exe -Algorithm SHA256).Hash
"$hash  ScanCode.exe" | Set-Content -Path $sha -Encoding ASCII

if (-not $NoZip) {
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path $exe -DestinationPath $zip -Force
    Write-Host "发布包：$zip" -ForegroundColor Green
}

Write-Host ''
Write-Host '构建完成' -ForegroundColor Green
Write-Host "  exe      : $exe  ($sizeMb MB)"
Write-Host "  sha256   : $hash"
Write-Host "  校验文件 : $sha"
if (-not $NoZip) { Write-Host "  zip      : $zip" }
Write-Host ''
Write-Host '下一步：把 ScanCode.exe 拷到 Windows 实机双击运行，首次运行会出现托盘图标，按 Ctrl+Alt+Q 框选二维码。' -ForegroundColor DarkGray
