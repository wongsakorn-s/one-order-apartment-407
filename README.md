# ONE ORDER: Apartment 407

A small emergent narrative simulation game where the player does **not** directly control the protagonist.

The player chooses three initial directives for the protagonist, then watches one night unfold (18:00 → 06:00) inside a small apartment building, alongside 8 autonomous NPCs. Nothing about the *story* is scripted — only the *people*, their circumstances, and a handful of interacting systems are. What happens is whatever those systems produce.

## Game concept

- **WANT** — what the protagonist strongly wants to achieve tonight (e.g. *Learn the truth about Room 407*).
- **NEVER** — a rule the protagonist should avoid violating (e.g. *Never steal*).
- **BELIEVE** — a belief that changes how the protagonist interprets the world (e.g. *Everyone is hiding something*).

Once the run starts, the player loses direct control. The protagonist decides where to go, who to talk to, what to investigate, whether to help, lie, confront, or flee — using the exact same decision-making system every NPC uses. The player only observes, through a top-down apartment view, a live event feed, and an inspector panel for the currently-selected character.

> Do not randomly choose what happens. Randomly generate who these people are and their initial circumstances, then let events emerge from their decisions and interactions.

Every run has a numeric **seed**. The same seed with the same directives always produces the same story — different seeds produce different people, different relationships, different secrets, and consequently different stories from the *same* directives.

The simulation's content comes from a small number of systems colliding, not from a large library of scripted scenes:

> Personality × Goals × Relationships × Knowledge × Memory × Emotions × Secrets × Player Directives × Circumstances

## How to run

Requires **Godot 4.7+** (Mono/.NET build not required, GDScript only).

- **Play the game:** open the project in the Godot editor and run it (F5), or from the CLI: `godot --path .`
- **Run the automated test suite** (headless, ~10s, 144 tests as of TASK-019):
  ```
  godot --headless --path . -s res://tests/test_runner.gd
  ```
- **Run the emergent-story stress test** (developer diagnostic mode, 50 full simulations, ~45s):
  ```
  godot --headless --path . -s res://scripts/tools/stress_test_runner.gd
  ```
  Pass a run count as a CLI user arg to change the sample size, e.g. `-- 100`.

## Architecture

Simulation logic is kept independent of rendering and UI. Nothing under `scripts/simulation`, `scripts/characters`, `scripts/ai`, `scripts/actions`, `scripts/events`, `scripts/generation`, `scripts/directives`, or `scripts/world` depends on a Godot `Node` being in the scene tree — everything there is plain `RefCounted` data and logic, directly testable headless.

```text
scripts/
  simulation/     SimulationRunner (orchestrator), SimulationClock, RandomService, RunEvaluator
  characters/     CharacterState, Personality/Needs/Emotions fields, Memory, Belief, Relationship
  ai/             UtilityAI (decision engine), UtilityDecision
  actions/        BaseAction + Idle/MoveTo/Talk/Investigate/Help/Refuse/Rest/TakeItem/GiveItem/
                  Flee/Confront/AskQuestion/ShareInformation/Lie
  events/         SimulationEvent (structured causal event record)
  world/          Location, WorldGraph (graph-based navigation), WorldView (2D presentation only)
  generation/     NPCGenerator, RelationshipGenerator, SecretGenerator, Room407Generator
  directives/     WantDirective, NeverDirective, BeliefDirective, DirectiveCatalog
  ui/             MainUI (presentation layer; reads simulation state via signals, never mutates it)
  tools/          StressTestRunner, StressTestMetrics (developer-only diagnostics)
tests/            One test file per task/system, orchestrated by tests/test_runner.gd
```

`SimulationRunner` is the only place that ticks the simulation (`_tick_simulation`, driven by `_physics_process` using simulation-second deltas, never real frame time) and is the single source of truth `MainUI` and `WorldView` read from via signals (`characters_updated`, `event_emitted`, `time_updated`, `simulation_completed`, ...). Neither the UI nor the world view ever mutates simulation state directly.

## Simulation model

Every run generates, in this fixed order (all from one seeded `RandomService`, so the whole sequence is reproducible):

