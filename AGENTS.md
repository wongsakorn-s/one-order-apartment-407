# ONE ORDER: Apartment 407

This repository contains a Godot 4.x emergent narrative simulation game.

Before implementing any gameplay task:

1. Read `docs/GAME_DESIGN.md`.
2. Read the relevant task from `docs/CODEX_TASKS.md`.
3. Inspect existing code before making changes.

## Core rules

- Use Godot 4.x and GDScript.
- Prefer typed GDScript where practical.
- Core simulation must not depend on LLM APIs.
- Simulation logic must remain separate from rendering/UI.
- All simulation randomness must use the centralized seeded RNG.
- Same seed + same directives must produce deterministic results.
- NPCs may only act on information they actually know.
- Prefer systemic interactions over scripted story content.
- Do not add features outside the current task.
- Do not rewrite working architecture without a concrete reason.
- Prefer a working vertical slice over speculative abstractions.
- Avoid giant manager classes.
- Avoid direct use of global random functions inside simulation logic.
- Keep world truth separate from character knowledge and beliefs.
- Dialogue must not directly mutate world truth; simulation actions do that.
- Major outcomes should emerge from state and decisions, not arbitrary RNG events.

## Validation

After every implementation task:

- Run relevant automated tests.
- Run the Godot project when practical.
- Check for parser/runtime errors.
- Fix regressions before moving to another task.
- Verify seed determinism remains intact.
- Report files created/modified, behavior added, tests run, and known limitations.

Do not finish a task with only interfaces, TODOs, or pseudocode. Implement a functional version.

## Game design source of truth

See:

`docs/GAME_DESIGN.md`

## Implementation roadmap

See:

`docs/CODEX_TASKS.md`

## Task execution rule

Implement only one roadmap task at a time unless explicitly instructed otherwise.

When a task is complete:

1. Verify its acceptance criteria.
2. Verify previous completed tasks still work.
3. Stop before starting the next task.
