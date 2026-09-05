# ONE ORDER: Apartment 407
## Codex Implementation Task Pack

Use these tasks sequentially.

Rules:

- Do not skip a task if the previous task's acceptance criteria are not satisfied.
- Every task must run relevant tests after changes.
- Run the Godot project when practical.
- Do not perform large rewrites without a concrete reason.
- Do not add features outside the current scope.
- Prefer a working vertical slice over abstraction.
- All randomness must use seeded RNG.
- Keep simulation logic separate from UI.
- Do not use an LLM/API in core simulation.

---

# GLOBAL CODEX INSTRUCTIONS

Before changing code:

1. Inspect the repository.
2. Read `AGENTS.md`.
3. Read `docs/GAME_DESIGN.md`.
4. Read the complete current task.
5. Understand the current architecture.
6. Reuse existing systems where reasonable.
7. Identify dependencies related to the task.

While implementing:

- Use GDScript.
- Prefer typed GDScript where practical.
- Keep simulation systems independent from presentation.
- Avoid giant manager classes.
- Avoid premature abstractions.
- Use seeded randomness only.
- Do not use global random functions directly inside simulation logic.
- Do not introduce external services.
- Do not introduce LLM APIs.
- Do not add unrelated gameplay features.
- Keep code understandable and debuggable.

After implementing:

1. Run tests if available.
2. Run the project if possible.
3. Check Godot output for errors.
4. Fix errors caused by the changes.
5. Update README/developer notes if architecture changed.
6. Report:
   - files created
   - files modified
   - behavior added
   - tests performed
   - acceptance criteria status
   - known limitations

Do not finish with only interfaces, TODOs, or pseudocode.

Implement a functional version.

---

# TASK-001 — PROJECT FOUNDATION

## Goal

Create the Godot project foundation for the simulation game.

## Implementation

Create a minimal playable scene and clean separation between:

- simulation
- world visualization
- UI

Suggested structure:

```text
res://
  scenes/
  scripts/
    simulation/
    characters/
    ai/
    actions/
    world/
    events/
    generation/
    directives/
    ui/
  tests/
```

Modify if there is a clear Godot-specific reason.

### Main Scene

Create a Main scene that successfully launches.

It should contain conceptually:

- WorldView
- UI layer
- SimulationRunner

Simple placeholders are enough.

### SimulationClock

Requirements:

- start at 18:00
- run until 06:00 next day
- pause
- speed multiplier
- x1, x2, x4
- simulation time must not depend directly on rendering FPS

Represent time internally using deterministic simulation minutes or seconds.

### Seeded Random Service

Create a centralized deterministic random service.

Seed:

```text
seed = integer
```

Provide methods such as:

```text
rand_float()
rand_range_float()
rand_range_int()
pick()
shuffle()
```

Simulation systems must use this service instead of global randomness.

### Initial UI

Show:

- simulation time
- current seed
- pause button
- x1 button
- x2 button
- x4 button

## Acceptance Criteria

- Godot project launches without errors.
- Simulation starts at 18:00.
- Clock advances.
- Pause stops simulation time.
- x2 and x4 visibly change simulation speed.
- Seed is visible.
- Same seed initializes the random service identically.
- No gameplay logic depends on `randomize()`.
- No external APIs are used.

---

# TASK-002 — APARTMENT WORLD MODEL

## Goal

Create a small logical world that the simulation can reference.

## Implementation

Create a simple apartment consisting approximately of:

- Lobby
- Hallway Floor 1
- Hallway Floor 2
- Stairwell
- Laundry Room
- Rooftop
- Room 101
- Room 102
- Room 103
- Room 201
- Room 202
- Room 203
- Room 407

Room 407 may be treated as a special room identifier despite the simplified floor layout.

Each location should have:

```text
id
display_name
neighbors
capacity if needed
tags
```

Implement graph-based navigation.

Do not implement tile pathfinding.

Movement operates between logical locations.

