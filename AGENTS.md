# Repository working agreements

## Git history

- Keep project-owned source, tests, scripts, shared build configuration, dependency lockfiles, design documents, reviewed plans, reports, and sanitized evidence summaries in Git.
- Commit each independently reviewable milestone after its relevant checks. Include connected code, tests, and documentation in the same logical commit; do not wait until the whole project is finished.
- Inspect `git diff`, the exact staged file list, and `git diff --cached --check` before committing. Stage explicit task paths rather than unrelated work.
- Describe the change and its reason; record verification and any known gaps in the commit body. A saved experiment must be labeled as an experiment, not as a completed feature.
- Preserve prototype history. Retire rejected prototypes with a later removal commit rather than rewriting the history that explains the decision.
- Do not amend, squash, rebase, force-push, or otherwise rewrite accumulated history unless the user requests it. Prefer a new fix or revert commit.
- Keep original applications/archives, installed tools, analysis databases, bulk disassembly/decompiler exports, raw runtime captures, credentials, and signing material out of Git. Use `samples/`, `.tools/`, `analysis/`, `evidence/raw/`, or `evidence/private/` as appropriate.
- Version only minimal, reviewed evidence excerpts with sample hash, architecture, address, tool version, and fact/inference labels. `.gitignore` does not replace staged-content review or remove already tracked files.
- Use the local repository by default; remote creation and publication require the user's requested scope.

## Current plan

The 2026-10-18 six-step pilot is complete; its research record is `.omx/plans/2026-10-18-oneswitch-pilot.md` with HTML reader `artifacts/20261018-0941-oneswitch-execution-plan.html` (keep them consistent if the pilot record is ever updated).

Read `docs/CORE.md` first: SwitchPilot is a personal-use, low-permission, few-reliable-controls macOS menu bar app. New features must pass its admission checklist (system gap or high-frequency long chain, public API/no new permission surface, visible and recoverable state, honest unsupported behavior, small panel footprint); duplicating system menu-bar/Control Center controls is out of scope.

The current product baseline is v0.5.1. Follow `docs/PRD.md`, `docs/DESIGN.md`, `docs/TECH.md`, and `docs/TESTPLAN.md`; implementation lives in `app/SwitchPilot/` and runtime evidence in `evidence/app-runtime.md`. Acceptance is evidence-based: automated checks pass, manual TCC/screen-state/login/icon items stay pending until the user runs them, and no feature is claimed complete without readback or explicit evidence. Record unexecuted items in TESTPLAN §3.1 rather than marking them passed.
