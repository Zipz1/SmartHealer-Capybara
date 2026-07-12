--Original idea of this addon is based on Ogrisch's LazySpell

local MAJOR_VERSION = "SmartHealer-1.6.8-Capybara"
local MINOR_VERSION = "$Revision: 151 $"

-- This ensures the code is only executed if the libary doesn't already exist, or is a newer version
if not AceLibrary then error(MAJOR_VERSION .. " requires AceLibrary") end
if not AceLibrary:IsNewVersion(MAJOR_VERSION, MINOR_VERSION) then return end

if not AceLibrary:HasInstance("AceDB-2.0") then error(MAJOR_VERSION .. " requires AceDB-2.0") end
if not AceLibrary:HasInstance("AceHook-2.1") then error(MAJOR_VERSION .. " requires AceHook-2.1") end
if not AceLibrary:HasInstance("AceAddon-2.0") then error(MAJOR_VERSION .. " requires AceAddon-2.0") end
if not AceLibrary:HasInstance("AceConsole-2.0") then error(MAJOR_VERSION .. " requires AceConsole-2.0") end

if not AceLibrary:HasInstance("HealComm-1.1") then error(MAJOR_VERSION .. " requires HealComm-1.1") end
if not AceLibrary:HasInstance("SpellCache-1.0") then error(MAJOR_VERSION .. " requires SpellCache-1.0") end
if not AceLibrary:HasInstance("ItemBonusLib-1.0") then error(MAJOR_VERSION .. " requires ItemBonusLib-1.0") end

local _smartHealer = AceLibrary("AceAddon-2.0"):new("AceHook-2.1", "AceConsole-2.0", "AceDB-2.0")
_G.SmartHealer = _smartHealer

_smartHealer:RegisterDB("SmartHealerCapybaraDB")

_smartHealer:RegisterDefaults("account", {
    overheal = 1, -- means heal exactly the missing_hp and only that   (btw should have been called missing_hp_percentage_multiplier)

    minimumOverheal = 0.1, -- means healing only 20% of the missing_hp
    maximumOverheal = 2.2, -- means overheal the missing_hp by 120% (by healing 220% of the missing_hp)

    interpretSpellRanksAsMaxNotMin = true,

    -- Capybara Edition raid rules
    group1Priority = true,
    rejuvRaidMaxRank = 7,
    rejuvMTMinRank = "max",
    rejuvOTMinRank = "max",
    rejuvGroup1MinRank = "max",
    debugMode = "off", -- off, on, or verbose
    debugFrame = 3, -- ChatFrame number used for debug output

    categories = {
        ["maintanks"] = {
            overheal = 1.25,
            categoryName = "maintanks",
        },
        ["offtanks"] = {
            overheal = 1.20,
            categoryName = "offtanks",
        },
        ["melees"] = {
            overheal = 1.15,
            categoryName = "melees",
        },
    },

    registeredPlayers = {
        -- ["playerName"] = categoryConfig        
    },
})

local libHC = AceLibrary("HealComm-1.1")
local libIB = AceLibrary("ItemBonusLib-1.0")
local libSC = AceLibrary("SpellCache-1.0")

local _sessionOverhealingDelta = 0

local function _strtrim(input)
    return strmatch(input, '^%s*(.*%S)') or ''
end

local function IsTruthy(value)
    local type = type(value)
    if type == "boolean" then
        -- value is already a boolean  nothing to do 
        return value
    end

    if type == "string" then
        value = strlower(_strtrim(value))
        return value == "true" or value == "1" or value == "y" or value == "yes"
    end

    if type == "number" then
        return value >= 1
    end

    return nil -- invalid value gets mapped to nil which acts like falsy
end

local function IsOptionallyTruthy(value, defaultValue)
    if value == nil or value == "" then
        -- value is an optional parameter   if not specified then default to defaultValue
        return defaultValue
    end

    value = IsTruthy(value)
    if value == nil then
        return defaultValue
    end

    return value
end

local _pfUIQuickCast_OnHeal_orig
function _smartHealer:OnEnable()
    -- Keep chat prefixes short. Some chat addons treat dotted version numbers as links.
    self.title = "SmartHealer Capybara"
    self.name = "SmartHealer Capybara"
    self.version = nil
    if Clique and Clique.CastSpell then
        self:Hook(Clique, "CastSpell", "Clique_CastSpell")
    end

    if CM and CM.CastSpell then
        self:Hook(CM, "CastSpell", "CM_CastSpell")
    end

    if pfUI and pfUI.uf and pfUI.uf.ClickAction then
        self:Hook(pfUI.uf, "ClickAction", "pfUI_ClickAction")
    end

    if SlashCmdList and SlashCmdList.PFCAST then
        self:Hook(SlashCmdList, "PFCAST", "pfUI_PFCast")
    end

    if pfUIQuickCast and pfUIQuickCast.OnHeal then
        self:Hook(pfUIQuickCast, "OnHeal", "pfUIQuickCast_OnHeal") -- wires up our interceptor _smartHealer:pfUIQuickCast_OnHeal()

        _pfUIQuickCast_OnHeal_orig = self.hooks[pfUIQuickCast]["OnHeal"]
    end

    self:RegisterChatCommand({ "/heal" }, function(arg)
        self:CastHeal(arg)
    end, "SMARTHEALER")

    self:RegisterChatCommand({ "/sh_overheal" }, function(arg)
        local category, substitutionsCount1 = string.gsub(arg, "^%s*(%S+)%s+(%S+)%s*$", "%1")
        local overheal, substitutionsCount2 = string.gsub(arg, "^%s*(%S+)%s+(%S+)%s*$", "%2")

        if substitutionsCount1 == 1 then
            self:ConfigureOverhealing(category, overheal)
            return
        end

        category = nil
        overheal, substitutionsCount2 = string.gsub(arg, "^%s*(%S+)%s*$", "%1")
        if substitutionsCount2 == 1 then
            self:ConfigureOverhealing(overheal) -- set the default overhealing multiplier
            return
        end

        self:PrintCurrentConfiguration()
    end, "SMARTOVERHEALER")

    self:RegisterChatCommand({ "/sh_toggle_player_in_category" }, function(arg)
        local category, substitutionsCount1 = string.gsub(arg, "^%s*(%S+)%s+(%S+)%s*$", "%1")
        local playerName, _ = string.gsub(arg, "^%s*(%S+)%s+(%S+)%s*$", "%2")

        if substitutionsCount1 == 1 then
            self:TogglePlayerInCategory(category, playerName)
            return
        end

        self:TogglePlayerInCategory(arg) -- will get the player name from the mouseover target
    end, "SMARTHEALERTOGGLEPLAYERINCATEGORY")

    self:RegisterChatCommand({ "/sh_overheal_global_maximum" }, function(value)
        self:SetOverhealGlobalMaximum(value)
    end, "SMARTHEALEROVERHEALGLOBALMAXIMUM")

    self:RegisterChatCommand({ "/sh_overheal_global_minimum" }, function(value)
        self:SetOverhealGlobalMinimum(value)
    end, "SMARTHEALEROVERHEALGLOBALMINIMUM")

    self:RegisterChatCommand({ "/sh_overheal_increment" }, function(value)
        self:IncrementSessionOverhealDelta(value)
    end, "SMARTHEALEROVERHEALINCREMENT")

    self:RegisterChatCommand({ "/sh_overheal_decrement" }, function(value)
        self:DecrementSessionOverhealDelta(value)
    end, "SMARTHEALEROVERHEALDECREMENT")

    self:RegisterChatCommand({ "/sh_reset_all_categories" }, function()
        self:ResetAllCategoriesToDefaultOnes()
    end, "SMARTHEALERRESETALLCATEGORIES")

    self:RegisterChatCommand({ "/sh_delete_category" }, function(category)
        self:DeleteCategory(category)
    end, "SMARTHEALERDELETECATEGORY")

    self:RegisterChatCommand({ "/sh_clear_players_registry" }, function(optionalCategory)
        self:ClearRegistry(optionalCategory)
    end, "SMARTHEALERCLEARPLAYERSREGISTRY")

    self:RegisterChatCommand({ "/sh_interpret_spell_ranks_as_max_not_min" }, function(value)
        self:InterpretSpellRanksAsMaxNotMin(value)
    end, "SMARTHEALERINTERPRETSPELLRANKSASMAXNOTMIN")

    -- Capybara Edition configuration command.
    -- /shc status
    -- /shc overheal [value]
    -- /shc group1 on|off
    -- /shc rejuvmax <rank>
    -- /shc debug off|on|verbose
    -- /shc debug frame <number>
    -- /shc mt|ot <player>
    -- /shc list
    self:RegisterChatCommand({ "/shc" }, function(arg)
        self:HandleCapybaraCommand(arg)
    end, "SMARTHEALERCAPYBARA")

    if self.InitializeV15Config then self:InitializeV15Config() end
    self:MigrateRegisteredPlayers()

    self:Print("SmartHealer Capybara 1.6.8 loaded.")
    self:Print("Use /shc config to configure the addon.")
    self:Print("/shc help for commands.")