Create a simple top-down visualization showing rooms as boxes and connected areas.

## Acceptance Criteria

- All locations exist.
- Location graph is connected where appropriate.
- Characters can calculate valid routes between connected locations.
- Invalid destinations fail safely.
- Visualization clearly shows each location.
- World model does not depend on rendered Node positions for simulation logic.

---

# TASK-003 — CHARACTER STATE

## Goal

Create the character data model.

## Implementation

Each character should contain:

```text
id
name
current_location
personality
needs
emotions
inventory
goals
memories
beliefs
relationships
current_action
```

Personality traits 0.0–1.0:

```text
empathy
greed
fear
aggression
curiosity
honesty
sociability
impulsiveness
```

Basic needs:

```text
safety
money
social
information
rest
food
```

Emotional state:

```text
happiness
fear
anger
stress
```

Clamp normalized values to sensible ranges.

Generate one protagonist and eight NPCs.

Use placeholder names from a predefined list.

Render characters as simple circles or placeholder sprites with names.

## Acceptance Criteria

- Nine total characters spawn.
- Every character has valid personality values.
- Every character has needs and emotions.
- Every character exists in a valid starting location.
- Character simulation state is not stored exclusively in scene Nodes.
- Debug output can inspect the full character state.

---

# TASK-004 — NPC PROCEDURAL GENERATION

## Goal

Make each seed generate meaningfully different people.

## Implementation

Using the run seed, generate for each NPC:

- personality
- initial needs
- initial emotional state
- starting location
- one primary goal
- optional secondary goal
- starting inventory

Example NPC goals:

```text
EarnMoney
AvoidCharacter
MeetCharacter
RetrieveItem
HideItem
RepairRelationship
InvestigateLocation
LeaveBuilding
FindFood
Rest
```

Generation requirements:

Same seed:

```text
same characters
same traits
same starting states
```

Different seed:

```text
meaningfully different configuration
```

Add a debug screen or console output listing generated NPCs.

## Acceptance Criteria

- Seed 123 produces exactly the same generated NPC states every time.
- Seed 456 differs from seed 123.
- Generation does not create invalid locations.
- Goals reference valid world entities.
- Generated NPCs always have at least one actionable goal.
- No major gameplay event is directly generated here.

---

# TASK-005 — ACTION SYSTEM

## Goal

Create composable actions that AI can choose.

## Implementation

Create `BaseAction` with concepts including:

```text
id
actor
target
preconditions
duration
effects
status
```

Initial actions:

```text
Idle
MoveTo
Talk
Investigate
Help
Refuse
Rest
TakeItem
GiveItem
Flee
Confront
```

Each action should support conceptually:

```text
can_execute()
start()
tick()
complete()
```

Actions modify simulation state rather than UI state.

`MoveTo` moves between connected logical locations.

`Talk` requires two characters in the same location.

`Investigate` requires a valid location or object.

Do not implement complex animation.

## Acceptance Criteria

- Character can execute Idle.
- Character can move between locations.
- Character cannot instantly teleport across disconnected nodes.
- Character can Talk only when co-located.
- Invalid actions fail safely.
- Actions have measurable simulation duration.
- Action completion generates a structured event.

---

# TASK-006 — UTILITY AI

## Goal

Make NPCs choose what to do autonomously.

## Implementation

Implement a Utility AI decision engine.

Each decision cycle should:

1. gather possible actions
2. filter impossible actions
3. calculate scores
4. select an action
5. execute it

Action score concept:

```text
score =
goal_relevance
+ personality_modifier
+ need_modifier
+ emotional_modifier
+ relationship_modifier
+ controlled_noise
- risk
```

Controlled noise must use seeded RNG.

Do not make noise strong enough to overwhelm meaningful decision factors.

Store debug data for each candidate:

```text
action
score
reason components
```

Example:

```text
Investigate Room 407

goal: +3.0
curiosity: +1.7
fear: -0.8
distance: -0.4

total: 3.5
```

