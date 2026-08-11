[CmdletBinding()]
param(
    [string]$SdkPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$sdkCandidates = @()
if ($SdkPath) { $sdkCandidates += $SdkPath }
if ($env:MAJESTYSDK) { $sdkCandidates += $env:MAJESTYSDK }
$sdkCandidates += Join-Path $repositoryRoot 'SDK'

$resolvedSdk = $sdkCandidates |
    Where-Object { Test-Path -LiteralPath $_ -PathType Container } |
    Select-Object -First 1
if (-not $resolvedSdk) {
    throw 'Majesty SDK was not found. Pass -SdkPath or set MAJESTYSDK.'
}

$sourcePath = Join-Path $resolvedSdk 'OriginalQuests\GPLMx\DecisionTrees\Modules\mx_Eval_Items.gpl'
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Northern Expansion item evaluation source was not found: $sourcePath"
}
if (-not $OutputPath) {
    $OutputPath = Join-Path $repositoryRoot 'GPL\Generated\LWS_MX_Eval_Items.gpl'
}

$source = Get-Content -LiteralPath $sourcePath -Raw
$nearbyNeedle = 'Item = $ListMember (Items, 1);'
$globalNeedle = 'This_resource = $ListMember (Resources, 1);'
$pickupNeedle = 'If (Target''s "Title" == "Treasure_Chest")'

if ([regex]::Matches($source, [regex]::Escape($nearbyNeedle)).Count -ne 1) { throw 'Could not locate unique nearby item selection.' }
if ([regex]::Matches($source, [regex]::Escape($globalNeedle)).Count -ne 1) { throw 'Could not locate unique global item selection.' }
if ([regex]::Matches($source, [regex]::Escape($pickupNeedle)).Count -ne 1) { throw 'Could not locate unique item pickup point.' }

$source = $source.Replace($nearbyNeedle, @"
Item = `$LWS_SelectDesiredSpecialItem (ThisAgent, Items);

                    If (`$IsValidGamePiece (Item) == FALSE)
                        return False;

                    // LWS: do not reserve a potion that this hero cannot carry.
                    If (Item's "Title" == "LWS_HealingPotion" && `$GetAttribute (ThisAgent, #ATTRIB_NumHealingPotions) >= #Max_Heal_Potions)
                        return False;
"@)
$source = $source.Replace($globalNeedle, @"
This_resource = `$LWS_SelectDesiredSpecialItem (ThisAgent, Resources);

            If (`$IsValidGamePiece (This_resource) == FALSE)
                return False;

            // LWS: leave capped potion drops available for another hero.
            If (This_resource's "Title" == "LWS_HealingPotion" && `$GetAttribute (ThisAgent, #ATTRIB_NumHealingPotions) >= #Max_Heal_Potions)
                return False;
"@)
$source = $source.Replace($pickupNeedle, @"
If (Target's "Title" == "LWS_HealingPotion" && `$GetAttribute (ThisAgent, #ATTRIB_NumHealingPotions) >= #Max_Heal_Potions)
                        begin
                            `$Reset_Tasks (ThisAgent);
                            return;
                        end

                    If (`$HasAttribute ("LWS_EquipmentType", Target) && `$LWS_ShouldRetrieveEquipment (ThisAgent, Target) == FALSE)
                        begin
                            // Precompiled hero decision trees can select this item again even though
                            // the generated evaluator filters it. Remove inspected inferior loot to
                            // prevent an endless retrieve/reject loop.
                            `$DeleteGamePiece (Target);
                            `$Reset_Tasks (ThisAgent);
                            return;
                        end

                    $pickupNeedle
"@)

$header = @(
    '// GENERATED FILE - DO NOT EDIT OR COMMIT.',
    '// Derived at build time from the locally installed Northern Expansion SDK.',
    '// LWS change: heroes ignore capped potions and remove inspected inferior equipment.',
    ''
)
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
Set-Content -LiteralPath $OutputPath -Value (($header -join "`r`n") + "`r`n" + $source) -Encoding Ascii
Write-Host "Generated Northern Expansion item evaluation override at $OutputPath"
