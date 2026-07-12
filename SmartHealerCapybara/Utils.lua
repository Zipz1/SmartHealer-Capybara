local SH = SmartHealer
if not SH then return end

function SH:Trim(value)
    if not value then return "" end
    return string.gsub(value, "^%s*(.-)%s*$", "%1")
end

function SH:GetRaidSubgroupByName(playerName)
    if not playerName or not GetNumRaidMembers or GetNumRaidMembers() == 0 then return nil end
    for i = 1, GetNumRaidMembers() do
        local name, _, subgroup = GetRaidRosterInfo(i)
        if name == playerName then return subgroup end
    end
    return nil
end


function SH:ValidateFocusName(value)
    local name = self:Trim(value or "")
    if name == "" then return nil, "No player entered or targeted." end
    if string.find(name, "%s") then return nil, "Player names cannot contain spaces." end
    local length = string.len(name)
    if length < 2 or length > 24 then return nil, "Player names must be 2 to 24 characters." end
    if string.find(name, "^%d+$") then return nil, "Player names cannot contain only numbers." end
    return name
end

function SH:IsFocusName(playerName)
    local category = self:GetRegisteredCategoryName(playerName)
    return category == "focus" or category == "tanks" or category == "maintanks" or category == "offtanks"
end

-- Compatibility alias for older code.
function SH:IsTankName(playerName) return self:IsFocusName(playerName) end

function SH:GetLearnedMaxRank(spell)
    local cache = AceLibrary("SpellCache-1.0")
    return cache.data[spell] and tonumber(cache.data[spell].Rank) or 1
end