## Acceptance Criteria

- NPCs autonomously perform actions.
- Different personalities produce visibly different preferences.
- Decisions are reproducible using the same seed.
- AI does not choose impossible actions.
- Debug view can show action candidate scores.
- AI can explain the major reasons for its selected action.

---

# TASK-007 — PLAYER DIRECTIVES

## Goal

Add WANT / NEVER / BELIEVE.

## Implementation

Before a run begins, show a setup screen.

Player selects:

### WANT

Examples:

```text
Earn 5000 money
Learn the truth about Room 407
Make a friend
Survive until morning
Become trusted by most residents
```

### NEVER

Examples:

```text
Never steal
Never hurt anyone
Never lie
Never enter Room 407
Never trust police
```

### BELIEVE

Examples:

```text
Most people can be trusted
Everyone is hiding something
Money solves problems
Helping people pays off
Nobody gives anything for free
```

Create data types:

```text
WantDirective
NeverDirective
BeliefDirective
```

Apply them only to the protagonist.

Utility integration:

- WANT → strong positive scoring influence
- NEVER → strong penalty or invalidation depending on directive
- BELIEVE → interpretation/scoring change, not a forced path

Example:

```text
BELIEVE:
Everyone is hiding something
```

should increase utility for:

- investigate
- ask questions
- suspicion-related actions

but not force those actions every time.

## Acceptance Criteria

- Player can select all three directives.
- Protagonist behavior changes based on selected directives.
- NPCs do not inherit protagonist directives.
- NEVER visibly prevents or strongly discourages violating behavior.
- WANT contributes clearly to utility debug scores.
- BELIEVE modifies interpretation rather than creating a scripted path.

---

# TASK-008 — RELATIONSHIP SYSTEM

## Goal

Create a social graph rich enough to create consequences.

## Implementation

Implement directional relationships.

Each character pair may have:

```text
trust
fear
attraction
respect
debt
suspicion
```

Relationships must be directional:

```text
A -> B != B -> A
```

Generate initial relationships from the run seed.

Relationships should influence utility decisions.

Examples:

High trust:

```text
more likely to help
more likely to share information
```

High suspicion:

```text
more likely to investigate
less likely to believe statements
```

High fear:

```text
avoid
flee
comply
```

High debt:

```text
higher willingness to help
```

Actions update relationships where appropriate.

## Acceptance Criteria

- Relationships exist for relevant character pairs.
- A → B can differ from B → A.
- Help can increase trust/debt.
- Refusal can reduce trust.
- Confrontation affects fear/suspicion/respect.
- Relationship modifiers appear in AI debug scoring.

---

# TASK-009 — MEMORY SYSTEM

## Goal

Make characters remember meaningful events.

## Implementation

Each memory should contain:

```text
id
timestamp
event_type
participants
location
importance
emotional_impact
related_event_id
facts
```

Characters gain memories from significant events they directly experience.

Memories influence later decisions.

Example:

If Nina remembers Alex helping her:

```text
trust Alex increases
future Help Alex action receives positive modifier
```

Implement limited memory capacity.

Suggested:

```text
max 30 memories
```

When capacity is exceeded:

Prefer forgetting low-importance old memories.

Do not delete high-importance memories before trivial ones.

## Acceptance Criteria

- Characters remember experienced events.
- Characters do not automatically remember events they did not observe.
- Important events survive longer than trivial events.
- Memories affect at least one AI decision type.
- Memory list is inspectable in debug UI.

---

# TASK-010 — KNOWLEDGE & BELIEF PROPAGATION

## Goal

Prevent NPC omniscience.

## Implementation

The global simulation knows world truth.

Characters only know facts they:

- directly observed
- were told
- inferred if explicitly supported

Represent character knowledge as:

```text
subject
predicate
value
confidence
source
timestamp
```

Example:

```text
subject: Bob
predicate: near_room
value: Room407
confidence: 1.0
source: self
```

