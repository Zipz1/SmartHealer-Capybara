local SH = SmartHealer
if not SH then return end

function SH:GetSpellRankRange(spell, unit, learnedMax)
    local profile = self:GetSpellProfile(spell)
    if not profile then return 1, learnedMax, "unconfigured spell" end
    self:NormalizeProfile(profile, learnedMax)

    local playerName = UnitName(unit)
    local isFocus = playerName and self:IsFocusName(playerName)

    if isFocus then
        return profile.focusMin, profile.focusMax, "focus rules"
    end
    return profile.raidMin, profile.raidMax, "raid rules"
end
