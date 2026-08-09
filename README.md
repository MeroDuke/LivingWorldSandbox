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
`LWS_Level`. The combat diagnostic verifies every classification boundary and
first-level threshold with temporary units, then removes them before creating
the focused equipment arena.

## Stat growth

Each monster level adds 5% of the monster's original MaxHP (minimum one point),
one point of Dodge and Parry, and one point of either HtoH or Ranged accuracy
according to its attack type. Strength increases every third level and Magic
Resistance every fifth level. Accuracy and avoidance stop at 98. Current HP
increases only by the MaxHP increment, preserving all previously missing HP;
level-up never performs a full heal. Temporary diagnostic monsters are set to
half health before leveling and PASS only if they remain injured.

## Building destruction perks

Destroying an enemy player building increments the individual monster's
`LWS_BuildingsDestroyed` counter and has a 35% chance to grant one permanent
stat perk. Combat improves attack accuracy and Strength, defense improves armor,
Parry, and Dodge, and magic improves Magic Resistance with a 95 cap. Monsters
can receive at most three building perks. Lairs never count as buildings. The
diagnostic forces each reward branch and verifies both a failed roll and the cap;
production combat uses random rolls. The temporary perk tester is removed before
the focused equipment arena is created.

## Healing potion loot

A monster death has an 8% chance to drop a custom Healing Potion
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
The old peasant crowd, nearby weak monsters, and scattered potion pickups are
not part of the current arena.
Short-lived peasant targets used by deterministic checks are detached from the
real Palace immediately after spawn, so they do not consume its internal
worker slots or stop normal builder/repairer spawning.

## Tiered equipment diagnostic

The first equipment implementation separates a weapon's quality tier from its
drop affix. The tiers follow the Blacksmith research UI: `T2`, `T3`, and `T4`
contribute `+1`, `+2`, and `+3` structural
bonus respectively; the affix is preserved when the Blacksmith improves the
tier. A Bronze `T2 Longsword +6` therefore has effective structural bonus 7 and
becomes `T3 +6` (effective 8), then `T4 +6` (effective 9).
The native `Weapon_Struct_Bonus` stores only the tier contribution so Majesty's
equipment name remains Bronze/T2, T3, or T4 as appropriate. The affix is added
to the hero's captured original `WeaponBasicDamage`; the native combat formula
and displayed numeric weapon value therefore still include the complete bonus.

After PASS the diagnostic creates a focused arena containing one level-8
Paladin, its completed Warriors Guild, one level-3 Blacksmith with all equipment
research explicitly cleared, and a nearby
`T3 Longsword +1` pickup. Its effective structural bonus is 3, producing a
visible Paladin weapon value of 13. The Paladin has 1000 carried gold plus 1000 stored
gold and a guaranteed equipment-upgrade consideration roll. Research the next
weapon quality at the Blacksmith and allow the autonomous Paladin time to visit
it. The Blacksmith decision uses the separate tier, so the already-high `+6`
affix does not prevent the visit.

The generated item-evaluation override filters equipment before the hero starts
retrieving it and repeats the comparison immediately before pickup. Inferior or
equal weapons are never equipped. Some precompiled hero decision paths bypass
the generated pre-filter, so an inferior drop that a hero has already reached
is removed from the ground to prevent an endless retrieve/reject loop. This is
an interim ground-loot cleanup rule until the later inventory system can replace
it with selling, salvaging, or per-hero ignore memory.

The former forced 100% diagnostic weapon and armor drop rate is disabled now
that the replacement and Blacksmith paths have been manually verified. The
drop handlers and tier/affix logic remain available for the later production
drop table. The diagnostic PASS signal remains the 7777 treasury-gold increase.
Four deliberately weak Giant Rats start 550-700 units away from the Paladin
without overriding the nearby starting equipment pickup with an immediate
combat decision.

## Equipment compatibility

Every LWS weapon and armor item carries an explicit equipment family. Pickup is
allowed only when that family matches the hero's Northern Expansion
`AllowedWeapon` or `AllowedArmor` definition. The complete allowed and forbidden
matrix is stored in `Docs/equipment-compatibility.json`, with a readable summary
in `Docs/equipment-compatibility.md`. `tools/Test-EquipmentCompatibility.ps1`
compares the matrix to both SDK character layers and verifies the runtime guard.

## Equipment rarity and power

Weapons and armor use separate tier and affix values. T1-T4 contribute 0-3
base power; weapon affixes count once and armor affixes count twice, matching
the Northern Expansion armor-magic calculation. Power maps to Common,
Uncommon, Rare, or Epic. Legendary is reserved for predefined Unique items and
is never produced by the normal power budget. The machine-readable rules live
in `Docs/equipment-rarity.json`, with rationale and examples in
`Docs/equipment-rarity.md`.

## Direct spell kill attribution

Monster-cast direct damage spells use the Northern Expansion
`spelldamage(attacker, defender, ...)` pipeline and receive kill credit through
the same fatal-hit rules as normal attacks. Enemy kills count; friendly Monster
Player targets do not. Player-cast spells have no attacker agent and therefore
cannot grant monster progression. Poison and other engine-periodic damage are
not yet attributed because the vanilla periodic HP drain does not retain its
source agent. The diagnostic advances a temporary Goblin Priest to level 2
using only direct spell damage and removes it after verification.
