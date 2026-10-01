$ErrorActionPreference = 'Stop'
$assetDir = Join-Path $PSScriptRoot '../assets/figma'
New-Item -ItemType Directory -Force $assetDir | Out-Null
$mapping = @{}
Get-ChildItem (Join-Path $PSScriptRoot '../../docs/figma-reference/*.txt') | ForEach-Object {
  $node = $_.BaseName
  $source = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
  [regex]::Matches($source, 'const (\w+) = "(https://www\.figma\.com/api/mcp/asset/[^\"]+)"') | ForEach-Object {
    $url = $_.Groups[2].Value
    $filename = $url.Split('/')[-1]
    $target = Join-Path $assetDir $filename
    if (!(Test-Path -LiteralPath $target)) { Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $target }
    $mapping["$node/$($_.Groups[1].Value)"] = "assets/figma/$filename"
  }
}
$mapping | ConvertTo-Json | Set-Content (Join-Path $assetDir 'manifest.json') -Encoding UTF8
$fontDir = Join-Path $PSScriptRoot '../assets/fonts'
New-Item -ItemType Directory -Force $fontDir | Out-Null
foreach ($font in @('Pretendard-Regular.otf', 'Pretendard-SemiBold.otf', 'Pretendard-Bold.ttf')) {
  Copy-Item -LiteralPath (Join-Path $env:LOCALAPPDATA "Microsoft/Windows/Fonts/$font") -Destination $fontDir
  (Get-Item -LiteralPath (Join-Path $fontDir $font)).IsReadOnly = $false
}
Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/orioncactus/pretendard/main/LICENSE' -OutFile (Join-Path $fontDir 'LICENSE.txt')
Write-Output "Downloaded $($mapping.Count) Figma references and Pretendard fonts."
