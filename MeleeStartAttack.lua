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
        ["Interface\\Icons\\Ability_ThunderClap"] = true, -- Lightning Strike (custom ability)
    },
}

-- Enabled by default on every login/reload.
local enabled = true

-- Stores learned abilities by class. An entry contains the internal icon, the
-- spell name as shown by this client, and whether it starts or stops attack.
if type(MeleeStartAttackDB) ~= "table" then
    MeleeStartAttackDB = {}
end
MeleeStartAttackDB.customAbilities = MeleeStartAttackDB.customAbilities or {}

-- Migrate entries saved by version 1.1.2. They retain their start behavior;
-- use /msa learn start to replace a legacy entry with its spell name.
if MeleeStartAttackDB.customStartIcons then
    local class, icon
    for class, icons in pairs(MeleeStartAttackDB.customStartIcons) do
        if not MeleeStartAttackDB.customAbilities[class] then
            MeleeStartAttackDB.customAbilities[class] = {}
        end
        for icon in pairs(icons) do
            table.insert(MeleeStartAttackDB.customAbilities[class], {
                icon = icon,
                spellName = "(legacy learned icon)",
                action = "start",
            })
        end
    end
    MeleeStartAttackDB.customStartIcons = nil
end

local learnAction = nil

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

-- Saved variables can be missing or partially written after an older addon
-- version. Always recreate this class table before reading or writing it.
local function GetCustomAbilities(class)
    if type(MeleeStartAttackDB) ~= "table" then
        MeleeStartAttackDB = {}
    end
    if type(MeleeStartAttackDB.customAbilities) ~= "table" then
        MeleeStartAttackDB.customAbilities = {}
    end
    if class and type(MeleeStartAttackDB.customAbilities[class]) ~= "table" then
        MeleeStartAttackDB.customAbilities[class] = {}
    end
    return class and MeleeStartAttackDB.customAbilities[class] or nil
end

local function GetLearnedAbility(texture)
    local class = PlayerClass()
    local abilities = GetCustomAbilities(class)
    local index = 1

    while abilities and abilities[index] do
        if abilities[index].icon == texture then
            return abilities[index]
        end
        index = index + 1
    end
    return nil
end

local function IsStartAttackIcon(texture)
    local ability = GetLearnedAbility(texture)
    return IconIsInList(texture, startAttackIcons)
        or (ability and ability.action == "start")
end

local function IsStopAttackIcon(texture)
    local ability = GetLearnedAbility(texture)
    return IconIsInList(texture, stopAttackIcons)
        or (ability and ability.action == "stop")
end

local function FindSpellNameByIcon(texture)
    local spellSlot = 1
    local spellName = GetSpellName(spellSlot, BOOKTYPE_SPELL)

    while spellName do
        if GetSpellTexture(spellSlot, BOOKTYPE_SPELL) == texture then
            return spellName
        end
        spellSlot = spellSlot + 1
        spellName = GetSpellName(spellSlot, BOOKTYPE_SPELL)
    end
    return nil
end

local function LearnAbility(texture, spellName)
    local class = PlayerClass()
    if not texture or not class then
        return false
    end

    spellName = spellName or FindSpellNameByIcon(texture)
    if not spellName then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff3333Melee Start Attack:|r could not identify that ability.")
        return false
    end

    local abilities = GetCustomAbilities(class)
    local action = learnAction
    local index = 1
    while abilities[index] do
        if abilities[index].icon == texture then
            abilities[index].spellName = spellName
            abilities[index].action = action
            learnAction = nil
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Melee Start Attack:|r learned " .. action .. " for " .. spellName .. ".")
            return true
        end
        index = index + 1
    end

    table.insert(abilities, {
        icon = texture,
        spellName = spellName,
        action = action,
    })
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Melee Start Attack:|r learned " .. action .. " for " .. spellName .. ".")
    learnAction = nil
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
    elseif iconLists == stopAttackIcons then
        return IsStopAttackIcon(texture)
    end
    return IconIsInList(texture, iconLists)
end

