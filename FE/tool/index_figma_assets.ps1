$ErrorActionPreference = 'Stop'
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('// Generated from downloaded Figma SVG root dimensions. Do not edit asset geometry.')
$lines.Add("const figmaAssets = <String, ({String path, double width, double height})>{")
Get-ChildItem (Join-Path $PSScriptRoot '../../docs/figma-reference/*.txt') | ForEach-Object {
  $node = $_.BaseName
  $source = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
  [regex]::Matches($source, 'const (\w+) = "https://www\.figma\.com/api/mcp/asset/([^\"]+\.svg)"') | ForEach-Object {
    $file = $_.Groups[2].Value
    $path = Join-Path $PSScriptRoot "../assets/figma/$file"
    if (!(Test-Path -LiteralPath $path)) { throw "Missing asset: $file" }
    $root = [regex]::Match((Get-Content -LiteralPath $path -Raw), '<svg[^>]+>').Value
    $w = [regex]::Match($root, '\bwidth="([\d.]+)"').Groups[1].Value
    $h = [regex]::Match($root, '\bheight="([\d.]+)"').Groups[1].Value
    if (!$w -or !$h) { throw "Missing dimensions: $file" }
    $lines.Add("  '$node/$($_.Groups[1].Value)': (path: 'assets/figma/$file', width: $w, height: $h),")
  }
}
$lines.Add('};')
[IO.File]::WriteAllLines((Join-Path $PSScriptRoot '../lib/review/figma_assets.dart'), $lines, [Text.UTF8Encoding]::new($false))
