-- Melee Start Attack - Vanilla 1.12.1 / Lua 5.0
-- Supports Paladins, Warriors, and Shamans.  It identifies spells by their
-- internal icon paths, which are shared by all localized Vanilla clients.

local startAttackIcons = {
    PALADIN = {
        ["Interface\\Icons\\Spell_Holy_SealOfRighteousness"] = true,
        ["Interface\\Icons\\Spell_Holy_HolySmite"] = true,
        ["Interface\\Icons\\Spell_Holy_HealingAura"] = true,
        ["Interface\\Icons\\Spell_Holy_RighteousnessAura"] = true,
        ["Interface\\Icons\\Spell_Holy_SealOfWrath"] = true,
        ["Interface\\Icons\\Ability_Warrior_InnerRage"] = true,
        ["Interface\\Icons\\Spell_Holy_RighteousFury"] = true,
    },
    WARRIOR = {
        ["Interface\\Icons\\Spell_Nature_BloodLust"] = true,
        ["Interface\\Icons\\Ability_Warrior_Cleave"] = true,
        ["Interface\\Icons\\Ability_Warrior_WarCry"] = true,
        ["Interface\\Icons\\Ability_Warrior_Disarm"] = true,
        ["Interface\\Icons\\INV_Sword_48"] = true,
        ["Interface\\Icons\\Ability_ShockWave"] = true,
        ["Interface\\Icons\\Ability_Rogue_Ambush"] = true,
        ["Interface\\Icons\\Ability_Rogue_Sprint"] = true,
        ["Interface\\Icons\\Ability_Warrior_SavageBlow"] = true,
        ["Interface\\Icons\\Ability_Warrior_PunishingBlow"] = true,
        ["Interface\\Icons\\Ability_MeleeDamage"] = true,
        ["Interface\\Icons\\INV_Gauntlets_04"] = true,
        ["Interface\\Icons\\Ability_Gouge"] = true,
        ["Interface\\Icons\\Ability_Warrior_Revenge"] = true,
        ["Interface\\Icons\\Ability_Warrior_ShieldBash"] = true,
        ["Interface\\Icons\\Ability_Warrior_DecisiveStrike"] = true,
        ["Interface\\Icons\\Ability_Warrior_Sunder"] = true,
        ["Interface\\Icons\\Spell_Nature_Reincarnation"] = true,
        ["Interface\\Icons\\Ability_ThunderClap"] = true,
        ["Interface\\Icons\\Ability_Whirlwind"] = true,
    },
    SHAMAN = {
        ["Interface\\Icons\\Spell_Nature_EarthShock"] = true,
        ["Interface\\Icons\\Spell_Fire_FlameShock"] = true,
        ["Interface\\Icons\\Spell_Frost_FrostShock"] = true,
        ["Interface\\Icons\\Ability_Shaman_Stormstrike"] = true,
        ["Interface\\Icons\\Ability_ThunderClap"] = true, -- Lightning Strike (OctoWoW)
    },
}

-- Enabled by default on every login/reload.
local enabled = true

-- Stores icons learned from the player's own client. This is useful for
-- custom OctoWoW abilities whose internal icon path is not documented.
MeleeStartAttackDB = MeleeStartAttackDB or {}
MeleeStartAttackDB.customStartIcons = MeleeStartAttackDB.customStartIcons or {}
local learnNextAction = false

-- The one supported exception: Intimidating Shout stops melee swings.
local stopAttackIcons = {
    WARRIOR = {
        ["Interface\\Icons\\Ability_GolemThunderClap"] = true,
    },
}

local function PlayerClass()
    local _, class = UnitClass("player")
    return class
end

local function IconIsInList(texture, iconLists)
    local class = PlayerClass()
    return texture and iconLists[class] and iconLists[class][texture] == true
end

local function IsStartAttackIcon(texture)
    local class = PlayerClass()
    local customIcons = MeleeStartAttackDB.customStartIcons[class]
    return IconIsInList(texture, startAttackIcons)
        or (texture and customIcons and customIcons[texture] == true)
end

local function LearnStartAttackIcon(texture)
    local class = PlayerClass()
    if not texture or not class then
        return false
    end

    if not MeleeStartAttackDB.customStartIcons[class] then
        MeleeStartAttackDB.customStartIcons[class] = {}
    end
    MeleeStartAttackDB.customStartIcons[class][texture] = true
    learnNextAction = false
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Melee Start Attack:|r learned " .. texture .. ".")
    return true
end

-- AttackTarget() toggles. When the normal Attack action is on an action bar,
-- use its actual state for a reliable and inexpensive start/stop check. If it
-- is absent, retain the original combat-state fallback behavior.
local attackActive = false
local attackActionSlot = nil

local function GetAttackActionSlot()
    if attackActionSlot and IsAttackAction(attackActionSlot) then
        return attackActionSlot
    end

    local actionSlot = 1
    while actionSlot <= 120 do
        if IsAttackAction(actionSlot) then
            attackActionSlot = actionSlot
            return actionSlot
        end
        actionSlot = actionSlot + 1
    end

    attackActionSlot = nil
    return nil
end