-- Macro addons, including SuperMacro, may run CastSpellByName directly instead
-- of calling UseAction. Resolve the localized name through the spellbook, then
-- match its internal (language-independent) icon.
local function FindSpellSlotByName(spellName)
    if not spellName then
        return nil
    end

    local baseName = string.gsub(spellName, "%s*%b()$", "")
    local spellSlot = 1
    local knownName = GetSpellName(spellSlot, BOOKTYPE_SPELL)

    while knownName do
        if knownName == baseName then
            return spellSlot
        end
        spellSlot = spellSlot + 1
        knownName = GetSpellName(spellSlot, BOOKTYPE_SPELL)
    end
    return nil
end

local function SpellNameHasIcon(spellName, iconLists)
    local spellSlot = FindSpellSlotByName(spellName)
    return spellSlot and SpellSlotHasIcon(spellSlot, BOOKTYPE_SPELL, iconLists)
end

-- Runs before mana, rage, or cooldown validation. Vanilla 1.12 action bars
-- expose only an icon, while macro addons may call the cast functions directly.
local originalUseAction = UseAction
UseAction = function(actionSlot, checkCursor, onSelf)
    if enabled then
        local texture = GetActionTexture(actionSlot)
        if learnAction then
            LearnAbility(texture)
        end
        if IsStopAttackIcon(texture) then
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
        if learnAction then
            LearnAbility(GetSpellTexture(spellSlot, bookType), GetSpellName(spellSlot, bookType))
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
        if learnAction then
            local spellSlot = FindSpellSlotByName(spellName)
            if spellSlot then
                LearnAbility(GetSpellTexture(spellSlot, BOOKTYPE_SPELL), GetSpellName(spellSlot, BOOKTYPE_SPELL))
            end
        end
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

local function ListLearnedAbilities()
    local class = PlayerClass()
    local abilities = GetCustomAbilities(class)
    local index = 1

    if not abilities or not abilities[index] then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Melee Start Attack:|r no learned abilities for " .. class .. ".")
        return
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Melee Start Attack learned abilities for " .. class .. ":|r")
    while abilities[index] do
        DEFAULT_CHAT_FRAME:AddMessage("  " .. abilities[index].action .. ": " .. abilities[index].spellName)
        index = index + 1
    end
end

local function UnlearnAbility(spellName)
    local class = PlayerClass()
    local abilities = GetCustomAbilities(class)
    local wantedName = string.lower(spellName or "")
    local index = 1

    while abilities and abilities[index] do
        if string.lower(abilities[index].spellName) == wantedName then
            table.remove(abilities, index)
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Melee Start Attack:|r removed " .. spellName .. ".")
            return
        end
        index = index + 1
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffff3333Melee Start Attack:|r no learned ability named " .. spellName .. ".")
end

SlashCmdList["MELEESTARTATTACK"] = function(message)
    local rawMessage = message or ""
    local command = string.lower(rawMessage)
    local _, _, unlearnName = string.find(rawMessage, "^%s*[Uu][Nn][Ll][Ee][Aa][Rr][Nn]%s+(.+)%s*$")

    if command == "on" then
        enabled = true
    elseif command == "off" then
        enabled = false
    elseif command == "toggle" or command == "" then
        enabled = not enabled
    elseif command == "status" then
        -- Do not change the current setting.
    elseif command == "learn" or command == "learn start" then
        learnAction = "start"
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Melee Start Attack:|r press the ability that should start auto-attack.")
        return
    elseif command == "learn stop" then
        learnAction = "stop"
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Melee Start Attack:|r press the ability that should stop auto-attack.")
        return
    elseif command == "list" then
        ListLearnedAbilities()
        return
    elseif unlearnName then
        UnlearnAbility(unlearnName)
        return
    elseif command == "reset" then
        local class = PlayerClass()
        MeleeStartAttackDB.customAbilities = MeleeStartAttackDB.customAbilities or {}
        MeleeStartAttackDB.customAbilities[class] = {}
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Melee Start Attack:|r removed all learned abilities for " .. PlayerClass() .. ".")
        return
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Melee Start Attack:|r /msa on, off, toggle, status, learn, list, unlearn <spell>, or reset")
        return
    end

    if command == "status" then
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
