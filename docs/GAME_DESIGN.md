# ONE ORDER: Apartment 407
## Game Design & Simulation Specification

## 1. Vision

The player does not directly control the protagonist.

The player gives the protagonist an initial directive, then watches the character autonomously live through the simulation and interact with NPCs and the world.

The game should create emergent stories through simulation rather than predefined branching story paths.

The most important design principle is:

> Do not randomly choose what happens. Randomly generate who these people are and their initial circumstances, then let events emerge from their decisions and interactions.

The player should feel:

> “I gave this character an intention. I want to see how they interpret it, what consequences follow, and whether the same intention produces a different story next time.”

---

# 2. Technology

Use:

- Godot 4.x
- GDScript
- 2D top-down prototype
- Simple placeholder graphics
- Data-driven architecture using Resources or JSON where appropriate
- No external backend
- No required LLM/API for the MVP

The entire prototype must run locally.

Keep simulation logic separated from rendering/UI.

Do not tightly couple NPC decision logic to Godot Nodes when it can be represented as plain simulation classes/resources.

---

# 3. MVP Scope

Keep the project intentionally small.

Create:

- 1 apartment building
- 2 floors
- 8–10 rooms
- 1 player-owned autonomous character
- 8 NPCs
- 1 simulation night
- Start time: 18:00
- End time: 06:00
- About 10–20 minutes real-time per simulation run
- Adjustable simulation speed
- Pause support

Locations may include:

- protagonist room
- hallway
- stairwell
- lobby
- rooftop
- laundry room
- convenience-store-like shared area if needed

Do NOT create an open world.

---

# 4. Core Player Flow

The game starts with a setup screen.

Show the protagonist's generated traits and basic background.

The player chooses three directives.

## WANT

Something the character strongly wants to accomplish.

Examples:

- Make 5,000 money before sunrise
- Find out what happened in Room 407
- Make at least one real friend tonight
- Survive until sunrise
- Make everyone in the building like you

## NEVER

Something the character should avoid doing.

Examples:

- Never steal
- Never hurt anyone
- Never lie
- Never enter Room 407
- Never trust the police

## BELIEVE

A belief that influences how the character interprets situations.

Examples:

- Most people can be trusted
- Everyone is hiding something
- Money solves every problem
- Helping people will eventually pay off
- Nobody gives anything for free

For the first implementation, use predefined selectable directives instead of free-text natural language.

Design the system so free-text directive parsing can be added later.

After the player presses START:

The player loses direct control over the character.

The protagonist autonomously decides:

- where to go
- who to talk to
- what to investigate
- whether to help someone
- whether to lie
- whether to trade
- whether to steal
- whether to escape danger
- whether to pursue or abandon goals

The player only observes.

---

# 5. Simulation Philosophy

The simulation should be:

- systemic
- explainable
- deterministic when given the same seed
- unpredictable when seeds or NPC initial conditions change

Every simulation run must have a numeric seed.

Same seed + same player directives:

> same simulation result

Different seed + same player directives:

> potentially very different story

Display the seed in the UI.

Allow:

- New Random Run
- Replay Same Seed

This is critical for debugging and emergent-story sharing.

Major outcomes should not be selected directly by RNG.

Bad:

```gdscript
if rng.randf() < 0.1:
    murder()
```

Preferred:

A confrontation becomes violent because several conditions converge:

- strong negative relationship
- high aggression
- emotional trigger
- access to a weapon
- low perceived consequences
- escalating conflict

Randomness may perturb scores, break ties, or generate initial conditions. It should not arbitrarily choose the story.

---

# 6. Character Model

Every NPC and the protagonist should contain these systems.

## Personality

Use normalized values from 0.0 to 1.0.

Minimum traits:

- empathy
- greed
- fear
- aggression
- curiosity
- honesty
- sociability
- impulsiveness

Personality influences decision scoring.

## Needs

Basic needs:

- safety
- money
- social connection
- information
- rest
- food

## Goals

NPCs should receive one or two generated personal goals.

Examples:

- find money for rent
- avoid another NPC
- meet someone secretly
- retrieve an item
- hide evidence
- repair a relationship
- investigate suspicious noise
- get drunk
- leave the building

Goals should conflict sometimes.

## Emotions

Suggested dimensions:

- happiness
- fear
- anger
- stress

Events modify emotions.

Emotions decay toward baseline over time.

Emotions influence utility scoring.

Examples:

- high anger → confrontation becomes more attractive
- high fear → flee/avoid becomes more attractive

---

