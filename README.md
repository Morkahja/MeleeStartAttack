# Melee Start Attack

One World of Warcraft **1.12.1 (Vanilla)** addon for Paladins, Warriors, and Shamans.

It starts normal melee auto-attack when you press a supported action-bar button or macro against a living hostile target—even when the action cannot be used because it is on cooldown or you lack mana/rage.

## Supported actions

- **Paladin:** Seal of Righteousness, Seal of the Crusader, Seal of Light, Seal of Wisdom, Seal of Justice, Seal of Command, and Judgement.
- **Warrior:** Bloodthirst, Cleave, Demoralizing Shout, Disarm, Execute, Hamstring, Heroic Strike, Intercept, Mortal Strike, Mocking Blow, Overpower, Pummel, Rend, Revenge, Shield Bash, Slam, Sunder Armor, Taunt, Thunder Clap, and Whirlwind. Intimidating Shout stops auto-attack.
- **Shaman:** Earth Shock, Flame Shock, Frost Shock, Stormstrike, and Lightning Strike.

Repeated presses do not stop auto-attack. The addon uses internal icon paths, so it works across Vanilla client languages. It is enabled by default each time you log in or reload the UI.

For the most reliable behavior, place WoW's normal **Attack** action from the General spellbook tab on any action bar. The addon will detect it once, use its true on/off state, and avoid repeated action-bar scans. Without it, the addon uses its built-in fallback behavior.

## Install

Copy the `MeleeStartAttack` folder to:

`World of Warcraft\\Interface\\AddOns\\MeleeStartAttack`

At character select, enable **Melee Start Attack** in the AddOns list.

## Commands

- `/meleeattack on` or `/msa on` — enable auto-attack triggering.
- `/meleeattack off` or `/msa off` — disable auto-attack triggering.
- `/meleeattack` or `/msa` — toggle it.
- `/meleeattack status` — display whether it is enabled and whether it is using Attack-action mode or fallback mode.
- `/meleeattack learn` or `/msa learn` — add the next action-bar ability you press. Use this for custom abilities whose icon is not listed, such as Lightning Strike if your client uses a different icon. The learned icon is saved for future logins.
- `/start_auto_attack` — start auto-attack if it is not already active; useful in macros.
- `/stop_auto_attack` — stop auto-attack if it is active; useful in macros.
