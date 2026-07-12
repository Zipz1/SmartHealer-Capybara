local SH = SmartHealer
if not SH then return end

local DEFAULT_PROFILES = {
    ["Healing Touch"] = { overheal=1.20, raidMin=1, raidMax=99, focusMin=1, focusMax=99 },
    ["Regrowth"]      = { overheal=1.20, raidMin=1, raidMax=99, focusMin=1, focusMax=99 },
    ["Rejuvenation"]  = { overheal=1.20,  raidMin=1, raidMax=7,  focusMin=8, focusMax=99 },
}

local function copyDefaults(source)
    local result = {}
    for k,v in pairs(source) do result[k] = v end
    return result
end

function SH:InitializeV15Config()
    local account = self.db.account
    account.schemaVersion = 151
    account.spellProfiles = account.spellProfiles or {}
    account.registeredPlayers = account.registeredPlayers or {}
    account.categories = account.categories or {}
    account.categories["focus"] = account.categories["focus"] or { overheal = 1, categoryName = "focus" }

    -- Merge every legacy tank category into the single persistent Focus list.
    for playerName, category in pairs(account.registeredPlayers) do
        local categoryName = type(category) == "table" and category.categoryName or category
        if categoryName == "maintanks" or categoryName == "offtanks" or categoryName == "tanks" then
            account.registeredPlayers[playerName] = "focus"
        end
    end

    account.debugMode = account.debugMode or "off"
    account.debugFrame = tonumber(account.debugFrame) or 3

    for spell, defaults in pairs(DEFAULT_PROFILES) do
        local profile = account.spellProfiles[spell]
        if not profile then
            profile = copyDefaults(defaults)
            if tonumber(account.overheal) then profile.overheal = tonumber(account.overheal) end
            account.spellProfiles[spell] = profile
        else
            -- Migrate v1.5.0 Group 1/Tank fields into Focus fields.
            if profile.focusMin == nil then profile.focusMin = profile.tankMin or defaults.focusMin end
            if profile.focusMax == nil then profile.focusMax = profile.tankMax or defaults.focusMax end
            for key, value in pairs(defaults) do
                if profile[key] == nil then profile[key] = value end
            end
            profile.useFocusRules = nil
            profile.useGroup1Rules = nil
            profile.useTankRules = nil
            profile.tankMin = nil
            profile.tankMax = nil
        profile.enabled = nil
        end
    end

    -- Migrate dynamically detected Priest, Paladin, Shaman, or other profiles too.
    for spell, profile in pairs(account.spellProfiles) do
        if profile.focusMin == nil then profile.focusMin = profile.tankMin or 1 end
        if profile.focusMax == nil then profile.focusMax = profile.tankMax or 99 end
        profile.useFocusRules = nil
        profile.useGroup1Rules = nil
        profile.useTankRules = nil
        profile.tankMin = nil
        profile.tankMax = nil
        profile.enabled = nil
    end

    -- Migrate older Rejuvenation settings once.
    if not account.v151MigrationComplete then
        local r = account.spellProfiles["Rejuvenation"]
        if account.rejuvRaidMaxRank then r.raidMax = tonumber(account.rejuvRaidMaxRank) or r.raidMax end
        local function oldFloor(value, fallback)
            if value == "max" then return 99 end
            if value == "off" then return 1 end
            return tonumber(value) or fallback
        end
        r.focusMin = math.max(oldFloor(account.rejuvMTMinRank, r.focusMin), oldFloor(account.rejuvOTMinRank, r.focusMin))
        account.v151MigrationComplete = true
    end
end

function SH:GetSpellProfile(spell)
    if not self.db.account.spellProfiles then self:InitializeV15Config() end
    return self.db.account.spellProfiles[spell]
end

function SH:GetAllSpellProfiles()
    if not self.db.account.spellProfiles then self:InitializeV15Config() end
    return self.db.account.spellProfiles
end

function SH:NormalizeProfile(profile, learnedMax)
    if not profile then return end
    profile.overheal = tonumber(profile.overheal) or 1
    learnedMax = math.max(1, math.floor(tonumber(learnedMax) or 1))
    profile.raidMin = math.min(learnedMax, math.max(1, math.floor(tonumber(profile.raidMin) or 1)))
    profile.raidMax = math.min(learnedMax, math.max(profile.raidMin, math.floor(tonumber(profile.raidMax) or learnedMax)))
    profile.focusMin = math.min(learnedMax, math.max(1, math.floor(tonumber(profile.focusMin) or 1)))
    profile.focusMax = math.min(learnedMax, math.max(profile.focusMin, math.floor(tonumber(profile.focusMax) or learnedMax)))
    profile.enabled = nil -- legacy setting removed in 1.6.0
end