end

-------------------------------------------------------------------------------
-- Capybara Edition configuration
-------------------------------------------------------------------------------
function _smartHealer:GetHealCommSpellCount()
    local spellCount = 0
    for _ in pairs(libHC.Spells or {}) do
        spellCount = spellCount + 1
    end
    return spellCount
end

function _smartHealer:GetRegisteredCategoryName(playerName)
    local stored = self.db.account.registeredPlayers and self.db.account.registeredPlayers[playerName]
    if type(stored) == "string" then
        return stored
    end
    -- Migration compatibility for older builds that stored the whole category table.
    if type(stored) == "table" then
        return stored.categoryName
    end
    return nil
end

function _smartHealer:GetRegisteredCategoryConfig(playerName)
    local categoryName = self:GetRegisteredCategoryName(playerName)
    return categoryName and self.db.account.categories[categoryName] or nil
end

function _smartHealer:MigrateRegisteredPlayers()
    if not self.db.account.registeredPlayers then
        self.db.account.registeredPlayers = {}
        return
    end
    for playerName, stored in pairs(self.db.account.registeredPlayers) do
        local categoryName = type(stored) == "table" and stored.categoryName or stored
        if categoryName == "maintanks" or categoryName == "offtanks" or categoryName == "tanks" then
            categoryName = "focus"
        end
        self.db.account.registeredPlayers[playerName] = categoryName
    end
end

function _smartHealer:GetRegisteredPlayerCount(categoryName)
    local count = 0
    for playerName in pairs(self.db.account.registeredPlayers or {}) do
        if self:GetRegisteredCategoryName(playerName) == categoryName then
            count = count + 1
        end
    end
    return count
end

function _smartHealer:PrintCapybaraStatus()
    self:Print("SmartHealer Capybara 1.6.8")
    self:Print("- HealComm: ", self:GetHealCommSpellCount() > 1 and "OK" or "ERROR", " (", self:GetHealCommSpellCount(), " spell entries)")
    self:Print("- Overheal: ", self:GetDefaultOverhealing(), " (", math.floor(self:GetDefaultOverhealing() * 100 + 0.5), "%)")
    self:Print("- Debug: ", string.upper(self.db.account.debugMode or "off"), " | Frame: ", tostring(self.db.account.debugFrame or 3))
    self:Print("- Group 1 priority: ", self.db.account.group1Priority and "ON" or "OFF", " | Rejuvenation floor: ", tostring(self.db.account.rejuvGroup1MinRank or "max"))
    self:Print("- Other raid members Rejuvenation cap: Rank ", self.db.account.rejuvRaidMaxRank)
    self:Print("- Tanks: ", self:GetRegisteredPlayerCount("tanks"))
end

function _smartHealer:PrintFocusList()
    self:Print("Focus Players:")
    local found = false
    for playerName in pairs(self.db.account.registeredPlayers or {}) do
        local category = self:GetRegisteredCategoryName(playerName)
        if category == "focus" or category == "tanks" or category == "maintanks" or category == "offtanks" then
            self:Print("- ", playerName)
            found = true
        end
    end
    if not found then self:Print("- none") end
end

function _smartHealer:SetDebugMode(value)
    value = string.lower(_strtrim(value or ""))
    if value ~= "off" and value ~= "on" and value ~= "verbose" then
        self:Print("Usage: /shc debug off|on|verbose")
        return
    end
    self.db.account.debugMode = value
    self:Print("Debug mode set to ", string.upper(value), ". Output frame: ChatFrame", tostring(self.db.account.debugFrame or 3))
end

function _smartHealer:GetDebugChatFrame()
    local frameNumber = tonumber(self.db.account.debugFrame) or 3
    local frame = getglobal and getglobal("ChatFrame" .. tostring(frameNumber))
    if frame and frame.AddMessage then
        return frame
    end
    return DEFAULT_CHAT_FRAME
end

function _smartHealer:SetDebugFrame(value)
    value = _strtrim(value or "")
    if value == "" then
        self:Print("Debug output frame: ChatFrame", tostring(self.db.account.debugFrame or 3))
        return
    end

    local frameNumber = tonumber(value)
    if not frameNumber then
        self:Print("Usage: /shc debug frame <number>")
        return
    end

    frameNumber = math.floor(frameNumber)
    if frameNumber < 1 or frameNumber > 10 then
        self:Print("Debug frame must be between 1 and 10")
        return
    end

    local frame = getglobal and getglobal("ChatFrame" .. tostring(frameNumber))
    if not frame or not frame.AddMessage then
        self:Print("ChatFrame", tostring(frameNumber), " does not exist. Create that chat window first.")
        return
    end

    self.db.account.debugFrame = frameNumber
    self:Print("Debug output moved to ChatFrame", tostring(frameNumber))
    frame:AddMessage("|cff33ff99SmartHealer:|r Debug output is using this window.")
end

function _smartHealer:DebugMessage(message)
    local frame = self:GetDebugChatFrame()
    frame:AddMessage("|cff33ff99SmartHealer:|r " .. tostring(message))
end