Implement basic information sharing during Talk.

Characters should sometimes share known facts.

Trust influences whether received information is believed.

Allow incorrect beliefs.

Example:

Tom says:

```text
Bob stole the key.
```

Jane may store:

```text
Bob stole key
confidence 0.45
source Tom
```

if Jane only partially trusts Tom.

## Acceptance Criteria

- NPC cannot use undiscovered world truth.
- Direct observation produces high-confidence knowledge.
- Shared information records its source.
- Trust affects confidence in received information.
- Different NPCs may hold contradictory beliefs.
- Debug inspector displays known facts and confidence.

---

# TASK-011 — SECRETS & RUN SETUP

## Goal

Generate initial conditions that create social pressure.

## Implementation

At run generation, create approximately 3–5 secrets.

Initial templates:

```text
A owes B money
A stole an item from B
A secretly likes B
A plans to leave tonight
A possesses the Room 407 key
A saw something near Room 407
A is hiding an item
A lied to B about something important
```

Secrets should modify actual world state.

Example:

If:

```text
A stole B's key
```

then:

- A has the key or hid it.
- B lacks the key.
- A knows they stole it.
- B may know the key is missing.
- B should not automatically know who stole it.

Avoid logical contradiction unless represented as intentionally false belief.

## Acceptance Criteria

- Each run contains multiple secrets.
- Same seed reproduces the same secrets.
- Secrets alter world state consistently.
- Characters only know secrets they logically should know.
- Secrets produce actionable motivations.
- Secrets themselves do not predetermine endings.

---

# TASK-012 — SOCIAL INTERACTIONS

## Goal

Make NPCs affect one another through richer social actions.

## Implementation

Add:

```text
AskQuestion
ShareInformation
Lie
Help
Refuse
Confront
```

Use personality and relationships.

Examples:

High honesty:

```text
less likely to lie
```

High greed:

```text
may demand payment or favors
```

High empathy:

```text
more likely to help
```

High suspicion:

```text
less likely to reveal sensitive facts
```

High fear:

```text
more likely to avoid confrontation
```

Dialogue may use simple templates.

Responses depend on:

- knowledge
- honesty
- relationship
- goals

No LLM.

## Acceptance Criteria

- NPCs can ask and answer questions.
- NPCs can share known facts.
- NPCs can lie.
- Lies create false beliefs, not world truth.
- Social interactions update relationships.
- Information can propagate across several NPCs.

---

# TASK-013 — CAUSAL EVENT SYSTEM

## Goal

Record WHY events happen.

## Implementation

Every meaningful simulation event should generate:

```text
event_id
timestamp
event_type
actor
targets
location
description
parent_event_ids
reasons
state_changes
```

Reasons may contain:

```text
goal contribution
personality contribution
relationship contribution
memory reference
belief reference
directive contribution
```

Example:

```text
Event:
Alex investigates Room 407

Reasons:
+ Want FindTruth
+ curiosity 0.8
+ Nina told Alex about noise
- fear 0.3
```

Do not store only human-readable strings.

Store structured references where practical.

## Acceptance Criteria

- Important actions produce causal events.
- Events have stable unique IDs.
- AI decision events store reason components.
- Later events can reference earlier events.
- Parent chain can be reconstructed.
- Event feed continues to show readable descriptions.

---

# TASK-014 — OBSERVER UI & DEBUG INSPECTOR

## Goal

Make the game readable to players and debuggable to developers.

## Implementation

Main screen layout:

### Top

Display:

```text
simulation time
seed
pause
x1
x2
x4
```

### Center

Apartment layout.

Characters visibly move between locations.

Show:

```text
character name
current action
```

### Left panel

Selected character:

```text
name
location
current action
primary goal
emotion
```

For protagonist:

```text
WANT
NEVER
BELIEVE
```

### Right panel

Live event feed.

Example:

