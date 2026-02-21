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
- Completion gate: Rafita exits only when provider reports `COMPLETE` + `EXIT_SIGNAL:true`, minimum loops are met, completion indicators threshold is met, and `.rafita/fix_plan.md` has no unchecked tasks.
- Optional live output mode: stream provider output to terminal while still writing full logs.

## Commands
After global install:
- `rafita` - Run the autonomous development loop
- `rafita-monitor` - Live monitor of loop status
- `rafita-report` - Generate summary report of work performed
- `rafita-setup` - Create a new Rafita-enabled project
- `rafita-import` - Import existing requirements into a project
- `rafita-enable` - Enable Rafita in an existing project
- `rafita-enable-ci` - Enable Rafita in CI/CD pipeline

## Install
```bash
git clone <this-repo>
cd rafita
./install.sh
```

## Testing
```bash
./tests/run_tests.sh
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

Require at least 8 loops before completion is allowed:
```bash
rafita --provider kimi --min-loops 8
```

Run with live output and stricter completion gate:
```bash
rafita --provider kimi --min-loops 8 --completion-threshold 2 --live
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

## Report
Generate a summary of work performed across all loops:
```bash
rafita-report
```

Export to JSON:
```bash
rafita-report --format json --output report.json
```

Export to Markdown:
```bash
rafita-report --format markdown --output report.md
```

Show last 5 loops only:
```bash
rafita-report --loops 5
```

## Ralph vs Rafita (Current Gap)
Based on Ralph's public README, notable capabilities and Rafita status:

- Dual completion verification (status block + textual completion indicators): now implemented in Rafita (`COMPLETION_INDICATOR_THRESHOLD`).
- Real-time visibility while the provider runs: now implemented in Rafita (`--live` / `LIVE_OUTPUT=true`).
- Provider strategy: Ralph is Claude-centric; Rafita is provider-agnostic (`codex|kimi|claude`) and keeps explicit selection (no fallback).

## Using Rafita In An Existing Project (Recommended)
For an already-started repo:

```bash
cd your-existing-project
rafita-enable --provider kimi
```

Then prepare control files before first run:

1. Put requirements in `.rafita/specs/` (PRD, tickets, bugs, acceptance criteria).
2. Prioritize `.rafita/fix_plan.md` with actionable checkboxes (`- [ ]` / `- [x]`).
3. Confirm `.rafitarc` values:
   - `MIN_LOOPS=8` (or your preferred floor)
   - `COMPLETION_INDICATOR_THRESHOLD=2`
   - `LIVE_OUTPUT=true` (optional)

Run:

```bash
rafita --provider kimi --min-loops 8 --completion-threshold 2 --live
```

## Optimal Usage Playbook
Use this routine for consistent results:

1. Keep `.rafita/specs/` small and concrete; avoid vague specs.
2. Keep `.rafita/fix_plan.md` ordered by priority and always up to date.
3. Use `--min-loops` to avoid premature exits on trivial `COMPLETE`.
4. Keep `COMPLETION_INDICATOR_THRESHOLD=2` or higher for stricter completion.
5. Enable `--live` when actively supervising; disable for quieter CI runs.
6. Watch progress with `rafita-monitor` and validate outcomes with `rafita-report`.
7. Treat unchecked tasks in `fix_plan.md` as the canonical "work remaining" signal.

## Notes
- Ensure provider CLIs are installed and authenticated (`codex`, `kimi`, `claude` as needed).
- For custom binary paths, edit `.rafitarc` (`CODEX_CMD`, `KIMI_CMD`, `CLAUDE_CMD`).
- Tune completion behavior in `.rafitarc` with `MIN_LOOPS`, `COMPLETION_INDICATOR_THRESHOLD`, and the checklist in `.rafita/fix_plan.md`.

## License
MIT
