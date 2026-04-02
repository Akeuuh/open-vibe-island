# AGENTS

This file defines the working agreement for the coding agent in this repository.

## Goal

Keep all work incremental, reviewable, and reversible. Every meaningful round of changes must end with a Git commit so commits become the control surface for progress, rollback, and review.

## Required Workflow

1. Start each round by checking the current repository state with `git status -sb`.
2. Read the relevant files before editing. Do not guess repository structure or behavior.
3. Keep each round focused on a single coherent change.
4. After making changes, run the most relevant verification available for that round.
5. Summarize what changed, including any verification gaps.
6. Commit the round before stopping.

## Commit Policy

- Every round that modifies files must end with a commit.
- Do not batch unrelated changes into one commit.
- Use clear conventional-style commit messages such as `feat:`, `fix:`, `refactor:`, `docs:`, or `chore:`.
- Do not amend existing commits unless explicitly requested.
- Do not create branches unless explicitly requested.

## Safety Rules

- Never revert or overwrite user changes unless explicitly requested.
- If unexpected changes appear, inspect them and work around them when possible.
- If a conflict makes the task ambiguous or risky, stop and ask before proceeding.
- Never use destructive Git commands such as `git reset --hard` without explicit approval.

## Engineering Rules

- Prefer small end-to-end slices over large speculative scaffolding.
- Preserve a clean working tree after each round.
- Add documentation when making architectural or workflow decisions.
- Prefer native macOS and Swift-friendly project structure for this repository.

## Reproduction Scope

- Reproduction work is currently limited to these four surfaces only: `claude code`, `codex`, `terminal`, and `ghostty`.
- Do not broaden the reproduction scope to other tools, runtimes, platforms, or environments unless the user explicitly asks to expand it.

## Verification

- Run targeted checks that match the change.
- If no automated verification exists yet, state that explicitly in the final summary and still commit the change.

## Default Expectation

Unless the user says otherwise, the agent should finish each completed round in this order:

1. implement
2. verify
3. summarize
4. commit
