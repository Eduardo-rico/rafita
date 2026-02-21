# Rafita Design (2026-02-21)

## Goal
Create a Ralph-like autonomous development loop that works with Codex and Kimi, and can also run Claude when explicitly selected.

## Approved Decisions
- Keep Ralph-like global commands: `rafita`, `rafita-monitor`, `rafita-setup`, `rafita-import`, `rafita-enable`, `rafita-enable-ci`.
- Use `.rafita/` project subfolder for internal control files.
- Provider selection is explicit with `--provider codex|kimi|claude`.
- No automatic fallback between providers.
- Claude is used only when explicitly selected (`--provider claude`).

## Architecture
- Shell-based orchestrator with provider adapters in `lib/provider.sh`.
- Loop script `rafita_loop.sh` drives execution, status parsing, and safety controls.
- Project-level config in `.rafitarc`.
- Templates in `templates/` for prompt, fix plan, and agent instructions.
- Runtime monitor in `rafita_monitor.sh` using `.rafita/status.json`.

## Data & Files
- `.rafita/PROMPT.md`
- `.rafita/fix_plan.md`
- `.rafita/specs/`
- `.rafita/logs/rafita.log`
- `.rafita/status.json`
- `.rafita/progress.json`
- `.rafitarc`

## Safety & Controls
- Rate limit with per-hour reset and call counters.
- Iteration timeout (provider call timeout).
- Circuit breaker for repeated failures and no-progress loops.
- Exit gate requires explicit `EXIT_SIGNAL: true` in `RAFITA_STATUS`.

## Commands
- Global (post-install): `rafita`, `rafita-monitor`, `rafita-setup`, `rafita-import`, `rafita-enable`, `rafita-enable-ci`.
- Provider override: `rafita --provider codex|kimi|claude`.

## Out of Scope (v1)
- Full parity with all Ralph test suites and advanced GitHub/beads integrations.

