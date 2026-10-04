param([string]$DeviceId, [string]$ApiBaseUrl, [string]$FlutterPath)
$ErrorActionPreference = 'Stop'
if (-not $env:JAVA_HOME -and (Test-Path 'C:\Program Files\Android\Android Studio\jbr')) {
    $env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
}
if (-not $FlutterPath) {
    $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutterCommand) { $FlutterPath = $flutterCommand.Source }
    else { $FlutterPath = Join-Path $PSScriptRoot '..\..\.tools\flutter\bin\flutter.bat' }
}
if (-not (Test-Path -LiteralPath $FlutterPath)) {
    throw 'Flutter SDK not found. Pass -FlutterPath with the path to flutter.bat.'
}
$FlutterPath = (Resolve-Path -LiteralPath $FlutterPath).Path
$projectPath = $PSScriptRoot
# The Windows Flutter shader compiler fails on some non-ASCII paths.
# Reuse the workspace's short drive only when it points to this same project.
$shortProject = 'R:\Re-view\FE'
if ($projectPath -match '[^\x00-\x7F]') {
    if (-not (Test-Path -LiteralPath 'R:\')) {
        $workspacePath = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
        & subst.exe R: $workspacePath
        if ($LASTEXITCODE -ne 0) { throw 'Unable to create the short R: workspace path.' }
    }
    $mapping = (& subst.exe) -join "`n"
    $workspacePath = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    if ($mapping -notmatch ('(?im)^R:\\: => ' + [regex]::Escape($workspacePath) + '$')) {
        throw 'R: is already used by another location. Run from an ASCII-only workspace path.'
    }
    $projectPath = $shortProject
    # Kotlin's incremental cache cannot relativize C: pub-cache files against R:.
    [Environment]::SetEnvironmentVariable('ORG_GRADLE_PROJECT_kotlin.incremental', 'false', 'Process')
    if ($FlutterPath.StartsWith($workspacePath, [StringComparison]::OrdinalIgnoreCase)) {
        $FlutterPath = 'R:' + $FlutterPath.Substring($workspacePath.Length)
    }
}
Push-Location $projectPath
try {
    & $FlutterPath pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }
    $runArguments = @('run')
    if ($DeviceId) { $runArguments += @('-d', $DeviceId) }
    if ($ApiBaseUrl) { $runArguments += "--dart-define=API_BASE_URL=$ApiBaseUrl" }
    & $FlutterPath @runArguments
    if ($LASTEXITCODE -ne 0) { throw 'flutter run failed.' }
}
finally { Pop-Location }
