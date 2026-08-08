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

Copy these files with their directory structure to run it:

- `LWSCombatDiagnostic.mqxml`
- `Data/LWSCombatDiagnostic.bcd`
- `Quests/LivingWorldSandbox.q`

The diagnostic adds 7777 treasury gold when all checks pass, or 111 gold when
one or more checks fail. The detailed result is also written with `DebugOut`.