# 7. Knowledge and Beliefs

Characters must NOT have access to global truth.

Separate:

- World Truth
- Character Knowledge
- Character Beliefs

Example world truth:

```text
Bob stole Alice's key.
```

Tom may only know:

```text
Tom saw Bob near Alice's room.
```

Jane may believe:

```text
Alice lost her key herself.
```

Characters can:

- observe events
- hear information
- tell others information
- lie
- misunderstand information
- form suspicions

Represent knowledge as facts or beliefs with:

- subject
- predicate
- object/value
- confidence
- source
- timestamp

Example:

```text
subject: Bob
predicate: suspicious
value: true
confidence: 0.65
source: Tom
time: 22.3
```

Trust should affect confidence in received information.

Different NPCs may hold contradictory beliefs.

---

# 8. Relationship Model

Relationships must not use only a single friendship number.

Track:

- trust
- fear
- attraction
- respect
- debt
- suspicion

Relationships are directional.

Example:

```text
John -> Mia

trust: 0.2
fear: 0.1
attraction: 0.8
respect: 0.5
debt: 0.4
suspicion: 0.7
```

John's relationship toward Mia can differ from Mia's relationship toward John.

Relationships should affect decisions.

Examples:

High trust:

- more likely to help
- more likely to share information

High suspicion:

- more likely to investigate
- less likely to believe statements

High fear:

- avoid
- flee
- comply

High debt:

- greater willingness to help

---

# 9. Memory System

Characters remember meaningful events.

Example:

```text
22:13
Alex protected Nina from an aggressive drunk.

emotion:
gratitude: 0.8
fear: 0.3

belief changes:
Alex trustworthy +0.4
```

A memory should contain:

- timestamp
- involved characters
- event type
- emotional impact
- importance
- related facts
- related event ID

Memories should influence later decisions.

Do not keep unlimited memory.

Use a reasonable cap such as 30 memories and retain important memories over trivial ones.

Characters should not automatically remember events they did not observe.

---

# 10. Actions

Create a small but composable action system.

Initial actions may include:

- Idle
- MoveTo
- Talk
- AskQuestion
- ShareInformation
- Lie
- Help
- Refuse
- GiveItem
- TakeItem
- Buy
- Sell
- Investigate
- EnterRoom
- LeaveRoom
- Rest
- Flee
- Confront
- Attack

Actions should have:

- preconditions
- duration
- effects
- utility considerations

Do not hardcode entire stories inside actions.

---

# 11. Decision Making

Implement Utility AI.

Each possible action receives a score.

Conceptually:

```text
score =
goal_relevance
+ personality_modifier
+ need_modifier
+ emotional_modifier
+ relationship_modifier
+ memory_modifier
+ belief_modifier
+ situational_modifier
+ controlled_randomness
- risk
- directive_violation
```

The protagonist's WANT strongly affects goal relevance.

NEVER creates a very large penalty or invalidates actions depending on context.

BELIEVE influences interpretation and utility scoring.

Example:

```text
WANT:
Make money

NEVER:
Steal

BELIEVE:
Everyone has a price
```

Possible behavior:

- negotiate
- offer favors
- trade information
- ask for work
- manipulate relationships

instead of stealing.

Controlled randomness must use seeded RNG and should break ties rather than dominate decisions.

---

# 12. Event System

Create event templates that respond to simulation state.

Examples:

- argument
- rumor
- request for help
- missing item
- suspicious noise
- power outage
- locked door
- secret meeting
- unpaid debt
- lost key
- neighbor complaint

Events provide situations.

NPC decisions determine what happens next.

Keep the initial event set around 15–25 templates.

---

# 13. Secrets

Every run should generate several hidden pieces of information.

Examples:

- NPC A owes NPC B money
- NPC C stole something
- NPC D secretly likes NPC E
- NPC F is planning to leave
- NPC G has a key to Room 407
- NPC H saw something suspicious earlier

Do not reveal these directly to the player.

Characters discover them through:

- observation
- investigation
- conversation
- rumors

Secrets create motivations and interactions, not fixed quest lines.

Generated states must remain logically consistent.

Example:

If A owes B money, relevant knowledge/memory should be generated consistently where appropriate.

Avoid contradictory state unless contradiction is intentionally represented as a false belief.

---

# 14. Room 407

Room 407 is a reusable mystery catalyst.

Do NOT create one canonical solution.

Different seeds may make Room 407 related to:

