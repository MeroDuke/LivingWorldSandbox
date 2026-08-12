$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $repositoryRoot 'GPL\LWS_MonsterState.gpl'
$policyPath = Join-Path $repositoryRoot 'Docs\monster-ability-policy.md'
$source = Get-Content -LiteralPath $sourcePath -Raw

function Assert-Contains([string]$Pattern, [string]$Message) {
    if ($source -notmatch $Pattern) { throw $Message }
}

Assert-Contains 'if \( ProgressClass <= 1 \) return;' 'C1 monsters must be excluded.'
Assert-Contains 'NewLevel == 3' 'Level 3 milestone is missing.'
Assert-Contains 'NewLevel == 6' 'Level 6 milestone is missing.'
Assert-Contains 'NewLevel == 9' 'Level 9 milestone is missing.'
Assert-Contains '\$IsSpellAvailable \( Monster, SpellName, 1 \) == FALSE' 'Exact duplicate guard is missing.'
Assert-Contains '\$LWS_HasSurvivalAbility' 'Survival-family duplicate guard is missing.'
Assert-Contains '\$LWS_HasOffensiveAbility' 'Offensive-family duplicate guard is missing.'
Assert-Contains '\$LWS_HasUtilityAbility' 'Utility-family duplicate guard is missing.'
Assert-Contains '\$LWS_IsUndeadMonster' 'Undead lore guard is missing.'
Assert-Contains '\$LWS_IsSupportMonster' 'Support archetype guard is missing.'
Assert-Contains '\$LWS_ApplyAbilityMilestone \( Monster, Monster''s "LWS_Level" \);' 'Level-up integration is missing.'

if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
    throw 'Monster ability policy documentation is missing.'
}

Write-Host 'Monster ability policy checks passed.'
