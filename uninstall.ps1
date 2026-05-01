param(
    [string]$CodexHome = (Join-Path $env:USERPROFILE ".codex")
)

$ErrorActionPreference = "Stop"

function Remove-TomlTable([string]$Text, [string]$TableName) {
    $escaped = [regex]::Escape($TableName)
    $pattern = "(?ms)^\[$escaped\]\r?\n.*?(?=^\[|\z)"
    return [regex]::Replace($Text, $pattern, "").TrimEnd()
}

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $encoding)
}

function Read-Utf8([string]$Path) {
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

$ConfigPath = Join-Path $CodexHome "config.toml"
$AgentsPath = Join-Path $CodexHome "AGENTS.md"
$SkillPath = Join-Path $CodexHome "skills\claude-code-builder"
$McpPath = Join-Path $CodexHome "mcp-servers\claude-code-builder"

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupRoot = Join-Path $CodexHome "backups\claude-code-builder-uninstall-$timestamp"
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

foreach ($path in @($ConfigPath, $AgentsPath, $SkillPath, $McpPath)) {
    if (Test-Path -LiteralPath $path) {
        Copy-Item -LiteralPath $path -Destination $backupRoot -Recurse -Force
    }
}

if (Test-Path -LiteralPath $ConfigPath) {
    $configText = Read-Utf8 $ConfigPath
    $configText = Remove-TomlTable $configText "mcp_servers.claude-code-builder"
    Write-Utf8NoBom $ConfigPath ($configText.TrimEnd() + "`r`n")
}

if (Test-Path -LiteralPath $AgentsPath) {
    $agentsText = Read-Utf8 $AgentsPath
    $begin = "<!-- CLAUDE_CODE_BUILDER_BEGIN -->"
    $end = "<!-- CLAUDE_CODE_BUILDER_END -->"
    $markerPattern = "(?ms)$([regex]::Escape($begin)).*?$([regex]::Escape($end))"
    $agentsText = [regex]::Replace($agentsText, $markerPattern, "").TrimEnd()
    Write-Utf8NoBom $AgentsPath ($agentsText + "`r`n")
}

foreach ($path in @($SkillPath, $McpPath)) {
    if (Test-Path -LiteralPath $path) {
        $resolved = (Resolve-Path -LiteralPath $path).Path
        if ($resolved.StartsWith((Resolve-Path -LiteralPath $CodexHome).Path)) {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}

Write-Output "Uninstalled claude-code-builder from $CodexHome"
Write-Output "Backup: $backupRoot"