- hidden money
- missing tenant
- secret meeting
- illegal activity
- stolen goods
- someone hiding there
- abandoned belongings
- completely innocent misunderstanding
- irrelevant activity

Some runs may make Room 407 irrelevant.

This prevents the game from becoming a fixed mystery story.

The explanation should be logically discoverable through simulation state.

Do not force the protagonist to investigate it.

---

# 15. Causal Event Log

Every meaningful event should generate a structured log.

Example:

```text
21:03 Alice rejected Bob.

21:40 Bob went drinking because:
- relationship_with_alice < threshold
- sadness increased
- alcohol available

22:10 Bob talked to Mark.

22:13 Mark told Bob that Alice may be seeing someone.

22:27 Bob decided to confront Alice.

Reason:
- jealousy: high
- aggression: medium
- intoxication: high
- suspicion: high
```

The simulation must retain causal links.

Each event should optionally reference:

- parent event IDs
- reasons
- relevant memories
- relevant goals
- relevant relationships
- relevant personality traits
- relevant beliefs
- player directives

Do not store only human-readable strings when structured references are practical.

---

# 16. End-of-Run Causality View

When the run ends, show:

- final protagonist state
- achieved / failed WANT
- whether NEVER was violated
- important relationship changes
- important discoveries
- major events

Most importantly:

Display a simple causal timeline or graph.

Example:

```text
Player Directive
"Help everyone"

↓
Helped Nina

↓
Nina trusted protagonist

↓
Nina revealed Room 407 information

↓
Protagonist investigated

↓
Bob was discovered

↓
Bob fled

↓
Tom saw Bob

↓
Police were called

↓
ENDING
"Nobody Sleeps Tonight"
```

A full graphical node editor is not necessary initially.

A vertical causal timeline is enough for the MVP.

---

# 17. Observer UI

## Center

Top-down apartment visualization.

Characters move between rooms.

Use simple circles/sprites with names.

## Left panel

Selected character information:

- name
- current action
- current location
- dominant goal
- emotional state

For the protagonist also show:

- WANT
- NEVER
- BELIEVE

## Right panel

Live event feed.

Example:

```text
21:14 Nina entered hallway.
21:16 Nina asked Alex for help.
21:17 Alex refused.
21:19 Nina's trust in Alex decreased.
```

## Top bar

- simulation clock
- seed
- pause
- speed x1
- speed x2
- speed x4

The player must NOT be able to manually command the protagonist after simulation starts.

---

# 18. Debug Inspector

Create a developer/debug mode.

When selecting a character, allow developer-only inspection of:

- personality values
- goals
- utility score candidates
- memories
- beliefs
- relationships
- current decision
- reasons for choosing that action

Example:

```text
Chosen:
Investigate Room 407

Score: 8.4

Reasons:

+4.0 WANT relevance
+2.2 curiosity
+1.5 Nina's information
+1.0 suspicious memory
-0.3 fear
```

This feature is essential for tuning autonomous AI.

---

# 19. Architecture

Structure the code approximately around these domains:

```text
simulation/
    simulation_world
    simulation_clock
    simulation_runner
    random_service

characters/
    character_state
    personality
    needs
    goals
    memory
    belief
    relationship

ai/
    decision_engine
    utility_action
    utility_consideration
    action_selector

actions/
    base_action
    move_action
    talk_action
    investigate_action
    help_action
    etc.

events/
    event_bus
    world_event
    event_templates
    causal_event

world/
    location
    room
    item
    interactable

generation/
    npc_generator
    relationship_generator
    secret_generator
    run_generator

directives/
    directive
    want_directive
    never_directive
    belief_directive

ui/
    setup_screen
    observer_screen
    event_feed
    character_inspector
    end_run_screen
```

Exact filenames may differ if there is a better Godot architecture.

Keep the simulation testable without running the full rendered game where possible.

---

# 20. Important Engineering Rule

Do not use an LLM to choose every NPC action.

Core simulation decisions must be implemented using deterministic game systems.

Future AI/LLM integrations may be used for:

- dialogue generation
- natural language directive parsing
- narration
- summarizing memories

Prepare interfaces for these possibilities, but do not make the MVP depend on an API.

---

# 21. Dialogue

For MVP, use lightweight templated dialogue.

Dialogue generation should receive context such as:

- relationship
- emotional state
- topic
- belief
- goal

Examples:

High trust:

```text
"Okay. I'll tell you what I saw."
```

Low trust:

```text
"Why do you want to know?"
```

Do not build a giant dialogue tree.

Dialogue should represent simulation decisions rather than create authoritative world state.

---