1. **Protagonist** — fixed starting personality/needs/inventory; directives applied.
2. **8 NPCs** (`NPCGenerator`) — personality, needs, emotions, starting location, 1–2 goals, starting inventory, all derived from archetypal templates plus seeded variation.
3. **Relationships** (`RelationshipGenerator`) — a directional trust/fear/attraction/respect/debt/suspicion edge for every ordered pair of characters.
4. **Initial knowledge** — each character starts knowing only their own location; a couple of narrative-specific seed beliefs.
5. **Secrets** (`SecretGenerator`) — 3–5 secrets (owed debts, stolen/hidden items, a secret crush, someone planning to leave, the Room 407 key, an overheard noise, a told lie), each mutating real inventory/relationship/belief/goal state, never handed to characters who wouldn't logically know them.
6. **Room 407 scenario** (`Room407Generator`) — at most one procedural scenario for Room 407 (hidden money, a missing tenant, a secret meeting, stolen goods, someone hiding there, abandoned belongings, innocent noise, or explicitly nothing) — with a further chance of no scenario at all, so the room is often unremarkable. The protagonist is never assigned Room 407 knowledge or goals by this generator, so the player is never nudged toward it.

From 18:00, every idle character runs a Utility AI decision cycle every tick; completed actions produce structured `SimulationEvent`s that are distributed as memories/beliefs only to characters who actually observed them. The run ends automatically at 06:00, at which point `RunEvaluator` scores the outcome and the player sees an end-of-run summary with a causal timeline.

## Seed determinism

`RandomService` (`scripts/simulation/random_service.gd`) is the **only** source of randomness anywhere in simulation logic — no code path calls the engine's global `randi()`/`randf()`/`randomize()`. Generation (NPCs, relationships, secrets, Room 407) and ongoing autonomous decisions (Utility AI tie-breaking noise) all draw from the same shared stream, in a fixed call order, so:

- Same seed + same directives ⇒ byte-identical event sequence, every time, including the exact final RNG stream position.
- Different seed ⇒ different NPCs, different relationships, different secrets, and (almost always) a different event sequence.

This is proven directly by `tests/test_determinism_suite.gd`, which ticks two full `SimulationRunner`s 150 times each and diffs their entire event logs.

## Utility AI

`UtilityAI.score_action()` (`scripts/ai/utility_ai.gd`) scores every candidate action for every idle character as:

```text
score = base + goal_relevance + personality_mod + need_mod + emotional_mod
      + relationship_mod + memory_mod + repetition_mod + controlled_noise
      + want_mod + never_mod + belief_mod - risk
```