function _smartHealer:GetShortSpellName(spell)
    local short = {
        ["Healing Touch"] = "HT",
        ["Regrowth"] = "Regrowth",
        ["Rejuvenation"] = "Rejuv",
        ["Lesser Heal"] = "L.Heal",
        ["Greater Heal"] = "G.Heal",
        ["Flash Heal"] = "F.Heal",
        ["Prayer of Healing"] = "PoH",
        ["Holy Light"] = "H.Light",
        ["Flash of Light"] = "FoL",
        ["Holy Shock"] = "H.Shock",
        ["Healing Wave"] = "H.Wave",
        ["Lesser Healing Wave"] = "LHW",
        ["Chain Heal"] = "Chain",
    }
    return short[spell] or spell
end

function _smartHealer:GetShortDebugReason(reason)
    reason = tostring(reason or "match")
    if string.find(reason, "focus") or string.find(reason, "Focus") then return "Focus" end
    if string.find(reason, "tank") then return "Focus" end
    if string.find(reason, "raid") then return "Raid" end
    if string.find(reason, "clear") or string.find(reason, "Clear") then return "Free" end
    return "Match"
end

function _smartHealer:DebugHeal(spell, unit, rank, missing, overheal, reason, estimates)
    local mode = self.db.account.debugMode or "off"
    if mode == "off" then return end

    local targetName = UnitName(unit) or tostring(unit)
    local profile = self:GetShortDebugReason(reason)
    if profile == "Match" then profile = "Automatic" end
    if profile == "Free" then profile = "Clearcasting" end

    local selectedHeal = nil
    if estimates then
        for i = 1, table.getn(estimates) do
            local estimate = estimates[i]
            if estimate.rank == rank then
                selectedHeal = math.floor((estimate.heal or 0) + 0.5)
                break
            end
        end
    end

    local required = math.floor(((tonumber(missing) or 0) * (tonumber(overheal) or 1)) + 0.5)
    local multiplier = tonumber(overheal) or 1
    local multiplierText = tostring(multiplier)

    self:DebugMessage(tostring(spell) .. " > " .. tostring(targetName) .. " > R" .. tostring(rank) .. " > Missing " .. tostring(missing) .. " > " .. profile)

    if mode == "verbose" then
        self:DebugMessage(tostring(spell) .. " > " .. tostring(targetName))
        self:DebugMessage("Missing HP: " .. tostring(missing))
        self:DebugMessage("Required Heal: " .. tostring(required) .. " (x" .. multiplierText .. ")")
        if selectedHeal then
            self:DebugMessage("Selected: R" .. tostring(rank) .. " (" .. tostring(selectedHeal) .. ")")
        else
            self:DebugMessage("Selected: R" .. tostring(rank))
        end
        if estimates then
            self:DebugMessage("Healing by Rank")
            local values = ""
            for i = 1, table.getn(estimates) do
                local e = estimates[i]
                if values ~= "" then values = values .. " " end
                values = values .. "R" .. tostring(e.rank) .. "=" .. tostring(math.floor(e.heal + 0.5))
                if e.selected then values = values .. "*" end
            end
            self:DebugMessage(values)
        end
    end
end

function _smartHealer:NormalizeRejuvFloor(value)
    value = string.lower(_strtrim(value or ""))
    if value == "max" then
        return "max"
    end
    if value == "off" or value == "none" then
        return 1
    end
    local rank = tonumber(value)
    if not rank then return nil end
    rank = math.floor(rank)
    if rank < 1 then rank = 1 end
    if rank > 20 then rank = 20 end
    return rank
end

function _smartHealer:GetRejuvFloorValue(configValue, learnedMaxRank)
    if configValue == "max" then
        return learnedMaxRank
    end
    local rank = tonumber(configValue) or 1
    if rank < 1 then rank = 1 end
    if rank > learnedMaxRank then rank = learnedMaxRank end
    return rank
end

function _smartHealer:SetRejuvMinimum(scope, value)
    scope = string.lower(_strtrim(scope or ""))
    local floor = self:NormalizeRejuvFloor(value)
    if not floor then
        self:Print("Usage: /shc rejuvmin tanks|mt|ot|group1 <rank|max|off>")
        return
    end

    if scope == "tanks" then
        self.db.account.rejuvMTMinRank = floor
        self.db.account.rejuvOTMinRank = floor
        self:Print("Main- and off-tank Rejuvenation floor set to ", tostring(floor))
    elseif scope == "mt" then
        self.db.account.rejuvMTMinRank = floor
        self:Print("Main-tank Rejuvenation floor set to ", tostring(floor))
    elseif scope == "ot" then
        self.db.account.rejuvOTMinRank = floor
        self:Print("Off-tank Rejuvenation floor set to ", tostring(floor))
    elseif scope == "group1" then
        self.db.account.rejuvGroup1MinRank = floor
        self:Print("Group 1 Rejuvenation floor set to ", tostring(floor))
    else
        self:Print("Usage: /shc rejuvmin tanks|mt|ot|group1 <rank|max|off>")
    end
end

function _smartHealer:HandleCapybaraCommand(arg)
    arg = _strtrim(arg or "")
    if arg == "" or string.lower(arg) == "status" then
        self:PrintCapybaraStatus()
        return
    end

    local _, _, command, value = string.find(arg, "^(%S+)%s*(.-)%s*$")
    command = command and string.lower(command) or ""
    value = _strtrim(value or "")

    if command == "config" or command == "ui" then
        self:ToggleConfigUI()
        return
    end

    if command == "overheal" then
        if value == "" then
            self:Print("Overheal: ", self:GetDefaultOverhealing(), " (", math.floor(self:GetDefaultOverhealing() * 100 + 0.5), "%)")
        else
            self:ConfigureOverhealing(value)
        end
        return
    end

    if command == "debug" then
        local _, _, debugCommand, debugValue = string.find(value, "^(%S+)%s*(.-)%s*$")
        if debugCommand and string.lower(debugCommand) == "frame" then
            self:SetDebugFrame(debugValue)
        else
            self:SetDebugMode(value)
        end
        return
    end

    if command == "group1" then
        value = string.lower(value)
        if value == "on" then
            self.db.account.group1Priority = true
            self:Print("Group 1 max-rank Rejuvenation enabled")
        elseif value == "off" then
            self.db.account.group1Priority = false
            self:Print("Group 1 max-rank Rejuvenation disabled")
        else
            self:Print("Usage: /shc group1 on|off")
        end
        return
    end

    if command == "rejuvmin" then
        local _, _, scope, floorValue = string.find(value, "^(%S+)%s+(%S+)%s*$")
        if not scope then
            self:Print("Usage: /shc rejuvmin tanks|mt|ot|group1 <rank|max|off>")
            return
        end
        self:SetRejuvMinimum(scope, floorValue)
        return
    end

    if command == "rejuvmax" then
        local rank = tonumber(value)
        if not rank then
            self:Print("Usage: /shc rejuvmax <rank>")
            return
        end
        rank = math.floor(rank)
        if rank < 1 then rank = 1 end
        if rank > 20 then rank = 20 end
        self.db.account.rejuvRaidMaxRank = rank
        self:Print("Non-priority Rejuvenation cap set to Rank ", rank)
        return
    end

    if command == "tank" or command == "mt" or command == "ot" then
        if value == "" then
            self:Print("Usage: /shc tank <player>")
            return
        end
        self:TogglePlayerInCategory("tanks", value)
        return
    end

    if command == "list" then
        self:PrintTankList()
        return
    end

    if command == "version" then
        self:Print("SmartHealer Capybara 1.6.8")
        return
    end

    self:Print("Commands: /shc config | status | overheal [value] | debug off|on|verbose | debug frame <number> | group1 on|off | rejuvmin tanks|mt|ot|group1 <rank|max|off> | rejuvmax <rank> | tank <player> | list | version")
