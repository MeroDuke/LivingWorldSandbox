[CmdletBinding()]
param(
    [string]$GplOutputPath,
    [string]$TextOutputPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if (-not $GplOutputPath) { $GplOutputPath = Join-Path $repositoryRoot 'GPL\Generated\LWS_VeteranNames.gpl' }
if (-not $TextOutputPath) { $TextOutputPath = Join-Path $repositoryRoot 'Data\LWS_VeteranNames.xml' }

$families = @(
    [pscustomobject]@{ Id = 1; Code = 'RAT'; Given = @('Mickey','Nibbles','Whiskers','Squeak','Gnawbert','Scurry','Ratticus','Cheddar','Scraps','Fang'); Titles = @('Destroyer of Cheese','the Sewer King','the Crumb Reaper','Gnawer of Crowns','the Plague Tail','the Uncaught','Bane of Granaries','the Palace Burrower','Lord of Leftovers','the Red-Toothed') },
    [pscustomobject]@{ Id = 2; Code = 'UNDEAD'; Given = @('Mordek','Vesper','Ashen','Grimhollow','Morvane','Sepulchra','Dreadbone','Nethros','Palehand','Cryptus'); Titles = @('the Restless','Keeper of the Last Breath','the Grave Walker','Bane of the Living','the Unburied','Warden of Dust','the Hollow-Eyed','Lord of the Barrow','the Deathless','Caller of Cold Graves') },
    [pscustomobject]@{ Id = 3; Code = 'GOBLIN'; Given = @('Gribnak','Snikk','Mogwort','Razzik','Grotfang','Nibz','Skab','Zoggit','Krikka','Boggle'); Titles = @('Coin-Biter','the Boot Collector','King of Scrap','the Loudest','Bane of Kneecaps','the Shiny Thief','the Unwashed','Lord of Bad Ideas','the Torch Juggler','Breaker of Barrels') },
    [pscustomobject]@{ Id = 4; Code = 'BEAST'; Given = @('Fang','Stormhide','Redclaw','Moonhowl','Bramble','Ironmane','Nightpaw','Thornback','Wildheart','Greymaw'); Titles = @('the Untamed','Hunter of Heroes','the Elder Fang','Bane of Poachers','the Trail Stalker','Guardian of the Wild','the Blood-Scented','the Unbroken','Lord of the Hunt','the Palace Prowler') },
    [pscustomobject]@{ Id = 5; Code = 'GIANT'; Given = @('Urgath','Boulderfist','Morgul','Thundergut','Krag','Doomclub','Bront','Skullbasher','Gorom','Stonebelly'); Titles = @('the Bridgebreaker','Crusher of Towers','the Mountain That Walks','Bane of Walls','the Iron Belly','the Unstoppable','Lord of the Crags','the Castle Shaker','the Mighty','Breaker of Heroes') },
    [pscustomobject]@{ Id = 6; Code = 'ARCANE'; Given = @('Azrath','Velkan','Malovar','Zareth','Noctivar','Caldris','Ophiron','Xandrel','Vael','Ravaryn'); Titles = @('the Spell-Eater','Master of Ruin','the Veil Piercer','Bane of Wizards','the Unbound','Keeper of Forbidden Fire','the Starless','Lord of Hexes','the Ever-Watching','Breaker of Wards') },
    [pscustomobject]@{ Id = 7; Code = 'GENERIC'; Given = @('Gorak','Vex','Karn','Ruin','Tharos','Brakka','Mourn','Dargan','Krell','Vorik'); Titles = @('the Unyielding','Bane of Heroes','the Veteran','the Bloodied','the Unconquered','Keeper of Scars','the Relentless','Lord of the Wilds','the Dreaded','Breaker of Oaths') }
)

$gpl = [System.Collections.Generic.List[string]]::new()
$gpl.Add('////////////////////////////////////////////////////////////////////////////////////////////////////////')
$gpl.Add('// Generated veteran monster display-name resolver. Do not edit by hand.')
$gpl.Add('////////////////////////////////////////////////////////////////////////////////////////////////////////')
$gpl.Add('')
$gpl.Add('Function LWS_VeteranNameCount ( integer NameFamily ) is integer')
$gpl.Add('Declare')
$gpl.Add('Begin')
foreach ($family in $families) { $gpl.Add("    if ( NameFamily == $($family.Id) ) return $($family.Given.Count * $family.Titles.Count);") }
$gpl.Add('    return 0;')
$gpl.Add('End')
$gpl.Add('')
$gpl.Add('Function LWS_VeteranNameKey ( integer NameFamily, integer NameRoll ) is string')
$gpl.Add('Declare')
$gpl.Add('Begin')

$xml = [System.Collections.Generic.List[string]]::new()
$xml.Add('<Majesty>')
$xml.Add('  <Language id="en_US">')
foreach ($family in $families) {
    $gpl.Add("    if ( NameFamily == $($family.Id) )")
    $gpl.Add('        begin')
    $index = 0
    foreach ($given in $family.Given) {
        foreach ($title in $family.Titles) {
            $key = ('IDTXT_LWS_VETERAN_{0}_{1:D3}' -f $family.Code, $index)
            $gpl.Add("            if ( NameRoll == $index ) return `"$key`";")
            $escapedName = [Security.SecurityElement]::Escape("$given $title")
            $xml.Add("    <Text id=`"$key`">$escapedName</Text>")
            $index++
        }
    }
    $gpl.Add('        end')
}
$gpl.Add('    return "";')
$gpl.Add('End')
$xml.Add('  </Language>')
$xml.Add('</Majesty>')

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $GplOutputPath) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $TextOutputPath) | Out-Null
[IO.File]::WriteAllLines($GplOutputPath, $gpl, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllLines($TextOutputPath, $xml, [Text.UTF8Encoding]::new($false))
Write-Host "Generated $GplOutputPath and $TextOutputPath"