- **Personality** (empathy, greed, fear, aggression, curiosity, honesty, sociability, impulsiveness) shifts almost every action's score.
- **Memory** references specific past events (e.g. "they helped me before" boosts `help` toward them) and can trace back to the exact `SimulationEvent` that caused it (`contributing_event_ids` → `parent_event_ids` on the resulting event — TASK-013's causal chain).
- **`repetition_mod`** is a deliberate, deterministic bias against repeating the exact action the character just completed (except idle/rest), added in TASK-019 after a 50-seed stress test showed talk/help snowballing off their own rising trust/debt into 70%+ of a character's actions.
- **Controlled noise** is seeded and small (±0.15) — it only breaks ties, it never drives the story (verified in the stress test: unique event sequences across 50/50 seeds even with noise present).
- **Player directives** apply only to the protagonist: WANT gives a strong positive bonus (+2 to +4) toward relevant actions, NEVER applies a large flat penalty (−15) to prohibited actions, BELIEVE nudges interpretation (±0.8 to ±1.6) without forcing a specific path.

Every scored decision, and every completed action's resulting `SimulationEvent`, carries the full reason breakdown — nothing is "explained" only as a human-readable string.

## Memory

Each character keeps up to 30 `Memory` records (`scripts/characters/memory.gd`), gained only for events they actually witnessed (were the actor, the target, or physically present). At capacity, the lowest-importance memory is evicted first; a new low-importance memory is dropped rather than displacing something more important. Memories feed back into Utility AI scoring (e.g. a memory of being helped makes helping that person back score higher) and are inspectable per-character in Developer Mode.

## Knowledge

Characters never see global world truth. Each holds a private set of `Belief`s (`scripts/characters/belief.gd`: subject, predicate, value, confidence, source, timestamp). Direct observation produces confidence 1.0 / source "self"; information received from another character (`Talk`, `ShareInformation`, `AskQuestion`) is scaled by the listener's trust in the speaker and can be wrong — `Lie` and dishonest `AskQuestion` answers deliberately create false beliefs in the listener without ever touching the speaker's own true belief or world state. Two characters can (and regularly do) hold contradictory beliefs about the same thing.

## Relationships

Every ordered character pair has an independent `Relationship` (`scripts/characters/relationship.gd`): trust, fear, attraction, respect, debt, suspicion, all 0.0–1.0. A → B is a completely separate value from B → A and is never overwritten by it. Social actions update relationships directionally (e.g. `Help` raises the helped character's trust/debt toward the helper more than the reverse).

## Directives

Applied only to the protagonist (`scripts/directives/`), never inherited by NPCs:

- `WantDirective.calculate_utility()` — a per-directive-id bonus toward actions that serve it.
- `NeverDirective.evaluate_violation()` — a flat −15 penalty (and in most cases the action becomes effectively unusable) for the specific action type it prohibits.
- `BeliefDirective.modify_interpretation()` — a modest interpretive nudge, never a forced path (verified: a sufficiently urgent competing need, like near-zero rest, still outscores a belief-favored action).

## End of run

At 06:00, `RunEvaluator` (`scripts/simulation/run_evaluator.gd`) produces: WANT scored success/partial/failure (distinct logic per WANT id, based on actually-recorded events/beliefs/relationships), NEVER respected/violated (scanning the protagonist's own causal events for the specific prohibited action, with a reference to the exact violating event), a BELIEVE narrative summary (deliberately never scored pass/fail), major relationships, which generated secrets actually surfaced during play, major memories, and a simple chronological causal timeline opening with the player's own directive. The player can then **Replay Same Seed**, pick a **New Random Seed** (same directives, a different story), or **Change Directives** (reopens the setup screen).

## Known limitations

- No death/failure state for the protagonist or NPCs — "survive the night" is scored by how often the protagonist was confronted, not by any actual danger mechanic.
- No formal door-lock/physical-security system — Room 407 "locked" is a belief, not enforced world state; nothing currently stops a character from moving there.
- `never_trust_police` can never actually be violated — no `call_police`/`report_to_police` action exists yet.
- Discovered-secret detection (shown at end of run) is a heuristic (does *any* other character now hold a matching belief), not a rigorous proof that the secret was meaningfully resolved.
- Room 407 items use a lightweight per-location item list (`Location.items`), separate from the economy-like item system on characters; there's no item-quality/value model beyond a fixed "valuable items" list used by the `earn_money` WANT.
- Dialogue is templated/derived from state (per the design's "no LLM" MVP constraint), not natural language generation.
- The 50-seed stress test (TASK-018) still shows NEVER (`never_steal`, the default) at 0% violation and WANT (`learn_room_407`, the default) at 0% failure across a full sample — both are influenced by the same TASK-019 tuning that fixed the more serious repetition problem, and neither was chased further to avoid re-opening that fix. Left as a note for a future balance pass.

## Future ideas

- `parse_directive(text)` — free-text directive input mapped onto the existing structured directives (interface intentionally left open; not started).
- `DialogueProvider` interface with a `TemplateDialogueProvider` (current) and a future optional `LLMDialogueProvider` for narration/dialogue flavor only — never for core decision-making.
- Exportable run records (seed + directives + generated characters/relationships/secrets + causal event log) for sharing or replaying specific interesting/broken runs.
- A real physical lock/key-use mechanic for Room 407 rather than a belief-only "locked" status.
- Per-secret "how was this actually resolved" tracking beyond the current discovery heuristic.

## Repository guide

- `AGENTS.md` — permanent engineering rules for Codex/agents.
- `docs/GAME_DESIGN.md` — game concept, simulation philosophy, architecture, and MVP scope.
- `docs/CODEX_TASKS.md` — implementation roadmap split into sequential Codex tasks.

## Development philosophy

If choosing between:

- adding many new scripted events, or
- making a few existing systems interact more deeply,

choose deeper systemic interaction.

The MVP succeeds when finishing a run makes the player immediately want to click:

> Run Again.