end


-------------------------------------------------------------------------------
-- Compact in-game configuration window
-------------------------------------------------------------------------------
local function SHC_CreateLabel(parent, text, x, y)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(text)
    return label
end

local function SHC_CreateEditBox(parent, name, x, y, width)
    local edit = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
    edit:SetWidth(width or 70)
    edit:SetHeight(20)
    edit:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    edit:SetAutoFocus(false)
    edit:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    edit:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    return edit
end

function _smartHealer:CreateConfigUI()
    if self.configFrame then return self.configFrame end

    local frame = CreateFrame("Frame", "SmartHealerCapybaraConfigFrame", UIParent)
    frame:SetWidth(430)
    frame:SetHeight(440)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -16)
    title:SetText("SmartHealer Capybara")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    local group1 = CreateFrame("CheckButton", "SHCConfigGroup1Check", frame, "UICheckButtonTemplate")
    group1:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -48)
    getglobal(group1:GetName() .. "Text"):SetText("Enable Raid Group 1 Rejuvenation priority")
    frame.group1 = group1

    SHC_CreateLabel(frame, "Overheal multiplier", 24, -88)
    frame.overheal = SHC_CreateEditBox(frame, "SHCConfigOverheal", 165, -82, 65)

    SHC_CreateLabel(frame, "Other raid Rejuvenation max rank", 24, -118)
    frame.rejuvMax = SHC_CreateEditBox(frame, "SHCConfigRejuvMax", 260, -112, 50)

    SHC_CreateLabel(frame, "Group 1 Rejuvenation minimum", 24, -148)
    frame.group1Min = SHC_CreateEditBox(frame, "SHCConfigGroup1Min", 260, -142, 50)
    SHC_CreateLabel(frame, "Use rank, max, or off", 320, -148)

    SHC_CreateLabel(frame, "Main-tank Rejuvenation minimum", 24, -178)
    frame.mtMin = SHC_CreateEditBox(frame, "SHCConfigMTMin", 260, -172, 50)

    SHC_CreateLabel(frame, "Off-tank Rejuvenation minimum", 24, -208)
    frame.otMin = SHC_CreateEditBox(frame, "SHCConfigOTMin", 260, -202, 50)

    SHC_CreateLabel(frame, "Debug mode", 24, -243)
    local debugButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    debugButton:SetWidth(90)
    debugButton:SetHeight(22)
    debugButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 115, -236)
    debugButton:SetScript("OnClick", function()
        local mode = _smartHealer.db.account.debugMode or "off"
        if mode == "off" then mode = "on"
        elseif mode == "on" then mode = "verbose"
        else mode = "off" end
        _smartHealer.db.account.debugMode = mode
        this:SetText(string.upper(mode))
    end)
    frame.debugButton = debugButton

    SHC_CreateLabel(frame, "Debug chat frame", 225, -243)
    frame.debugFrame = SHC_CreateEditBox(frame, "SHCConfigDebugFrame", 345, -237, 45)

    local tankHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    tankHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -278)
    tankHeader:SetText("Persistent tank assignments")

    frame.tankName = SHC_CreateEditBox(frame, "SHCConfigTankName", 24, -296, 145)
    local mtButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    mtButton:SetWidth(85); mtButton:SetHeight(22)
    mtButton:SetPoint("LEFT", frame.tankName, "RIGHT", 10, 0)
    mtButton:SetText("Toggle MT")
    mtButton:SetScript("OnClick", function()
        local name = _strtrim(frame.tankName:GetText() or "")
        if name ~= "" then _smartHealer:TogglePlayerInCategory("maintanks", name); _smartHealer:RefreshConfigUI() end
    end)
    local otButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    otButton:SetWidth(85); otButton:SetHeight(22)
    otButton:SetPoint("LEFT", mtButton, "RIGHT", 6, 0)
    otButton:SetText("Toggle OT")
    otButton:SetScript("OnClick", function()
        local name = _strtrim(frame.tankName:GetText() or "")
        if name ~= "" then _smartHealer:TogglePlayerInCategory("offtanks", name); _smartHealer:RefreshConfigUI() end
    end)

    local list = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    list:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -330)
    list:SetWidth(380)
    list:SetJustifyH("LEFT")
    list:SetJustifyV("TOP")
    frame.tankList = list

    local apply = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    apply:SetWidth(100); apply:SetHeight(24)
    apply:SetPoint("BOTTOM", frame, "BOTTOM", -55, 18)
    apply:SetText("Apply")
    apply:SetScript("OnClick", function() _smartHealer:ApplyConfigUI() end)

    local done = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    done:SetWidth(100); done:SetHeight(24)
    done:SetPoint("BOTTOM", frame, "BOTTOM", 55, 18)
    done:SetText("Close")
    done:SetScript("OnClick", function() _smartHealer:ApplyConfigUI(); frame:Hide() end)

    frame:SetScript("OnShow", function() _smartHealer:RefreshConfigUI() end)
    frame:Hide()
    self.configFrame = frame
    return frame
end

function _smartHealer:RefreshConfigUI()
    local frame = self:CreateConfigUI()
    frame.group1:SetChecked(self.db.account.group1Priority and 1 or nil)
    frame.overheal:SetText(tostring(self.db.account.overheal or 1))
    frame.rejuvMax:SetText(tostring(self.db.account.rejuvRaidMaxRank or 7))
    frame.group1Min:SetText(tostring(self.db.account.rejuvGroup1MinRank or "max"))
    frame.mtMin:SetText(tostring(self.db.account.rejuvMTMinRank or "max"))
    frame.otMin:SetText(tostring(self.db.account.rejuvOTMinRank or "max"))
    frame.debugButton:SetText(string.upper(self.db.account.debugMode or "off"))
    frame.debugFrame:SetText(tostring(self.db.account.debugFrame or 3))

    local mts, ots = {}, {}
    for playerName in pairs(self.db.account.registeredPlayers or {}) do
        local category = self:GetRegisteredCategoryName(playerName)
        if category == "maintanks" then table.insert(mts, playerName)
        elseif category == "offtanks" then table.insert(ots, playerName) end
    end
    table.sort(mts); table.sort(ots)
    frame.tankList:SetText("MT: " .. (table.getn(mts) > 0 and table.concat(mts, ", ") or "none") .. "\nOT: " .. (table.getn(ots) > 0 and table.concat(ots, ", ") or "none"))
end

