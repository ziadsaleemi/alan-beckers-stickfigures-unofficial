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
$LicensePath = Join-Path $RootDir "LICENSE"

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

function Get-SignToolPath {
    $Command = Get-Command "signtool.exe" -ErrorAction SilentlyContinue
    if ($Command) {
        return $Command.Source
    }

    $WindowsKits = Join-Path ${env:ProgramFiles(x86)} "Windows Kits\10\bin"
    if (Test-Path $WindowsKits) {
        $Candidate = Get-ChildItem $WindowsKits -Recurse -Filter "signtool.exe" -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match "\\x64\\signtool\.exe$" } |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        if ($Candidate) {
            return $Candidate.FullName
        }
    }

    return $null
}

function Invoke-InstallerSigning {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallerPath
    )

    $RequireSigning = $env:WINDOWS_REQUIRE_SIGNING -eq "1"
    $CertificatePath = $env:WINDOWS_CODESIGN_PFX_PATH
    $CertificatePassword = $env:WINDOWS_CODESIGN_PFX_PASSWORD
    $TemporaryCertificatePath = $null

    if (-not $CertificatePath -and $env:WINDOWS_CODESIGN_PFX_B64) {
        $TemporaryCertificatePath = Join-Path $env:TEMP "alan-beckers-stickfigures-codesign.pfx"
        [IO.File]::WriteAllBytes($TemporaryCertificatePath, [Convert]::FromBase64String($env:WINDOWS_CODESIGN_PFX_B64))
        $CertificatePath = $TemporaryCertificatePath
    }

    if (-not $CertificatePath) {
        if ($RequireSigning) {
            throw "WINDOWS_REQUIRE_SIGNING=1 but WINDOWS_CODESIGN_PFX_B64 or WINDOWS_CODESIGN_PFX_PATH is not set."
        }
        Write-Output "Windows code signing skipped because no signing certificate was configured."
        return
    }

    if (-not (Test-Path $CertificatePath)) {
        throw "Windows code signing certificate was not found: $CertificatePath"
    }

    if (-not $CertificatePassword) {
        throw "WINDOWS_CODESIGN_PFX_PASSWORD is required when signing the Windows installer."
    }

    $SignTool = Get-SignToolPath
    if (-not $SignTool) {
        throw "signtool.exe was not found. Install the Windows SDK or use a runner image that includes it."
    }

    $TimestampUrl = $env:WINDOWS_CODESIGN_TIMESTAMP_URL
    if (-not $TimestampUrl) {
        $TimestampUrl = "http://timestamp.digicert.com"
    }

    try {
        & $SignTool sign `
            /f $CertificatePath `
            /p $CertificatePassword `
            /fd SHA256 `
            /tr $TimestampUrl `
            /td SHA256 `
            /v `
            $InstallerPath

        & $SignTool verify /pa /v $InstallerPath
    } finally {
        if ($TemporaryCertificatePath -and (Test-Path $TemporaryCertificatePath)) {
            Remove-Item -Force $TemporaryCertificatePath
        }
    }
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

if (Test-Path $LicensePath) {
    $PackageArgs += @("--license-file", $LicensePath)
}

& $JPackage @PackageArgs

$GeneratedExe = Get-ChildItem $DistDir -Filter "*.exe" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $GeneratedExe) {
    throw "jpackage finished without creating an .exe file in $DistDir"
}

Move-Item -Force $GeneratedExe.FullName $OutputExe
Invoke-InstallerSigning -InstallerPath $OutputExe
Write-Output $OutputExe
