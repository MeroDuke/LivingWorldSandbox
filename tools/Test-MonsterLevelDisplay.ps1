$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$statePath = Join-Path $repositoryRoot 'GPL\LWS_MonsterState.gpl'
$state = Get-Content -Raw -LiteralPath $statePath

function Assert-Match([string]$Text, [string]$Pattern, [string]$Message) {
    if ($Text -notmatch $Pattern) { throw $Message }
}

Assert-Match $state 'Function\s+LWS_SyncMonsterDisplayLevel\s*\(\s*agent\s+Monster\s*\)' `
    'The monster display-level synchronization function is missing.'
Assert-Match $state '\$SetAttribute\s*\(\s*Monster\s*,\s*#ATTRIB_ExperienceLevel\s*,\s*Monster''s\s+"LWS_Level"\s*\)' `
    'The UI-facing ExperienceLevel is not mirrored from LWS_Level.'

$ensurePattern = '(?s)Function\s+LWS_EnsureMonsterState.*?\$LWS_SyncMonsterDisplayLevel\s*\(\s*Monster\s*\s*\);.*?End'
Assert-Match $state $ensurePattern `
    'State restoration must reapply the visible monster level after display-name restoration.'

$levelUpPattern = '(?s)Monster''s\s+"LWS_Level"\s*\+=\s*1\s*;\s*\$LWS_SyncMonsterDisplayLevel\s*\(\s*Monster\s*\s*\);'
Assert-Match $state $levelUpPattern `
    'Monster level-up must synchronize the visible level immediately.'

$nameSyncPattern = '(?s)if\s*\(\s*Monster''s\s+"LWS_VeteranNameKey"\s*!=\s*""\s*\).*?\$SpecifyName.*?\$LWS_SyncMonsterDisplayLevel'
Assert-Match $state $nameSyncPattern `
    'Veteran display-name restoration must be followed by level synchronization.'

Write-Host 'Monster level display regression checks passed.'
