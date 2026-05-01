# Claude Code Builder Portable

This package installs the Codex-side Claude Code Builder integration on another Windows machine.

It contains:

- Codex Skill: `claude-code-builder`
- Codex MCP server: `claude-code-builder`
- Install, uninstall, and verify scripts

## Requirements

- Codex CLI installed and logged in
- Claude Code CLI installed and logged in
- Python available as `python`

Check:

```powershell
codex --version
claude --version
python --version
```

## Install

From this folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
powershell -ExecutionPolicy Bypass -File .\verify.ps1
```

By default it installs to:

```text
%USERPROFILE%\.codex
```

Custom Codex home:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -CodexHome "D:\Somewhere\.codex"
```

## What Gets Installed

```text
%USERPROFILE%\.codex\skills\claude-code-builder\SKILL.md
%USERPROFILE%\.codex\mcp-servers\claude-code-builder\server.py
%USERPROFILE%\.codex\config.toml
%USERPROFILE%\.codex\AGENTS.md
```

The MCP exposes:

- `claude_builder_doctor`
- `claude_builder_run`
- `claude_builder_parallel`

## Verify In Codex

```powershell
codex mcp list
```

You should see:

```text
claude-code-builder  enabled
```

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```
