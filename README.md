# Rafita

Autonomous AI development loop inspired by Ralph, adapted to run with explicit provider selection across `claude`, `codex`, and `kimi`.

## Credit
This project is based on the Ralph concept and workflow by the original creator of Ralph:
- Ralph repository: https://github.com/frankbria/ralph-claude-code

Ralph focused on Claude workflows. Rafita keeps a similar operational style while supporting `codex`, `kimi`, and `claude` through explicit `--provider` selection.

## Key Behavior
- Ralph-style commands and project layout.
- Internal control folder: `.rafita/`.
- Explicit provider selection only: `--provider codex|kimi|claude`.
- No automatic fallback between providers.
- Claude is used only when explicitly selected (`--provider claude`).

## Commands
After global install:
- `rafita`
- `rafita-monitor`
- `rafita-setup`
- `rafita-import`
- `rafita-enable`
- `rafita-enable-ci`

## Install
```bash
git clone <this-repo>
cd rafita
./install.sh
```

## Quick Start
Create a project:
```bash
rafita-setup demo --provider codex
cd demo
rafita
```

Run with Kimi:
```bash
rafita --provider kimi
```

Run with Claude explicitly:
```bash
rafita --provider claude
```

Enable Rafita in an existing project:
```bash
cd my-project
rafita-enable --provider codex
rafita
```

Import an existing requirements/PRD file:
```bash
rafita-import ./requirements.md my-project --provider kimi
```

## Project Files
- `.rafitarc`: project configuration
- `.rafita/PROMPT.md`: provider prompt contract
- `.rafita/fix_plan.md`: task checklist
- `.rafita/specs/`: requirements/specs
- `.rafita/logs/`: execution logs
- `.rafita/status.json`: monitor status

## Monitor
```bash
rafita-monitor
```

Or run in tmux split mode:
```bash
rafita --monitor
```

## Notes
- Ensure provider CLIs are installed and authenticated (`codex`, `kimi`, `claude` as needed).
- For custom binary paths, edit `.rafitarc` (`CODEX_CMD`, `KIMI_CMD`, `CLAUDE_CMD`).

## License
MIT