function _smartHealer:ApplyConfigUI()
    local frame = self:CreateConfigUI()
    self.db.account.group1Priority = frame.group1:GetChecked() and true or false

    local overheal = tonumber(frame.overheal:GetText())
    if overheal and overheal > 0 then self.db.account.overheal = overheal end

    local rejuvMax = tonumber(frame.rejuvMax:GetText())
    if rejuvMax then
        rejuvMax = math.floor(rejuvMax)
        if rejuvMax < 1 then rejuvMax = 1 end
        if rejuvMax > 20 then rejuvMax = 20 end
        self.db.account.rejuvRaidMaxRank = rejuvMax
    end

    local group1Min = self:NormalizeRejuvFloor(frame.group1Min:GetText())
    local mtMin = self:NormalizeRejuvFloor(frame.mtMin:GetText())
    local otMin = self:NormalizeRejuvFloor(frame.otMin:GetText())
    if group1Min then self.db.account.rejuvGroup1MinRank = group1Min end
    if mtMin then self.db.account.rejuvMTMinRank = mtMin end
    if otMin then self.db.account.rejuvOTMinRank = otMin end

    local debugFrame = tonumber(frame.debugFrame:GetText())
    if debugFrame then
        debugFrame = math.floor(debugFrame)
        if debugFrame < 1 then debugFrame = 1 end
        if debugFrame > 10 then debugFrame = 10 end
        self.db.account.debugFrame = debugFrame
    end

    self:RefreshConfigUI()
    self:Print("Configuration saved.")
end

function _smartHealer:ToggleConfigUI()
    local frame = self:CreateConfigUI()
    if frame:IsVisible() then frame:Hide() else frame:Show() end
end

-------------------------------------------------------------------------------
-- Handler function for /heal <spell_name>[, overheal_multiplier]
-------------------------------------------------------------------------------
-- Function automatically choose which rank of heal will be casted based on
-- amount of missing life.
--
-- NOTE: Argument "spellName" should be always heal and shouldn't contain rank.
-- If there is a rank, function won't scale it. It means that "Healing Wave"
-- will use rank as needed, but "Healing Wave(Rank 3)" will always cast rank 3.
-- Argument "spellName" can contain overheal multiplier information separated
-- by "," or ";" and it should be either number (1.1) or percentage (110%).
--
-- Examples:
-- _smartHealer:CastSpell("Healing Wave")			--/heal Healing Wave
-- _smartHealer:CastSpell("Healing Wave, 1.15")		--/heal Healing Wave, 1.15
-- _smartHealer:CastSpell("Healing Wave;120%")		--/heal Healing Wave;120%
-------------------------------------------------------------------------------
function _smartHealer:CastHeal(spellName)
    if not spellName or string.len(spellName) == 0 or type(spellName) ~= "string" then
        return
    end

    spellName = string.gsub(_strtrim(spellName), "%s+", " ") -- trim the spellname and then replace all space character with a single space character

    local _, _, explicitOverhealMultiplier = string.find(spellName, "[,;]%s*(.-)$") -- tries to find overheal multiplier (number after spell name, separated by "," or ";")

    local possibleExplicitOverheal
    if explicitOverhealMultiplier then
        local _, _, percent = string.find(explicitOverhealMultiplier, "(%d+)%%")
        if percent then
            possibleExplicitOverheal = tonumber(percent) / 100
        else
            possibleExplicitOverheal = tonumber(explicitOverhealMultiplier)
        end

        spellName = string.gsub(spellName, "[,;].*", "")     --removes everything after first "," or ";"
    end

    local spell, rank = libSC:GetRanklessSpellName(spellName)
    local unit, onSelf

    if UnitExists("target") and UnitCanAssist("player", "target") then
        unit = "target"
    end

    if unit == nil then
        if GetCVar("autoSelfCast") == "1" then
            unit = "player"
            onSelf = true
        else
            return
        end
    end

    if spell and rank == nil and libHC.Spells[spell] then
        rank = self:GetOptimalRank(spell, unit, possibleExplicitOverheal)
        if rank then
            spellName = libSC:GetSpellNameText(spell, rank)
        end
    elseif (self.db.account.debugMode or "off") ~= "off" then
        self:Print("[DEBUG] Spell not recognized for downranking: ", tostring(spellName))
    end


    CastSpellByName(spellName, onSelf)

    if UnitIsUnit("player", unit) then
        if SpellIsTargeting() then
            SpellTargetUnit(unit)
        end
        if SpellIsTargeting() then
            SpellStopTargeting()
        end
    end
end

function _smartHealer:getUnitIdFromMouseHoverOverPartyOrRaidMember()
    local frame = GetMouseFocus()
    if frame and frame.label and frame.id then
        return frame.label .. frame.id
    end

    return nil
end

-------------------------------------------------------------------------------------------
-- Handler function for /sh_toggle_player_in_category <category> [<optional_player_name>]
-------------------------------------------------------------------------------------------
-- PLaces the given player in the specified category (if the player is already in another
-- category he will get removed from that one).
--
-- If the player is already in the category specified then he's removed from it.
--
-- If no player name is specified, then the player that's currently being hovered over is
-- selected.
--
-------------------------------------------------------------------------------
function _smartHealer:TogglePlayerInCategory(categoryName, optionalPlayerName)
    categoryName = _strtrim(categoryName or "")
    if categoryName == "" then
        self:Print(" [ERROR] Category name not specified")
        return
    end

    local categoryConfig = self.db.account.categories[categoryName]
    if not categoryConfig then
        self:Print(" [ERROR] Category '", categoryName, "' not found")
        return
    end

    local playerName = _strtrim(optionalPlayerName or "")
    if playerName == "" then
        local mouseHoverOverUnitId = self:getUnitIdFromMouseHoverOverPartyOrRaidMember()
        if mouseHoverOverUnitId == nil then
            self:Print(" [INFO] No explicit player-name specified and no party/raid member is currently being hovered over with the mouse - nothing to do ...")
            return
        end

        playerName = UnitName(mouseHoverOverUnitId)
    end

    if not playerName or playerName == "" then
        self:Print(" [ERROR] Player not specified")
        return
    end

    local preExistingCategoryConfig = self:TryRemovePlayerFromPreExistingCategory(playerName)
    if preExistingCategoryConfig ~= nil and preExistingCategoryConfig.categoryName == categoryName then
        self:Print("[-] Removed '", playerName, "' from category '", preExistingCategoryConfig.categoryName, "'")
        return
    end

    self.db.account.registeredPlayers[playerName] = categoryName

    self:Print((preExistingCategoryConfig ~= nil and "[->] Moved" or "[+] Added"), " '", playerName, "' to category '", categoryName, "'")
end

-- utility function to remove a player from a category
function _smartHealer:TryRemovePlayerFromPreExistingCategory(playerName)
    if not playerName or playerName == "" then
        self:Print(" [ERROR] Player name not specified")
        return nil
    end

    local categoryName = self:GetRegisteredCategoryName(playerName)
    if categoryName == nil then
        return nil
    end

    self.db.account.registeredPlayers[playerName] = nil

    return self.db.account.categories[categoryName] or { categoryName = categoryName }
end