```text
21:13 Nina entered Lobby.
21:15 Nina asked Tom about Room 407.
21:16 Tom lied to Nina.
21:17 Nina's suspicion increased.
```

### Developer Debug Mode

When enabled, show:

- personality
- needs
- goals
- emotions
- relationships
- memories
- knowledge
- current action
- candidate action utility scores

Do not expose debug information in normal player mode.

## Acceptance Criteria

- Clicking a character selects them.
- UI updates with current state.
- Event feed updates live.
- Protagonist directives are visible.
- Debug mode exposes full decision reasoning.
- No player control commands appear during simulation.

---

# TASK-015 — ROOM 407 MYSTERY CATALYST

## Goal

Make Room 407 a procedural catalyst rather than a fixed story.

## Implementation

At run generation, select zero or one Room 407 scenario.

Examples:

```text
hidden_money
missing_tenant
secret_meeting
stolen_goods
someone_hiding
abandoned_belongings
innocent_noise
irrelevant
```

Do NOT create a fixed canonical explanation.

Each scenario modifies:

- world state
- items
- secrets
- character knowledge
- relevant goals

The explanation must be logically discoverable through simulation.

Some runs should make Room 407 unimportant.

Do not force the protagonist to investigate.

## Acceptance Criteria

- Multiple Room 407 configurations exist.
- Same seed reproduces the configuration.
- Different configurations lead to different information chains.
- Room 407 can occasionally be irrelevant.
- No hardcoded quest path is required to resolve the mystery.
- NPCs can independently interact with Room 407-related state.

---

# TASK-016 — RUN ENDING & CAUSAL TIMELINE

## Goal

Give the simulation a satisfying end-of-run payoff.

## Implementation

A run ends at 06:00.

Evaluate:

### WANT

```text
success
partial
failure
```

### NEVER

```text
respected
violated
```

### BELIEVE

Do not score as pass/fail.

Instead summarize important decisions influenced by the belief.

Show:

- protagonist final state
- goal outcome
- directive violations
- major relationships
- discovered secrets
- major memories
- important world events

Implement a causal timeline.

Example:

```text
Player chose:
Find truth about Room 407

↓
Nina heard suspicious noise

↓
Nina told Alex

↓
Alex investigated hallway

↓
Alex found Bob's key

↓
Alex confronted Bob

↓
Bob lied

↓
Tom contradicted Bob

↓
Alex discovered stolen goods
```

Start with a simple vertical timeline.

Do not build a complex graph editor.

## Acceptance Criteria

- Run ends automatically at 06:00.
- WANT is evaluated.
- NEVER violation is shown.
- Major events are summarized.
- Causal chains can be viewed.
- Player has:
  - Run Again
  - Replay Same Seed
  - New Seed

---

# TASK-017 — DETERMINISM & TEST SUITE

## Goal

Prove that the simulation is reproducible.

## Implementation

Create automated simulation tests.

Important tests:

### Seed Determinism

Run:

```text
seed = 12345
same directives
```

twice.

Important event sequence must match.

### Seed Variation

Run with:

```text
12345
54321
```

NPC configuration or important event sequence should differ.

### Knowledge Isolation

Character cannot use a fact they never observed or received.

### Relationship Directionality

Verify:

```text
A -> B
```

does not overwrite:

```text
B -> A
```

### NEVER Rule

Test at least one prohibited action.

### Memory Capacity

Verify low-importance memories are removed before important memories.

### Causal Reference

Verify child events can reference parent events.

Create a headless simulation runner if useful.

## Acceptance Criteria

- Tests can run repeatedly.
- Determinism tests pass.
- Tests do not depend on rendering FPS.
- Failing tests produce understandable output.
- Seeded random sequence remains centralized.

---

# TASK-018 — EMERGENT STORY STRESS TEST

## Goal

Verify that the game creates stories rather than random wandering.

## Implementation

Create a developer simulation stress-test mode.

Run at least:

```text
50 simulation runs
```

using sequential seeds.

Collect metrics:

