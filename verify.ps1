param(
    [string]$CodexHome = (Join-Path $env:USERPROFILE ".codex"),
    [switch]$RunSmoke
)

$ErrorActionPreference = "Stop"

$SkillPath = Join-Path $CodexHome "skills\claude-code-builder\SKILL.md"
$ServerPath = Join-Path $CodexHome "mcp-servers\claude-code-builder\server.py"
$ConfigPath = Join-Path $CodexHome "config.toml"

if (-not (Test-Path -LiteralPath $SkillPath)) {
    throw "Missing Skill: $SkillPath"
}
if (-not (Test-Path -LiteralPath $ServerPath)) {
    throw "Missing MCP server: $ServerPath"
}
if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Missing Codex config: $ConfigPath"
}

python -m py_compile $ServerPath
python -c "import tomllib,sys; tomllib.load(open(sys.argv[1],'rb')); print('config.toml OK')" $ConfigPath
if ($LASTEXITCODE -ne 0) {
    throw "config.toml validation failed"
}

$claudeVersion = & claude --version
Write-Output "Claude Code: $claudeVersion"

$init = [pscustomobject]@{jsonrpc='2.0';id=1;method='initialize';params=[pscustomobject]@{}} | ConvertTo-Json -Compress
$doctor = [pscustomobject]@{jsonrpc='2.0';id=2;method='tools/call';params=[pscustomobject]@{name='claude_builder_doctor';arguments=[pscustomobject]@{}}} | ConvertTo-Json -Compress -Depth 6
$doctorOutput = @($init, $doctor) | python $ServerPath
Write-Output $doctorOutput

if ($RunSmoke) {
    $tmp = Join-Path $env:TEMP ("claude-builder-smoke-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path (Join-Path $tmp "src") | Out-Null
    Set-Content -LiteralPath (Join-Path $tmp "src\smoke.txt") -Value "start" -Encoding UTF8

    $task = "Append the line PORTABLE_SMOKE_OK to src/smoke.txt. No tests are needed. Finish with RESULT_STATUS: success."
    $call = [pscustomobject]@{
        jsonrpc='2.0'
        id=3
        method='tools/call'
        params=[pscustomobject]@{
            name='claude_builder_run'
            arguments=[pscustomobject]@{
                repo=$tmp
                task_name='portable-smoke'
                task=$task
                owned_paths=@('src/smoke.txt')
                verification='No tests needed'
                effort='low'
                permission_mode='acceptEdits'
                timeout_seconds=300
            }
        }
    } | ConvertTo-Json -Compress -Depth 10
    $smokeOutput = @($init, $call) | python $ServerPath
    Write-Output $smokeOutput

    Remove-Item -LiteralPath $tmp -Recurse -Force
}

Write-Output "Verification completed."