-------------------------------------------------------------------------------
-- Handler function for /sh_overheal [<category>] <overheal_multiplier>
-------------------------------------------------------------------------------
-- Sets the overheal multiplier% for the specified category of players. If only the
-- multiplier% is specified then it sets the default overheal-multiplier%.
-- If no argument is specified, it prints the current overheal multiplier%.
--
-- Examples:
--
-- /sh_overheal 1.15   -- sets the default overheal multiplier to 115%
-- /sh_overheal 115%   -- same as above
--
-- /sh_overheal maintanks 1.25   -- sets the overheal multiplier for maintanks to 115%
-- /sh_overheal maintanks 125%   -- same as above
--
-- /sh_overheal offtanks 1.15   -- sets the overheal multiplier for offtanks to 115%
-- /sh_overheal offtanks 115%   -- same as above
--
-- /sh_overheal     -- prints the current overheal multiplier for all categories
--
-------------------------------------------------------------------------------
function _smartHealer:ConfigureOverhealing(categoryName, overheal)
    if not overheal or overheal == "" then
        overheal = categoryName
        categoryName = nil -- one argument means the default multiplier, not a category name
    end

    if overheal and type(overheal) == "string" then
        overheal = _strtrim(overheal)

        local _, _, percent = string.find(overheal, "(%d+)%%")
        if percent then
            overheal = tonumber(percent) / 100
        else
            overheal = tonumber(overheal)
        end
    end

    if type(overheal) ~= "number" then
        self:Print(" [ERROR] Invalid overheal multiplier supplied (type '", type(overheal), "' is not a string-number or a number)")
        return
    end

    overheal = math.floor(overheal * 1000 + 0.5) / 1000

    categoryName = _strtrim(categoryName or "")
    if categoryName == "" then
        self.db.account.overheal = overheal
        return
    end

    self.db.account.categories[categoryName] = self.db.account.categories[categoryName] or {
        categoryName = categoryName,
        overheal = 1
    }

    self.db.account.categories[categoryName].overheal = overheal
end

local maxBuffs = 32;

function _smartHealer:GetDefaultOverhealing()
    return self.db.account.overheal + _sessionOverhealingDelta
end

function _smartHealer:GetProperOverhealingForPlayer(playerName)
    local assignedCategoryConfig = self:GetRegisteredCategoryConfig(playerName)
    if assignedCategoryConfig and assignedCategoryConfig.overheal ~= nil then
        -- self:Print(" [DEBUG] Using overheal multiplier '", overheal, "' for player '", playerName, "' from category '", assignedCategoryConfig.categoryName, "'")

        return assignedCategoryConfig.overheal + _sessionOverhealingDelta
    end

    local overheal = self:GetDefaultOverhealing()
    -- self:Print(" [DEBUG] Using default overheal multiplier '", overheal, "' for player '", playerName, "' based on the default overhealing value.")

    return overheal
end

-------------------------------------------------------------------------------
-- Handler function for /sh_overheal (without any parameters)
-------------------------------------------------------------------------------
function _smartHealer:PrintCurrentConfiguration()
    self:Print("Overheal multipliers:")
    self:Print("- default: ", self:GetDefaultOverhealing(), "(", self:GetDefaultOverhealing() * 100, "%)")
    for categoryName, _ in pairs(self.db.account.categories) do
        local playerNamesForCategory = {}
        for playerName in pairs(self.db.account.registeredPlayers) do
            if self:GetRegisteredCategoryName(playerName) == categoryName then
                table.insert(playerNamesForCategory, playerName)
            end
        end

        self:Print(
                "- category '", categoryName, "': ",
                self:GetOverhealingForCategory(categoryName), "(", self:GetOverhealingForCategory(categoryName) * 100, "%) -> ",
                table.getn(playerNamesForCategory) == 0
                        and "(no players registered)"
                        or table.concat(playerNamesForCategory, ", ")
        )
    end

    self:Print("")
    self:Print("Global overheal [min, max]: [", self.db.account.minimumOverheal, ", ", self.db.account.maximumOverheal, "]")
end

-------------------------------------------------------------------------------
-- Handler function for /sh_overheal_global_maximum <value>
-------------------------------------------------------------------------------
function _smartHealer:SetOverhealGlobalMaximum(value)
    value = tonumber(value)
    if value < 0 then
        self:Print(" [ERROR] Value must be a positive number")
        return
    end

    self.db.account.maximumOverheal = value
end

-------------------------------------------------------------------------------
-- Handler function for /sh_overheal_global_minimum <value>
-------------------------------------------------------------------------------
function _smartHealer:SetOverhealGlobalMinimum(value)
    value = tonumber(value)
    if value < 0 then
        self:Print(" [ERROR] Value must be a positive number")
        return
    end

    self.db.account.minimumOverheal = value
end

-------------------------------------------------------------------------------
-- Handler function for /sh_overheal_increment <value>
-------------------------------------------------------------------------------
function _smartHealer:IncrementSessionOverhealDelta(value)
    value = value == nil
            and 0.1
            or value

    value = tonumber(value)
    if value < 0 then
        self:Print(" [ERROR] Value must be a positive number")
        return
    end

    local newSessionOverhealingDelta = _sessionOverhealingDelta + value
    newSessionOverhealingDelta = math.abs(newSessionOverhealingDelta - 0.001) < 0.01
            and 0
            or newSessionOverhealingDelta

    if self.db.account.overheal + newSessionOverhealingDelta > self.db.account.maximumOverheal then
        self:Print(" [ERROR] Cannot exceed max-overhealing-multiplier value '", self.db.account.maximumOverheal, "'")
        return
    end

    _sessionOverhealingDelta = newSessionOverhealingDelta

    self:Print(" [INFO] Default overhealing-multiplier incremented to ", self:GetDefaultOverhealing(), " (mod: ", _sessionOverhealingDelta, ")")
end

-------------------------------------------------------------------------------
-- Handler function for /sh_overheal_decrement <value>
-------------------------------------------------------------------------------
function _smartHealer:DecrementSessionOverhealDelta(value)
    value = value == nil
            and 0.1
            or value

    value = tonumber(value)
    if value < 0 then
        self:Print(" [ERROR] Value must be a positive number")
        return
    end

    value = -1 * value

    local newSessionOverhealingDelta = _sessionOverhealingDelta + value
    newSessionOverhealingDelta = math.abs(newSessionOverhealingDelta - 0.001) < 0.01
            and 0
            or newSessionOverhealingDelta

    if self.db.account.overheal + newSessionOverhealingDelta < self.db.account.minimumOverheal then
        self:Print(" [ERROR] Cannot exceed min-overhealing-multiplier value '", self.db.account.minimumOverheal, "'")
        return
    end

    _sessionOverhealingDelta = newSessionOverhealingDelta

    self:Print(" [INFO] Default overhealing multiplier decremented to ", self:GetDefaultOverhealing(), " (mod: ", _sessionOverhealingDelta, ")")
end

-------------------------------------------------------------------------------
-- Handler function for /sh_reset_all_categories
-------------------------------------------------------------------------------
function _smartHealer:ResetAllCategoriesToDefaultOnes()
    self:ClearRegistry() -- remove all players from all categories

    self.db.account.categories = {
        ["maintanks"] = {
            overheal = 1.25,
            categoryName = "maintanks",
        },
        ["offtanks"] = {
            overheal = 1.20,
            categoryName = "offtanks",
        },
        ["melees"] = {
            overheal = 1.15,
            categoryName = "melees",
        },
    }