# 22. Emergent Story Requirements

The game should be capable of creating simple stories like:

## Example Run A

```text
Player:
WANT Find the truth about Room 407
NEVER Hurt anyone
BELIEVE Everyone is hiding something

Alex questions Nina.

Nina distrusts Alex.

Alex follows Nina.

Nina secretly meets Tom.

Alex assumes Tom is involved.

Alex confronts Tom.

Tom reveals that Nina only owes him money.

Meanwhile the actual Room 407 clue was with Sarah.

Alex fails the goal.
```

## Example Run B with same directives but different seed

```text
Nina likes Alex.

Nina voluntarily tells Alex about a strange noise.

Alex investigates.

Alex finds a lost key.

The key belongs to Bob.

Bob lies about it.

Alex follows Bob.

Bob reveals Room 407 is being used to hide stolen goods.

Alex succeeds.
```

The important property is:

- Same directive.
- Different characters.
- Different relationships.
- Different circumstances.
- Different story.

---

# 23. Content Generation

At the beginning of every run, generate:

- personality
- NPC goals
- selected secrets
- relationship graph
- inventory
- initial locations
- basic emotional state

Use seeded randomness only.

Make generated states logically valid.

Example:

If:

```text
A owes B money
```

then both NPCs should have corresponding knowledge/memory where appropriate.

Avoid contradictory generated state unless contradiction is intentionally represented as a false belief.

---

# 24. Testing

Create automated tests where practical.

At minimum verify:

## Seed determinism

Same seed + same directives produces identical important event sequence.

## Seed variation

Different seeds generate different NPC configurations.

## NEVER behavior

Forbidden actions receive appropriate penalties or become invalid.

## Knowledge isolation

NPCs cannot act using information they never learned.

## Relationship directionality

A → B relationship differs independently from B → A.

## Causal log

Events retain parent/reason references correctly.

---

# 25. Development Order

Build in vertical slices.

Do not build every system completely before getting something playable.

## Phase 1

Simulation skeleton:

- world
- clock
- character
- movement
- seeded RNG

Result:

NPC circles walk between apartment rooms.

## Phase 2

Utility AI:

- actions
- goals
- personality
- decision scoring

Result:

NPCs autonomously choose meaningful actions.

## Phase 3

Social simulation:

- relationships
- conversations
- memory
- knowledge

Result:

NPC behavior changes based on previous interactions.

## Phase 4

Player directives:

- WANT
- NEVER
- BELIEVE

Result:

The protagonist noticeably behaves differently based on player setup.

## Phase 5

Procedural run generation:

- NPC personality
- relationships
- secrets
- goals

Result:

Different seeds produce different stories.

## Phase 6

Causal logging and end-run analysis.

## Phase 7

Polish observer UI and debugging tools.

---

# 26. Non-Goals

Do NOT spend significant time on:

- combat depth
- character customization
- skill trees
- crafting
- procedural map generation
- multiplayer
- online backend
- realistic graphics
- voice acting
- complex animation
- hundreds of NPCs
- fully generated AI dialogue
- open world
- save-game system beyond run seed if unnecessary

The simulation is the product.

---

# 27. Success Criteria

The MVP is successful when the player can:

1. Launch the project.
2. See generated protagonist information.
3. Select WANT.
4. Select NEVER.
5. Select BELIEVE.
6. Start a seeded simulation.
7. Watch the protagonist move and autonomously interact.
8. Watch NPCs interact independently of the protagonist.
9. Observe relationships and memories changing.
10. See information propagate between NPCs.
11. Watch events emerge from character decisions.
12. Finish the night.
13. Read a summary explaining what happened and WHY.
14. Replay the same seed and get the same result.
15. Start a different seed with identical directives and see a meaningfully different chain of events.

The MVP should make the player want to immediately click:

> Run Again.

---

# 28. Initial Agent Instruction

When beginning from an empty or early repository:

1. Inspect the current repository.
2. Do not blindly overwrite useful existing code.
3. Read `AGENTS.md`.
4. Use `docs/CODEX_TASKS.md` as the implementation roadmap.
5. Implement tasks one at a time.
6. Run/test after each task.
7. Fix errors before advancing.
8. Keep README updated as the project evolves.

Do not stop after creating empty interfaces or placeholder classes.

Prioritize having a working simulation over architectural perfection.

When choosing between adding more content and making existing systems interact more deeply, choose deeper interaction.

The objective is not to create many events.

The objective is:

> A small number of systems that collide with each other and produce surprising consequences.