local function IsAutoAttacking()
    local attackSlot = GetAttackActionSlot()
    if attackSlot then
        return IsCurrentAction(attackSlot)
    end

    return attackActive
end

local function GetAttackModeText()
    local attackSlot = GetAttackActionSlot()
    if attackSlot then
        return "Attack-action mode (slot " .. attackSlot .. ")"
    end
    return "fallback mode (no Attack action found on an action bar)"
end

local function StartAutoAttack()
    if UnitExists("target") and not UnitIsDead("target")
       and UnitCanAttack("player", "target") and not IsAutoAttacking() then
        AttackTarget()
        attackActive = true
    end
end

local function StopAutoAttack()
    if IsAutoAttacking() then
        AttackTarget()
    end
    attackActive = false
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTER_COMBAT")
eventFrame:RegisterEvent("PLAYER_LEAVE_COMBAT")
eventFrame:SetScript("OnEvent", function()
    if event == "PLAYER_ENTER_COMBAT" then
        attackActive = true
    elseif event == "PLAYER_LEAVE_COMBAT" then
        attackActive = false
    end
end)

local function SpellSlotHasIcon(spellSlot, bookType, iconLists)
    local texture = GetSpellTexture(spellSlot, bookType)
    if iconLists == startAttackIcons then
        return IsStartAttackIcon(texture)
    end
    return IconIsInList(texture, iconLists)
end

-- Macro addons, including SuperMacro, may run CastSpellByName directly instead
-- of calling UseAction. Resolve the localized name through the spellbook, then
-- match its internal (language-independent) icon.
local function SpellNameHasIcon(spellName, iconLists)
    if not spellName then
        return false
    end

    local baseName = string.gsub(spellName, "%s*%b()$", "")
    local spellSlot = 1
    local knownName = GetSpellName(spellSlot, BOOKTYPE_SPELL)

    while knownName do
        if knownName == baseName then
            if learnNextAction and iconLists == startAttackIcons then
                LearnStartAttackIcon(GetSpellTexture(spellSlot, BOOKTYPE_SPELL))
            end
            if SpellSlotHasIcon(spellSlot, BOOKTYPE_SPELL, iconLists) then
                return true
            end
        end
        spellSlot = spellSlot + 1
        knownName = GetSpellName(spellSlot, BOOKTYPE_SPELL)
    end

    return false
end

-- Runs before mana, rage, or cooldown validation. Vanilla 1.12 action bars
-- expose only an icon, while macro addons may call the cast functions directly.
local originalUseAction = UseAction
UseAction = function(actionSlot, checkCursor, onSelf)
    if enabled then
        local texture = GetActionTexture(actionSlot)
        if learnNextAction then
            LearnStartAttackIcon(texture)
        end
        if IconIsInList(texture, stopAttackIcons) then
            StopAutoAttack()
        elseif IsStartAttackIcon(texture) then
            StartAutoAttack()
        end
    end
    return originalUseAction(actionSlot, checkCursor, onSelf)
end

local originalCastSpell = CastSpell
CastSpell = function(spellSlot, bookType)
    if enabled then
        if learnNextAction then
            LearnStartAttackIcon(GetSpellTexture(spellSlot, bookType))
        end
        if SpellSlotHasIcon(spellSlot, bookType, stopAttackIcons) then
            StopAutoAttack()
        elseif SpellSlotHasIcon(spellSlot, bookType, startAttackIcons) then
            StartAutoAttack()
        end
    end
    return originalCastSpell(spellSlot, bookType)
end

local originalCastSpellByName = CastSpellByName
CastSpellByName = function(spellName, onSelf)
    if enabled then
        if SpellNameHasIcon(spellName, stopAttackIcons) then
            StopAutoAttack()
        elseif SpellNameHasIcon(spellName, startAttackIcons) then
            StartAutoAttack()
        end
    end
    return originalCastSpellByName(spellName, onSelf)
end

SLASH_MELEESTARTATTACK1 = "/meleeattack"
SLASH_MELEESTARTATTACK2 = "/msa"
SlashCmdList["MELEESTARTATTACK"] = function(message)
    message = string.lower(message or "")

    if message == "on" then
        enabled = true
    elseif message == "off" then
        enabled = false
    elseif message == "toggle" or message == "" then
        enabled = not enabled
    elseif message == "status" then
        -- Do not change the current setting.
    elseif message == "learn" then
        learnNextAction = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Melee Start Attack:|r press the ability you want to add.")
        return
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Melee Start Attack:|r /msa on, off, toggle, status, or learn")
        return
    end

    if message == "status" then
        if enabled then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Melee Start Attack enabled:|r " .. GetAttackModeText() .. ".")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff3333Melee Start Attack disabled:|r " .. GetAttackModeText() .. ".")
        end
    elseif enabled then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Melee Start Attack enabled.|r")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff3333Melee Start Attack disabled.|r")
    end
end

SLASH_STARTAUTOATTACK1 = "/start_auto_attack"
SlashCmdList["STARTAUTOATTACK"] = StartAutoAttack

SLASH_STOPAUTOATTACK1 = "/stop_auto_attack"
SlashCmdList["STOPAUTOATTACK"] = StopAutoAttack

DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Melee Start Attack loaded.|r")