end

-------------------------------------------------------------------------------
-- Handler function for /sh_interpret_spell_ranks_as_max_not_min <true/false>
-------------------------------------------------------------------------------
function _smartHealer:InterpretSpellRanksAsMaxNotMin(value)
    value = IsOptionallyTruthy(value, true)
    if value == nil then
        self:Print(" [ERROR] Invalid value specified")
        return
    end

    self.db.account.interpretSpellRanksAsMaxNotMin = value
end

-------------------------------------------------------------------------------
-- Handler function for /sh_delete_category <category>
-------------------------------------------------------------------------------
function _smartHealer:DeleteCategory(category)
    category = _strtrim(category)
    if category == "" then
        self:Print(" [ERROR] Category name not specified")
        return
    end

    self.db.account.categories[category] = nil
end

-------------------------------------------------------------------------------
-- Handler function for /sh_clear_players_registry [<category>]
-------------------------------------------------------------------------------
function _smartHealer:ClearRegistry(optionalCategoryName)
    optionalCategoryName = _strtrim(optionalCategoryName or "")
    if optionalCategoryName == "" then
        self.db.account.registeredPlayers = {}
        self:Print(" [INFO] All players removed from all categories")
        return
    end

    for playerName in pairs(self.db.account.registeredPlayers) do
        if self:GetRegisteredCategoryName(playerName) == optionalCategoryName then
            self.db.account.registeredPlayers[playerName] = nil
        end
    end

    self:Print(" [INFO] All players removed from category '", optionalCategoryName, "'")
end

-------------------------------------------------------------------------------
-- Function selects optimal spell rank to cast based on unit's missing HP
-------------------------------------------------------------------------------
-- spell	                - spell name to cast ("Healing Wave")
-- unit	 	                - unitId ("player", "target", ...)
-- possibleExplicitOverheal	- overheal multiplier. If nil, then using self.db.account.overheal.
-------------------------------------------------------------------------------
function _smartHealer:GetOptimalRank(spell, unit, possibleExplicitOverheal)
    if libSC.data[spell] == nil then
        self:Print("[ERROR] Smartheal spell-registry doesn't contain spell '", spell, "'")
        return
    end

    local profile = self.GetSpellProfile and self:GetSpellProfile(spell) or nil
    local bonus, power, mod
    if TheoryCraft == nil then
        bonus = tonumber(libIB:GetBonus("HEAL")) or 0
        power, mod = libHC:GetUnitSpellPower(unit, spell)
        local buffpower, buffmod = libHC:GetBuffSpellPower()
        bonus = bonus + (buffpower or 0)
        mod = (mod or 1) * (buffmod or 1)
    end

    local missing = UnitHealthMax(unit) - UnitHealth(unit)
    local learnedMaxRank = tonumber(libSC.data[spell].Rank) or 1
    local minRank, maxRank, rangeReason = 1, learnedMaxRank, "default range"
    if self.GetSpellRankRange then
        minRank, maxRank, rangeReason = self:GetSpellRankRange(spell, unit, learnedMaxRank)
    end
    minRank = math.max(1, math.min(learnedMaxRank, tonumber(minRank) or 1))
    maxRank = math.max(minRank, math.min(learnedMaxRank, tonumber(maxRank) or learnedMaxRank))

    local rank = maxRank
    local overheal = possibleExplicitOverheal
    if overheal == nil then
        if profile and tonumber(profile.overheal) then
            overheal = tonumber(profile.overheal)
        else
            overheal = self:GetProperOverhealingForPlayer(UnitName(unit))
        end
    end

    local debugEstimates = {}
    local mana = UnitMana("player")
    for i = maxRank, minRank, -1 do
        local spellData = TheoryCraft ~= nil and TheoryCraft_GetSpellDataByName(spell, i)
        if spellData then
            if mana >= spellData.manacost then
                table.insert(debugEstimates, 1, { rank = i, heal = spellData.averagehealnocrit })
                if spellData.averagehealnocrit > (missing * overheal) then
                    rank = i
                else
                    break
                end
            else
                rank = i > 1 and i - 1 or 1
            end
        else
            if libHC.Spells[spell] and libHC.Spells[spell][i] then
                local heal = (libHC.Spells[spell][i](bonus) + (power or 0)) * (mod or 1)
                table.insert(debugEstimates, 1, { rank = i, heal = heal })
                if heal > (missing * overheal) then
                    rank = i
                else
                    break
                end
            else
                self:Print("Warning: libHC missing data for " .. spell .. " Rank " .. i)
                break
            end
        end
    end

    -- Clearcasting may use the strongest rank allowed by this spell profile.
    local index = 1
    while index <= maxBuffs do
        local bIndex = GetPlayerBuff(index, "HELPFUL")
        local icon = GetPlayerBuffTexture(bIndex)
        if icon == "Interface\\Icons\\Spell_Shadow_ManaBurn" then
            rank = maxRank
        end
        index = index + 1
    end

    if rank < minRank then rank = minRank end
    if rank > maxRank then rank = maxRank end

    for i = 1, table.getn(debugEstimates) do
        if debugEstimates[i].rank == rank then debugEstimates[i].selected = true end
    end

    local reason = (rangeReason or "profile") .. " | allowed R" .. minRank .. "-R" .. maxRank
    self:DebugHeal(spell, unit, rank, missing, overheal, reason, debugEstimates)
    return rank
end
-------------------------------------------------------------------------------
-- Support for Clique
-------------------------------------------------------------------------------
function _smartHealer:Clique_CastSpell(clique, spellName, unit)
    unit = unit or clique.unit

    if UnitExists(unit) then
        local spell, rank = libSC:GetRanklessSpellName(spellName)

        if spell and rank == nil and libHC.Spells[spell] then
            rank = self:GetOptimalRank(spellName, unit)
            if rank then
                spellName = libSC:GetSpellNameText(spell, rank)
            end
        end
    end

    self.hooks[Clique]["CastSpell"](clique, spellName, unit)
end

-------------------------------------------------------------------------------
-- Support for ClassicMouseover
-------------------------------------------------------------------------------
function _smartHealer:CM_CastSpell(cm, spellName, unit)
    if UnitExists(unit) then
        local spell, rank = libSC:GetRanklessSpellName(spellName)

        if spell and rank == nil and libHC.Spells[spell] then
            rank = self:GetOptimalRank(spellName, unit)
            if rank then
                spellName = libSC:GetSpellNameText(spell, rank)
            end
        end
    end

    self.hooks[CM]["CastSpell"](cm, spellName, unit)
end

