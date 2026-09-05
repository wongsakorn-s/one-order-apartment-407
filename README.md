# ONE ORDER: Apartment 407

A small emergent narrative simulation game where the player does **not** directly control the protagonist.

The player chooses three initial directives:

- **WANT** — what the protagonist strongly wants to achieve.
- **NEVER** — a rule the protagonist should avoid violating.
- **BELIEVE** — a belief that changes how the protagonist interprets the world.

After the run starts, the protagonist acts autonomously alongside NPCs. The player observes the consequences.

## Core design principle

> Do not randomly choose what happens. Randomly generate who these people are and their initial circumstances, then let events emerge from their decisions and interactions.

The simulation focuses on the interaction of:

- Personality
- Goals
- Relationships
- Knowledge
- Memory
- Emotions
- Player directives
- Circumstances

## Planned technology

- Godot 4.x
- GDScript
- 2D top-down prototype
- Seeded deterministic simulation
- No required backend
- No required LLM/API for the MVP

## Repository guide

- `AGENTS.md` — permanent engineering rules for Codex/agents.
- `docs/GAME_DESIGN.md` — game concept, simulation philosophy, architecture, and MVP scope.
- `docs/CODEX_TASKS.md` — implementation roadmap split into sequential Codex tasks.

## Recommended Codex workflow

For each task:

1. Read `AGENTS.md`.
2. Read `docs/GAME_DESIGN.md`.
3. Read the current task in `docs/CODEX_TASKS.md`.
4. Inspect the current repository state.
5. Implement **only that task**.
6. Run tests and the Godot project.
7. Fix regressions.
8. Verify acceptance criteria.
9. Commit.
10. Continue to the next task only after review.

Example instruction:

```text
Read AGENTS.md and docs/GAME_DESIGN.md first.

Then read TASK-001 from docs/CODEX_TASKS.md.

Implement TASK-001 completely.

Do not implement TASK-002 or later tasks.

Run the relevant tests and Godot project after implementation.
Fix errors caused by your changes.

At the end, report:
- files created
- files modified
- tests run
- acceptance criteria status
- known limitations
```

## Development philosophy

If choosing between:

- adding many new scripted events, or
- making a few existing systems interact more deeply,

choose deeper systemic interaction.

The MVP succeeds when finishing a run makes the player immediately want to click:

> Run Again.