```text
number of interactions
number of conversations
information transfers
lies
relationship changes
investigations
conflicts
secrets discovered
WANT success rate
NEVER violation rate
unique major event sequences
```

Print a readable summary.

Detect pathological behavior such as:

- NPC repeatedly performing the same action
- characters doing nothing for long periods
- everyone choosing identical goals
- secrets never being discovered
- Room 407 always dominating every run
- protagonist always succeeding
- protagonist always failing

Do not artificially force outcomes to balance statistics.

Use metrics to expose simulation weaknesses.

## Acceptance Criteria

- 50 runs execute without crashes.
- Simulation does not enter infinite loops.
- Multiple different event sequences occur.
- Some goals succeed and some fail.
- NPC action distributions are not completely uniform or identical.
- Summary identifies repetitive patterns.

---

# TASK-019 — SIMULATION TUNING

## Goal

Improve variety without making RNG drive the story.

## Implementation

Review results from the simulation stress test.

Tune:

- action utility weights
- personality influence
- goal influence
- relationship influence
- memory influence
- belief influence
- directive influence
- controlled random noise

Objectives:

1. Player directives should strongly influence protagonist behavior.
2. Personality should meaningfully affect action choices.
3. Same directive + different seed should produce different stories.
4. Major outcomes should remain explainable.
5. Controlled randomness should break ties, not drive the story.
6. NPCs should interact frequently enough to create social consequences.
7. Not every NPC should interact with the protagonist.
8. Room 407 should not dominate every run.

Do not add major new systems.

Tune existing systems.

## Acceptance Criteria

Re-run stress tests.

Results should show:

- meaningful variety
- fewer repetitive loops
- multiple causal chains
- information propagation
- relationship changes
- variable protagonist outcomes

Document major weight changes.

---

# TASK-020 — MVP POLISH & DELIVERY

## Goal

Turn the simulation prototype into a playable MVP.

## Implementation

Focus on clarity and usability.

Do not add major systems.

### Setup Screen

Clearly explain:

```text
Choose one WANT.
Choose one NEVER.
Choose one BELIEVE.

After the simulation starts, you cannot control the character.
```

### Observer Screen

Make it easy to understand:

- who is where
- what they are doing
- what important events occurred

### Run End Screen

Make causal consequences the focus.

### Run Controls

Provide:

```text
Replay Same Seed
New Random Seed
Change Directives
```

### Developer Mode

Keep debug tools accessible but separate from normal UX.

### README

Document:

```text
Game concept
How to run
Architecture
Simulation model
Seed determinism
Utility AI
Memory
Knowledge
Relationships
Directives
Known limitations
Future ideas
```

Remove obvious dead code and unresolved errors.

## Final Acceptance Criteria

The full flow must work:

1. Launch game.
2. Select WANT.
3. Select NEVER.
4. Select BELIEVE.
5. See generated protagonist.
6. Start simulation.
7. Lose direct control.
8. Watch protagonist make autonomous decisions.
9. Watch NPCs interact independently.
10. Observe information spread.
11. Observe memories and relationships affecting behavior.
12. Observe emergent events.
13. Reach 06:00.
14. See outcome.
15. See causal explanation.
16. Replay same seed.
17. Obtain reproducible result.
18. Use new seed with same directives.
19. Observe a meaningfully different story.

The MVP is successful if the player finishes one run and immediately wants to click:

> Run Again.

---

# OPTIONAL TASK-021 — SAVE RUN RECORD

Do only after the MVP works.

Implement exportable run records.

Save:

```text
seed
directives
generated characters
initial relationships
initial secrets
major causal events
ending result
```

Use JSON.

Goal:

Allow developers to reproduce interesting or broken runs.

Acceptance:

A saved run record contains enough information to replay or debug the simulation.

---

# OPTIONAL TASK-022 — NATURAL LANGUAGE DIRECTIVES

Do NOT implement until predefined directives work well.

