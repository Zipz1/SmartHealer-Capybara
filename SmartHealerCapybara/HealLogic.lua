local SH = SmartHealer
if not SH then return end
-- Rank calculation remains in SmartHealer:GetOptimalRank for compatibility with
-- the original hook integrations. This module owns profile policy helpers.
function SH:SetSpellProfileValue(spell, key, value)
    local profile = self:GetSpellProfile(spell)
    if not profile then return false end
    profile[key] = value
    self:NormalizeProfile(profile, self:GetLearnedMaxRank(spell))
    return true
end
