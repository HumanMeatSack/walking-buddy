$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$OutputDirectory = Join-Path $ProjectRoot ".build\windows-x64"
$ArchivePath = Join-Path $ProjectRoot ".build\Walking-Buddy-Windows-x64.zip"

if (Test-Path $OutputDirectory) {
    Remove-Item $OutputDirectory -Recurse -Force
}
if (Test-Path $ArchivePath) {
    Remove-Item $ArchivePath -Force
}

dotnet publish (Join-Path $ProjectRoot "Windows\WalkingBuddy.Windows.csproj") `
    --configuration Release `
    --runtime win-x64 `
    --self-contained true `
    --output $OutputDirectory `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:DebugType=None `
    -p:DebugSymbols=false

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Compress-Archive -Path (Join-Path $OutputDirectory "*") -DestinationPath $ArchivePath

Write-Host "Built: $OutputDirectory"
Write-Host "Archive: $ArchivePath"
