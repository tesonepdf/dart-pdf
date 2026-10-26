$ErrorActionPreference = 'Stop'

$repository = 'tesonepdf/dart-pdf'
$projectRoot = Split-Path -Parent $PSScriptRoot
$androidDirectory = Join-Path $projectRoot 'apk\android'
$windowsDirectory = Join-Path $projectRoot 'apk\windows'
$stagingDirectory = Join-Path $env:TEMP "dartpdf-builds-$([guid]::NewGuid().ToString('N'))"
$headers = @{
    'Accept' = 'application/vnd.github+json'
    'User-Agent' = 'DartPDF-local-build-sync'
}

try {
    New-Item -ItemType Directory -Path (Join-Path $stagingDirectory 'android') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $stagingDirectory 'windows') -Force | Out-Null

    $releases = Invoke-RestMethod `
        -Uri "https://api.github.com/repos/$repository/releases?per_page=100" `
        -Headers $headers

    $builds = @(
        foreach ($release in $releases) {
            if ($release.tag_name -match '^build-(\d+)$') {
                [pscustomobject]@{
                    Number = [int]$Matches[1]
                    Release = $release
                }
            }
        }
    ) | Sort-Object Number -Descending | Select-Object -First 4

    if ($builds.Count -ne 4) {
        throw "Expected four published builds; found $($builds.Count)."
    }

    foreach ($build in $builds) {
        $assets = @($build.Release.assets)
        $apk = $assets | Where-Object name -eq 'DartPDF-Android.apk' | Select-Object -First 1
        if (-not $apk) {
            $apk = $assets | Where-Object name -eq 'app-arm64-v8a.apk' | Select-Object -First 1
        }
        $windows = $assets | Where-Object name -eq 'windows-x64.zip' | Select-Object -First 1

        if (-not $apk) {
            throw "Build $($build.Number) has no Android APK asset."
        }
        if (-not $windows) {
            throw "Build $($build.Number) has no Windows portable package."
        }

        Invoke-WebRequest -Uri $apk.browser_download_url -Headers $headers `
            -OutFile (Join-Path $stagingDirectory "android\DartPDF-build-$($build.Number).apk")
        Invoke-WebRequest -Uri $windows.browser_download_url -Headers $headers `
            -OutFile (Join-Path $stagingDirectory "windows\DartPDF-build-$($build.Number)-windows-x64.zip")
        Write-Output "Downloaded build #$($build.Number)."
    }

    New-Item -ItemType Directory -Path $androidDirectory, $windowsDirectory -Force | Out-Null

    Get-ChildItem -LiteralPath $androidDirectory -Filter 'DartPDF-build-*.apk' -File |
        Remove-Item -Force
    Get-ChildItem -LiteralPath $windowsDirectory -Filter 'DartPDF-build-*-windows-x64.zip' -File |
        Remove-Item -Force

    Get-ChildItem -LiteralPath (Join-Path $stagingDirectory 'android') -File |
        Move-Item -Destination $androidDirectory
    Get-ChildItem -LiteralPath (Join-Path $stagingDirectory 'windows') -File |
        Move-Item -Destination $windowsDirectory

    Write-Output "Android APKs: $androidDirectory"
    Write-Output "Windows packages: $windowsDirectory"
}
finally {
    if (Test-Path -LiteralPath $stagingDirectory) {
        Remove-Item -LiteralPath $stagingDirectory -Recurse -Force
    }
}
