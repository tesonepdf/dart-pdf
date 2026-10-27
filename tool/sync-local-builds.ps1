$ErrorActionPreference = 'Stop'

$repository = 'tesonepdf/dart-pdf'
$keep = 4
$projectRoot = Split-Path -Parent $PSScriptRoot
$androidDirectory = Join-Path $projectRoot 'apk\android'
$windowsDirectory = Join-Path $projectRoot 'apk\windows'
$headers = @{
    'Accept' = 'application/vnd.github+json'
    'User-Agent' = 'DartPDF-local-build-sync'
}

New-Item -ItemType Directory -Path $androidDirectory, $windowsDirectory -Force | Out-Null

$releases = Invoke-RestMethod `
    -Uri "https://api.github.com/repos/$repository/releases?per_page=100" `
    -Headers $headers

$latest = @(
    foreach ($release in $releases) {
        if ($release.tag_name -match '^build-(\d+)$') {
            [pscustomobject]@{ Number = [int]$Matches[1]; Release = $release }
        }
    }
) | Sort-Object Number -Descending | Select-Object -First 1

if (-not $latest) {
    throw 'No published build found.'
}

$number = $latest.Number
$apkTarget = Join-Path $androidDirectory "DartPDF-build-$number.apk"
$windowsTarget = Join-Path $windowsDirectory "DartPDF-build-$number-windows-x64.zip"

if ((Test-Path -LiteralPath $apkTarget) -and (Test-Path -LiteralPath $windowsTarget)) {
    Write-Output "Build #$number already present."
}
else {
    $assets = @($latest.Release.assets)
    $apk = $assets | Where-Object name -eq 'DartPDF-Android.apk' | Select-Object -First 1
    if (-not $apk) {
        $apk = $assets | Where-Object name -eq 'app-arm64-v8a.apk' | Select-Object -First 1
    }
    $windows = $assets | Where-Object name -eq 'windows-x64.zip' | Select-Object -First 1

    if (-not $apk) { throw "Build $number has no Android APK asset." }
    if (-not $windows) { throw "Build $number has no Windows portable package." }

    $apkTemp = "$apkTarget.part"
    $windowsTemp = "$windowsTarget.part"
    try {
        Invoke-WebRequest -Uri $apk.browser_download_url -Headers $headers -OutFile $apkTemp
        Invoke-WebRequest -Uri $windows.browser_download_url -Headers $headers -OutFile $windowsTemp
        Move-Item -LiteralPath $apkTemp -Destination $apkTarget -Force
        Move-Item -LiteralPath $windowsTemp -Destination $windowsTarget -Force
    }
    finally {
        Remove-Item -LiteralPath $apkTemp, $windowsTemp -Force -ErrorAction SilentlyContinue
    }
    Write-Output "Downloaded build #$number."
}

function Remove-OldBuilds($directory, $filter, $pattern) {
    Get-ChildItem -LiteralPath $directory -Filter $filter -File |
        Where-Object { $_.Name -match $pattern } |
        Sort-Object { [int]([regex]::Match($_.Name, $pattern).Groups[1].Value) } -Descending |
        Select-Object -Skip $keep |
        Remove-Item -Force
}

Remove-OldBuilds $androidDirectory 'DartPDF-build-*.apk' '^DartPDF-build-(\d+)\.apk$'
Remove-OldBuilds $windowsDirectory 'DartPDF-build-*-windows-x64.zip' '^DartPDF-build-(\d+)-windows-x64\.zip$'
