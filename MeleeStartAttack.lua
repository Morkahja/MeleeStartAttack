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

-- Keep the original lightweight Warrior Start Attack behavior. AttackTarget()
-- toggles, so check the normal Attack action first and retain combat state as
-- a fallback for players who do not put Attack on an action bar.
local attackActive = false

local function IsAutoAttacking()
    local actionSlot = 1
    while actionSlot <= 120 do
        if IsAttackAction(actionSlot) then
            if IsCurrentAction(actionSlot) then
                return true
            end
        end
        actionSlot = actionSlot + 1
    end
    return attackActive
end

local function StartAttackIfPossible()
    if UnitExists("target") and not UnitIsDead("target")
       and UnitCanAttack("player", "target") and not IsAutoAttacking() then
        AttackTarget()
        attackActive = true
    end
end

local function StopAttackIfActive()
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
            StopAttackIfActive()
        elseif IsStartAttackIcon(texture) then
            StartAttackIfPossible()
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
            StopAttackIfActive()
        elseif SpellSlotHasIcon(spellSlot, bookType, startAttackIcons) then
            StartAttackIfPossible()
        end
    end
    return originalCastSpell(spellSlot, bookType)
end

local originalCastSpellByName = CastSpellByName
CastSpellByName = function(spellName, onSelf)
    if enabled then
        if SpellNameHasIcon(spellName, stopAttackIcons) then
            StopAttackIfActive()
        elseif SpellNameHasIcon(spellName, startAttackIcons) then
            StartAttackIfPossible()
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

    if enabled then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Melee Start Attack enabled.|r")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff3333Melee Start Attack disabled.|r")
    end
end

DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Melee Start Attack loaded.|r")
