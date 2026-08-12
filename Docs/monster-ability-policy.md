# Monster ability progression

The normal LWS level growth remains unchanged. Ability milestones are a separate layer and
use only spells already supplied by the Northern Expansion SDK.

| Progress class | Level 3: survival | Level 6: offense | Level 9: utility/buff |
|---:|---|---|---|
| C1 | none | none | none |
| C2 | `Speed_Monster` or `Damage_Shield` | `Insect_Swarm` or `Energy_Blast` | `Resist_Magic` |
| C3 | `Flame_Shield`, undead: `Resist_Magic` | nature: `Acid_Bolt`, otherwise `Electrical_Fury` | `Iron_Will` |
| C4 | `Monk_Stone_Skin` | undead: `Horrify`, nature: `Pestilence`, otherwise `Acid_Bolt` | undead: `Iron_Will`, otherwise `Shield_of_Light` |
| C5 | `Monk_Stone_Skin` | undead: `Drain_Life`, otherwise `Horrify` | `Vigilance` |

Priest and Shaman support archetypes prefer `Speed_Monster` at level 9. The native Goblin
Priest already learns this spell at birth, so its existing ability satisfies the slot.

## Safety rules

- C1 monsters keep only their existing statistical level growth.
- Progress class is a hard power ceiling and never changes through leveling.
- A native spell in the same role satisfies the milestone; LWS does not add another one.
- `$IsSpellAvailable` prevents exact duplicate learning.
- Undead never receive divine or nature-themed buffs from this system.
- `SuperBuff`, summons, hard-control packages, and custom spells are excluded.
- If no lore-safe SDK spell exists, the milestone may remain empty.

The granted spell name is recorded in `LWS_AbilityLevel3`, `LWS_AbilityLevel6`, or
`LWS_AbilityLevel9` for diagnostics and future migration.
