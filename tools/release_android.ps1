# Builds signed split-per-ABI APKs plus version.json for in-app updates.
#   .\tools\release_android.ps1 -Notes "What changed"            # build only
#   .\tools\release_android.ps1 -Notes "..." -Publish            # build + GitHub release
#   add -Required to force everyone below this build to update.
# Bump `version:` in pubspec.yaml (both name and +build) before every release.
param(
  [Parameter(Mandatory = $true)][string]$Notes,
  [switch]$Required,
  [switch]$Publish
)
$ErrorActionPreference = 'Stop'
$repo = 'Linaxme/hisab_app'
$root = Split-Path $PSScriptRoot -Parent

$pubspec = Get-Content "$root\pubspec.yaml" -Raw -Encoding UTF8
if ($pubspec -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)') { throw 'version: x.y.z+n not found in pubspec.yaml' }
$name = $Matches[1]
$build = [int]$Matches[2]
if ($build -ge 1000) { throw 'build number must stay below 1000 (split APKs add abi * 1000)' }
if (-not (Test-Path "$root\android\key.properties")) { throw 'android\key.properties missing: release key required' }
$tag = "v$name"

# Gradle and aapt fail on the non-ASCII project path, so build from an ASCII copy.
$work = Join-Path $env:TEMP 'hisab_analyze'
robocopy "$root\android" "$work\android" /MIR /XD build .gradle .cxx /NFL /NDL /NJH /NJS | Out-Null
robocopy "$root\lib" "$work\lib" /MIR /NFL /NDL /NJH /NJS | Out-Null
robocopy "$root\assets" "$work\assets" /MIR /NFL /NDL /NJH /NJS | Out-Null
Copy-Item "$root\pubspec.yaml", "$root\pubspec.lock" $work -Force
Push-Location $work
# Flutter prints warnings on stderr; only the exit code means failure.
$ErrorActionPreference = 'Continue'
try {
  flutter build apk --release --split-per-abi
  if ($LASTEXITCODE -ne 0) { throw 'flutter build failed' }
} finally { Pop-Location; $ErrorActionPreference = 'Stop' }

$out = Join-Path (Split-Path $root -Parent) "releases\$tag"
New-Item -ItemType Directory -Force $out | Out-Null
$base = "https://github.com/$repo/releases/download/$tag"
$apks = [ordered]@{}
$files = @()
foreach ($abi in 'arm64-v8a', 'armeabi-v7a', 'x86_64') {
  $file = "amar-dokan-$name-$abi.apk"
  Copy-Item "$work\build\app\outputs\flutter-apk\app-$abi-release.apk" "$out\$file" -Force
  $apks[$abi] = [ordered]@{ url = "$base/$file"; sha256 = (Get-FileHash "$out\$file" -Algorithm SHA256).Hash.ToLower() }
  $files += "$out\$file"
}

$manifest = [ordered]@{
  version  = $name
  build    = $build
  minBuild = $(if ($Required) { $build } else { 0 })
  notes    = $Notes
  apks     = $apks
}
$utf8 = New-Object System.Text.UTF8Encoding $false
# Escape non-ASCII so app builds that decode the body as Latin-1 (<= 1.0.6) still read Bengali notes.
$json = [regex]::Replace(($manifest | ConvertTo-Json -Depth 5), '[^\x00-\x7F]', { param($m) '\u{0:x4}' -f [int][char]$m.Value })
[IO.File]::WriteAllText("$out\version.json", $json, $utf8)
[IO.File]::WriteAllText("$out\notes.md", $Notes, $utf8)
$files += "$out\version.json"
Write-Host "Built $tag (build $build) in $out"

if ($Publish) {
  $ErrorActionPreference = 'Continue'
  gh release create $tag @files --repo $repo --title "Amar Dokan $name" --notes-file "$out\notes.md" --latest
  if ($LASTEXITCODE -ne 0) { throw 'gh release create failed' }
  Write-Host "Published https://github.com/$repo/releases/tag/$tag"
}
