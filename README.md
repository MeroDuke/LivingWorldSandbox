# LivingWorldSandbox

A Majesty Gold HD / Northern Expansion sandbox quest.

The current baseline intentionally contains only:

- one player Palace supplied by the quest template;
- six starter monster lairs;
- twenty-four starter roaming monsters.

## Project layout

- `LivingWorldSandbox.mqxml` - master quest definition and runtime load graph;
- `Quests/LivingWorldSandbox.q` - map template and starting conditions;
- `GPL/LivingWorldSandbox.gpl` - quest bootstrap source;
- `GPL/LivingWorldSandbox.gplproj` - compiler input manifest;
- `Data/LivingWorldSandbox.bcd` - compiled GPL bytecode loaded by the game.

The Majesty SDK is a local, read-only dependency and is not stored in this repository.

## Local build

On Windows, either set `MAJESTYSDK` to the SDK directory or pass it explicitly:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Build-Quest.ps1 -SdkPath C:\path\to\MajestySDK
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-QuestBaseline.ps1
```

The build always produces the canonical runtime artifact at
`Data/LivingWorldSandbox.bcd`.

## Ready-to-copy packages

Create clean runtime-only packages under `output/`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\New-QuestPackages.ps1
```

Add `-Build` (and optionally `-SdkPath`) to compile both bytecode targets before
packaging. Copy the complete contents of the required package directory into the
Majesty quest directory; do not copy individual files from the source tree:

- `output/LivingWorldSandbox/` - normal playable sandbox;
- `output/LWSCombatDiagnostic/` - isolated Phase 0 diagnostic.

The generated `output/` directory is intentionally excluded from Git.

## CI

Package validation runs on a GitHub-hosted Windows runner. GPL compilation uses a
self-hosted Windows x64 runner with the custom label `majesty-sdk` and the
`MAJESTYSDK` environment variable configured for the runner service. Set the
repository variable `MAJESTY_SDK_RUNNER_ENABLED` to `true` after the runner is
online. Until then, hosted package validation still runs and the compile job is
skipped. Pull requests never execute code on the SDK-bearing self-hosted runner;
compilation runs only for trusted pushes or an explicit manual dispatch.

CI recompiles the GPL source and fails if the committed bytecode is not exactly
reproducible.

## Phase 0 combat diagnostic

`LWSCombatDiagnostic.mqxml` is a developer-only Northern Expansion quest. It
loads `Data/LWSCombatDiagnostic.bcd`, preserves the production starter
ecosystem, and invokes controlled combat-pipeline checks directly without
waiting for autonomous heroes or monsters to choose a fight.

Generate the packages and copy the complete contents of
`output/LWSCombatDiagnostic/` to run it.

The diagnostic adds 7777 treasury gold when all checks pass, or 111 gold when
one or more checks fail. The detailed result is also written with `DebugOut`.

## Phase 1 monster state

Each starter monster receives its own idempotent progression state at spawn:
`LWS_Level`, per-level and total kill counters, destroyed-building count,
progression class, and perk storage. Progression class is derived from the
Northern Expansion `LevelXP` value: starter `1-250`, low `251-550`, medium
`551-900`, high `901-2000`, and brutal `2001+`; zero-XP special units remain
unclassified. Kill thresholds are respectively `1/2/3/4`, `2/3/4/5`,
`4/6/8/10`, `12/16/20/24`, and `20/30/40/50`, with the fourth value repeated
after level 4. The visible native experience level is synchronized with
`LWS_Level`; stat growth, perks, and loot remain disabled. The combat diagnostic
verifies every classification boundary and first-level threshold, then leaves
the test rat beside nine enemy peasants for observable AI-driven progression.
It also leaves five level-2 showcase monsters near the Palace: Giant Rat
(starter), Ratman (low), Troll (medium), Minotaur (high), and Dragon (brutal).
The diagnostic passes only when each monster reaches level 2 after receiving
exactly its class-specific number of kill credits.

## Stat growth

Each monster level adds 5% of the monster's original MaxHP (minimum one point),
one point of Dodge and Parry, and one point of either HtoH or Ranged accuracy
according to its attack type. Strength increases every third level and Magic
Resistance every fifth level. Accuracy and avoidance stop at 98. Current HP
increases only by the MaxHP increment, preserving all previously missing HP;
level-up never performs a full heal. The five diagnostic showcase monsters are
set to half health before leveling and PASS only if they remain injured.

## Building destruction perks

Destroying an enemy player building increments the individual monster's
`LWS_BuildingsDestroyed` counter and has a 35% chance to grant one permanent
stat perk. Combat improves attack accuracy and Strength, defense improves armor,
Parry, and Dodge, and magic improves Magic Resistance with a 95 cap. Monsters
can receive at most three building perks. Lairs never count as buildings. The
diagnostic forces each reward branch and verifies both a failed roll and the cap;
production combat uses random rolls. It leaves a three-perk Goblin Overlord near
the Palace with 72 HtoH, 19 Strength, 4 armor, 61 Parry, 51 Dodge, and 23 Magic
Resistance so the combined permanent bonuses can be inspected in the UI.

## Healing potion loot

A monster death temporarily has a 50% chance to drop a custom Healing Potion
special item. Any hero collecting it receives exactly one native
`#ATTRIB_NumHealingPotions`, up to the vanilla carrying cap, and can consume it
through the unchanged Northern Expansion `heal_self` behavior. The item uses the
generic vanilla special-item world art because Majesty has no placeable potion
bottle unit. Healing herbs remain untouched and retain their original
five-herbs-per-potion behavior. The diagnostic forces one failed and one
successful drop roll, then verifies pickup increments a Rogue's native potion
counter by exactly one.
Ground drops carry Majesty's generated inventory attribute, allowing the
vanilla `Eval_Items` behavior to retrieve and transfer them normally.
Heroes already carrying the vanilla maximum of five healing potions ignore
these drops, leaving them on the ground for another hero.
After PASS it removes the dangerous class/perk showcase monsters and creates a
separate autonomous arena: one level-8 Paladin at half health, six nearby weak
monsters (Giant Rats and Skeletons), and three scattered Healing Potion pickups.
The arena includes a completed player-owned Warriors Guild which adopts the
Paladin as a member, preventing the otherwise homeless hero from leaving the
map. The arena makes combat and loot visible, but its random outcome cannot
change PASS/FAIL.
