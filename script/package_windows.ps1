param(
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"

$AppName = "Alan Beckers Stickfigures"
$Vendor = "Skittlq"
$UpgradeUuid = "9f3812e2-0a9a-4e0c-9f74-0ddf383d2ca0"

$RootDir = Resolve-Path (Join-Path $PSScriptRoot "..")
$DistDir = Join-Path $RootDir "dist"
$InputDir = Join-Path $DistDir "windows-input"
$OutputExe = Join-Path $DistDir "Alan-Beckers-Stickfigures-Windows.exe"
$IconPath = Join-Path $RootDir "img\icon.ico"

if ($Version -notmatch '^\d+(\.\d+){0,3}$') {
    $Version = "1.0.0"
}

$JPackage = $null
if ($env:JAVA_HOME) {
    $Candidate = Join-Path $env:JAVA_HOME "bin\jpackage.exe"
    if (Test-Path $Candidate) {
        $JPackage = $Candidate
    }
}

if (-not $JPackage) {
    $Command = Get-Command "jpackage.exe" -ErrorAction SilentlyContinue
    if ($Command) {
        $JPackage = $Command.Source
    }
}

if (-not $JPackage) {
    throw "jpackage.exe was not found. Install JDK 17 or newer before running this script."
}

Remove-Item -Recurse -Force $InputDir -ErrorAction SilentlyContinue
Remove-Item -Force $OutputExe -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $InputDir | Out-Null
New-Item -ItemType Directory -Force $DistDir | Out-Null

Copy-Item (Join-Path $RootDir "AlansStickfigures.jar") $InputDir
Copy-Item (Join-Path $RootDir "conf") $InputDir -Recurse
Copy-Item (Join-Path $RootDir "img") $InputDir -Recurse
Copy-Item (Join-Path $RootDir "lib") $InputDir -Recurse

$PackageArgs = @(
    "--type", "exe",
    "--dest", $DistDir,
    "--input", $InputDir,
    "--name", $AppName,
    "--main-jar", "AlansStickfigures.jar",
    "--main-class", "com.group_finity.mascot.Main",
    "--app-version", $Version,
    "--vendor", $Vendor,
    "--description", "Alan Becker's Stickfigures Unofficial",
    "--win-dir-chooser",
    "--win-menu",
    "--win-menu-group", $AppName,
    "--win-shortcut",
    "--win-per-user-install",
    "--win-upgrade-uuid", $UpgradeUuid
)

if (Test-Path $IconPath) {
    $PackageArgs += @("--icon", $IconPath)
}

& $JPackage @PackageArgs

$GeneratedExe = Get-ChildItem $DistDir -Filter "*.exe" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $GeneratedExe) {
    throw "jpackage finished without creating an .exe file in $DistDir"
}

Move-Item -Force $GeneratedExe.FullName $OutputExe
Write-Output $OutputExe
