param(
    [string]$CodexHome = (Join-Path $env:USERPROFILE ".codex")
)

$ErrorActionPreference = "Stop"
$PackageRoot = $PSScriptRoot

function Ensure-Dir([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

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

$SkillSource = Join-Path $PackageRoot "codex\skills\claude-code-builder"
$McpSource = Join-Path $PackageRoot "codex\mcp-servers\claude-code-builder"

if (-not (Test-Path -LiteralPath (Join-Path $SkillSource "SKILL.md"))) {
    throw "Missing packaged Skill: $SkillSource"
}
if (-not (Test-Path -LiteralPath (Join-Path $McpSource "server.py"))) {
    throw "Missing packaged MCP server: $McpSource"
}

Ensure-Dir $CodexHome

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupRoot = Join-Path $CodexHome "backups\claude-code-builder-$timestamp"
Ensure-Dir $backupRoot

$ConfigPath = Join-Path $CodexHome "config.toml"
$AgentsPath = Join-Path $CodexHome "AGENTS.md"
$SkillDest = Join-Path $CodexHome "skills\claude-code-builder"
$McpDest = Join-Path $CodexHome "mcp-servers\claude-code-builder"

foreach ($path in @($ConfigPath, $AgentsPath, $SkillDest, $McpDest)) {
    if (Test-Path -LiteralPath $path) {
        Copy-Item -LiteralPath $path -Destination $backupRoot -Recurse -Force
    }
}

Ensure-Dir (Split-Path -Parent $SkillDest)
Ensure-Dir (Split-Path -Parent $McpDest)
Ensure-Dir $SkillDest
Ensure-Dir $McpDest

Copy-Item -Path (Join-Path $SkillSource "*") -Destination $SkillDest -Recurse -Force
Copy-Item -Path (Join-Path $McpSource "*") -Destination $McpDest -Recurse -Force

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    New-Item -ItemType File -Path $ConfigPath -Force | Out-Null
}

$serverPath = Join-Path $McpDest "server.py"
$serverTomlPath = $serverPath.Replace("'", "''")
$configText = Read-Utf8 $ConfigPath
$configText = Remove-TomlTable $configText "mcp_servers.claude-code-builder"
$configBlock = @"

[mcp_servers.claude-code-builder]
type = "stdio"
command = "python"
args = ['$serverTomlPath']
"@
Write-Utf8NoBom $ConfigPath ($configText.TrimEnd() + "`r`n" + $configBlock.TrimStart() + "`r`n")

if (-not (Test-Path -LiteralPath $AgentsPath)) {
    New-Item -ItemType File -Path $AgentsPath -Force | Out-Null
}

$agentsText = Read-Utf8 $AgentsPath
$begin = "<!-- CLAUDE_CODE_BUILDER_BEGIN -->"
$end = "<!-- CLAUDE_CODE_BUILDER_END -->"
$markerPattern = "(?ms)$([regex]::Escape($begin)).*?$([regex]::Escape($end))"
$agentsText = [regex]::Replace($agentsText, $markerPattern, "").TrimEnd()

$agentsBody = @'
# Claude Code Builder

Claude Code Builder is available as a direct external implementation subagent through the `claude-code-builder` MCP server and the `$claude-code-builder` skill.

Default policy:
- Codex remains the primary controller, planner, integrator, and final reviewer.
- Use Codex internal agents for exploration, implementation, and review when they fit the task.
- Use Claude Code Builder when the user explicitly asks for Claude, Claude Code, an external subagent, or parallel agents to write code.
- Prefer bounded implementation tasks with clear file/path ownership.
- Do not use external multi-CLI orchestrators or Gemini unless the user explicitly asks.
- For parallel Claude workers, assign disjoint owned paths and avoid overlapping edits.
- Tell Claude workers they are not alone in the codebase, must not revert edits made by others, and must report changed files, commands run, and blockers.
- Claude Builder is implementation-oriented. Trigger it similarly to Codex worker subagents when the user wants delegated code changes, but keep Codex as the planner/integrator/reviewer.
- Claude Builder injects Claude native agents `codex_builder`, `codex_explorer`, and `codex_reviewer`.
- Claude may use explorer/reviewer internally for read-only help on larger tasks.
- Claude Builder allows common verification commands such as `npm test`, `node *`, `python -m pytest *`, `pytest *`, and read-only `git status/diff`.
- Codex should still run final verification.

Common MCP tools:
- `claude_builder_doctor`
- `claude_builder_run`
- `claude_builder_parallel`
'@

$agentsBlock = $begin + "`r`n" + $agentsBody.Trim() + "`r`n" + $end

Write-Utf8NoBom $AgentsPath ($agentsText + "`r`n`r`n" + $agentsBlock.Trim() + "`r`n")

python -m py_compile $serverPath

Write-Output "Installed claude-code-builder into $CodexHome"
Write-Output "Backup: $backupRoot"
Write-Output "Run: codex mcp list"