Add a lightweight interface:

```text
parse_directive(text)
```

For now it may map phrases to existing structured directives.

Example:

```text
"I need money no matter what"
```

could map toward:

```text
WantDirective.EARN_MONEY
```

Do not let free-form text directly control arbitrary simulation state.

Long term, an LLM parser may plug into this interface.

Core simulation must remain structured and deterministic.

---

# OPTIONAL TASK-023 — LLM DIALOGUE ADAPTER

Do NOT make this required for gameplay.

Create an interface:

```text
DialogueProvider
```

Implement:

```text
TemplateDialogueProvider
```

Future:

```text
LLMDialogueProvider
```

Dialogue input should include:

```text
speaker
listener
topic
knowledge
relationship
emotion
intent
```

Dialogue output must never directly modify world state.

Simulation actions determine truth.

Dialogue only represents decisions made by simulation.

---

# CODEX BUGFIX PROMPT

Use when the build starts failing.

```text
You are in bug-fixing mode.

Do not add new gameplay features.

Inspect the current Godot project and identify:

- parser errors
- runtime errors
- invalid node references
- invalid resources
- circular dependencies
- type errors
- deterministic simulation violations
- accidental use of global RNG
- invalid generated state

Fix the smallest root cause possible.

Do not rewrite working systems unless necessary.

After fixing:

1. Run automated tests.
2. Run the project.
3. Verify the main gameplay loop.
4. Report the root cause and exact fix.
```

---

# CODEX REFACTOR PROMPT

Use only when the system has become difficult to maintain.

```text
Review the current project architecture.

Do not add features.

Identify only concrete maintainability problems such as:

- oversized classes
- duplicated decision logic
- simulation code depending on UI
- circular dependencies
- repeated seeded-random logic
- hardcoded entity lookup
- event logging duplicated across actions

Refactor only issues that currently create development friction.

Rules:

- preserve behavior
- preserve seed determinism
- run tests before and after
- avoid speculative abstractions

If existing architecture is adequate, do not refactor it.
```

---

# CODEX SIMULATION REVIEW PROMPT

Use after TASK-018 or whenever NPC behavior feels unintelligent.

```text
Review the simulation as a game systems designer.

Do not focus on graphics.

Investigate why NPC behavior may feel:

- random
- repetitive
- passive
- omniscient
- irrational
- overly predictable

Inspect:

- utility weights
- goals
- action availability
- knowledge boundaries
- memory effects
- relationships
- emotional state
- event frequency
- controlled randomness

Find systemic causes.

Prefer fixing interactions between existing systems rather than adding new content.

Provide concrete recommendations and implement the highest-impact low-scope fixes.

Re-run simulation stress tests afterward.
```

---

# DEVELOPMENT CHECKPOINTS

Do not judge progress only by the number of implemented classes.

## Checkpoint A — After TASK-006

Question:

> Do NPCs look like they want something, or are they simply walking randomly?

If they just walk randomly, stop and fix Utility AI.

## Checkpoint B — After TASK-010

Question:

> Does what happened earlier change later NPC behavior?

If not, stop and strengthen relationships, memory, and knowledge.

## Checkpoint C — After TASK-013

Question:

> Can the game explain WHY something happened?

If not, stop and improve causal logging.

## Checkpoint D — After TASK-018

Question:

> Does the same player directive produce recognizably different stories across seeds?

If only names change, the emergent simulation is not deep enough.

## Checkpoint E — After TASK-020

The player should experience:

> “I wonder what would happen if I chose the same thing again.”

That feeling is the primary success metric of the MVP.

---

# MOST IMPORTANT RULE

Whenever choosing between:

```text
adding 20 more scripted events
```

and:

```text
making 5 existing systems interact more deeply
```

choose deeper systemic interaction.

This game's content should primarily come from:

```text
Personality
× Goals
× Relationships
× Knowledge
× Memory
× Directives
× Circumstances
```

not from a giant branching storyline.