-------------------------------------------------------------------------------
-- Support for pfUI Click-Casting
-------------------------------------------------------------------------------
function _smartHealer:pfUI_ClickAction(pfui_uf, button)
    local spellName = ""
    local key = "clickcast"

    if button == "LeftButton" then
        local unit = (this.label or "") .. (this.id or "")

        if UnitExists(unit) then
            if this.config.clickcast == "1" then
                if IsShiftKeyDown() then
                    key = key .. "_shift"
                elseif IsAltKeyDown() then
                    key = key .. "_alt"
                elseif IsControlKeyDown() then
                    key = key .. "_ctrl"
                end

                spellName = pfUI_config.unitframes[key]

                if spellName ~= "" then
                    local spell, maxDesiredRank = libSC:GetRanklessSpellName(spellName)

                    if spell and maxDesiredRank == nil and libHC.Spells[spell] then
                        local optimalRank = self:GetOptimalRank(spellName, unit)
                        if optimalRank then
                            if maxDesiredRank ~= nil then
                                -- if the user has specified a rank then consider it as the max possible rank
                                optimalRank = math.min(optimalRank, maxDesiredRank)
                            end

                            pfUI_config.unitframes[key] = libSC:GetSpellNameText(spell, optimalRank)
                        end
                    end
                end
            end
        end
    end

    self.hooks[pfUI.uf]["ClickAction"](pfui_uf, button)

    if spellName ~= "" then
        pfUI_config.unitframes[key] = spellName
    end
end

-------------------------------------------------------------------------------
-- Support for pfUI /pfcast and /pfmouse commands
-------------------------------------------------------------------------------

-- Inspired by how pfui deduces the intended target inside the implementation of /pfcast
-- Must be kept in sync with the pfui codebase   otherwise there might be cases where the
-- wrong target is assumed here thus leading to wrong healing rank calculations

-- Prepare a list of units that can be used via SpellTargetUnit
local st_units = { [1] = "player", [2] = "target", [3] = "mouseover" }
for i = 1, MAX_PARTY_MEMBERS do
    table.insert(st_units, "party" .. i)
end
for i = 1, MAX_RAID_MEMBERS do
    table.insert(st_units, "raid" .. i)
end

-- Try to find a valid (friendly) unitstring that can be used for
-- SpellTargetUnit(unit) to avoid another target switch
function _smartHealer:getUnitString(unit)
    for _, unitstr in pairs(st_units) do
        if UnitIsUnit(unit, unitstr) then
            return unitstr
        end
    end

    return nil
end

function _smartHealer:getIntendedTargetForPFCastSpell()
    local unit = "mouseover"
    if not UnitExists(unit) then
        local frame = GetMouseFocus()
        if frame.label and frame.id then
            unit = frame.label .. frame.id
        elseif UnitExists("target") then
            unit = "target"
        elseif GetCVar("autoSelfCast") == "1" then
            unit = "player"
        else
            return
        end
    end

    -- If target and mouseover are friendly units, we can't use spell target as it
    -- would cast on the target instead of the mouseover. However, if the mouseover
    -- is friendly and the target is not, we can try to obtain the best unitstring
    -- for the later SpellTargetUnit() call.
    return ((not UnitCanAssist("player", "target") and UnitCanAssist("player", unit) and self:getUnitString(unit)) or "player")
end

function _smartHealer:pfUI_PFCast(msg)
    if type(msg) ~= "string" or string.len(msg) == 0 then
        self.hooks[SlashCmdList]["PFCAST"](msg) -- fallback if the message is a func or invalid
        return
    end
    
    local spell, maxDesiredRank = libSC:GetRanklessSpellName(msg)
    if spell and maxDesiredRank == nil and libHC.Spells[spell] then
        local unitstr = self:getIntendedTargetForPFCastSpell()
        if unitstr == nil then
            return
        end

        local optimalRank = self:GetOptimalRank(msg, unitstr)
        if optimalRank then
            if maxDesiredRank ~= nil then
                -- if the user has specified a rank then consider it as the max possible rank
                optimalRank = math.min(optimalRank, maxDesiredRank)
            end

            local optimalHeal = libSC:GetSpellNameText(spell, optimalRank)
            _smartHealer.hooks[SlashCmdList]["PFCAST"](optimalHeal) -- mission accomplished
            return
        end
    end

    _smartHealer.hooks[SlashCmdList]["PFCAST"](msg) -- fallback if we can't find optimal rank
end

--------------------------------------------------------------------------------------------------------------------------------------------
-- Support for /pfquickcast:heal* family of commands - these commands are provided by the pfUI-QuickCast addon which is separate from pfUI
--------------------------------------------------------------------------------------------------------------------------------------------

local _pfGetSpellIndex = pfUI
        and pfUI.api
        and pfUI.api.libspell
        and pfUI.api.libspell.GetSpellIndex

function _smartHealer:tryGetOptimalSpell(spellNameRaw, explicitlySpecifiedRank, intendedTarget)
    if not spellNameRaw or not libHC.Spells[spellNameRaw] then
        return nil, nil, nil -- fallback if the spell doesnt exist in the spellbook because for example the player hasnt specced for it 
    end

    local optimalRank = self:GetOptimalRank(spellNameRaw, intendedTarget)
    -- print("** [_smartHealer:pfUIQuickCast_OnHeal] maxDesiredRank='" .. tostring(maxDesiredRank) .. "'")

    if not optimalRank then
        return nil, nil, nil -- fallback if we can't find optimal rank
    end

    if explicitlySpecifiedRank ~= nil then
        if self.db.account.interpretSpellRanksAsMaxNotMin == nil then
            self.db.account.interpretSpellRanksAsMaxNotMin = true -- auto-migrate the db setting for users who just updated the addon
        end

        if self.db.account.interpretSpellRanksAsMaxNotMin then
            optimalRank = math.min(optimalRank, explicitlySpecifiedRank) -- the optimalrank must not exceed the explicitly specified rank
        else
            optimalRank = math.max(optimalRank, explicitlySpecifiedRank) -- the optimalrank must not fall below the explicitly specified rank
        end
    end

    local rankedSpell = libSC:GetSpellNameText(spellNameRaw, optimalRank)

    local rankedSpellId, spellBookType = _pfGetSpellIndex(spellNameRaw, "Rank " .. optimalRank)

    return rankedSpell, rankedSpellId, spellBookType
end

--- Interceptor for the vanilla pfUIQuickCast.OnHeal()
---
--- This is where we deduce the optimal spell rank for the /pfquickcast:heal* family of commands
---
function _smartHealer:pfUIQuickCast_OnHeal(spell, spell_id, spell_book_type, proper_target, intention_is_focus_cast, is_instant_cast, future_arg1, future_arg2, future_arg3, future_arg4, future_arg5)
    local spellNameRaw, explicitlySpecifiedRank = libSC:GetRanklessSpellName(spell)

    local rankedSpell, rankedSpellId, rankedSpellBookType = self:tryGetOptimalSpell(
            spellNameRaw,
            explicitlySpecifiedRank,
            proper_target
    )

    _pfUIQuickCast_OnHeal_orig(
            rankedSpell or spell,
            rankedSpellId or spell_id,
            rankedSpellBookType or spell_book_type,
            proper_target,
            intention_is_focus_cast,
            is_instant_cast,
            future_arg1, -- just to be sure we wont miss
            future_arg2, -- out on any future arguments
            future_arg3, -- we can set explicit names for
            future_arg4, -- these when and if they will be added to the pfUIQuickCast:heal* API while
            future_arg5 --  in the meantime the addon will work just fine without the need for a new release
    )
end

SmartHealer = AceLibrary:Register(_smartHealer, MAJOR_VERSION, MINOR_VERSION) --deadlast   finally register it as a global symbol
