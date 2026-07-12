local SH = SmartHealer
if not SH then return end

-- Build the configurable spell list from the current character's live spellbook.
-- A spell is included only when:
--   1. it is learned by this character, and
--   2. HealComm exposes rank calculations for it in HealComm.Spells.
-- This keeps the UI class-independent without relying on hand-written class lists.
function SH:GetProfileSpellList()
    local result = {}
    local seen = {}
    local hc = AceLibrary("HealComm-1.1")
    local sc = AceLibrary("SpellCache-1.0")

    local function ensureProfile(spell)
        if self.db.account.spellProfiles[spell] then return end
        local maxRank = self:GetLearnedMaxRank(spell)
        self.db.account.spellProfiles[spell] = {
            overheal = tonumber(self.db.account.overheal) or 1.20,
            raidMin = 1,
            raidMax = maxRank,
            focusMin = 1,
            focusMax = maxRank,
        }
    end

    local function add(spell)
        if not spell or spell == "" or seen[spell] then return end
        if not (hc.Spells and hc.Spells[spell]) then return end

        seen[spell] = true
        table.insert(result, spell)
        ensureProfile(spell)
    end

    -- Scan in spellbook order so the UI order matches the player's spellbook.
    local tabCount = GetNumSpellTabs and GetNumSpellTabs() or 0
    if tabCount and tabCount > 0 then
        local _, _, offset, count = GetSpellTabInfo(tabCount)
        local spellCount = (offset or 0) + (count or 0)
        for slot = 1, spellCount do
            local spellName = GetSpellName(slot, BOOKTYPE_SPELL)
            add(spellName)
        end
    end

    -- Fallback for clients where spellbook scanning is temporarily unavailable
    -- during early addon initialization. SpellCache is itself built from the
    -- learned spellbook, so this still only returns learned spells.
    if table.getn(result) == 0 and sc and sc.data then
        local fallback = {}
        for spell in pairs(sc.data) do
            if hc.Spells and hc.Spells[spell] then
                table.insert(fallback, spell)
            end
        end
        table.sort(fallback)
        for _, spell in ipairs(fallback) do add(spell) end
    end

    return result
end

-- Diagnostic helper used by /shc spells.
function SH:PrintDetectedHealingSpells()
    local spells = self:GetProfileSpellList()
    self:Print("Detected learned HealComm spells: ", table.getn(spells))
    if table.getn(spells) == 0 then
        self:Print("No learned downrankable healing spells were detected.")
        return
    end

    for _, spell in ipairs(spells) do
        self:Print("- ", spell, " (R", self:GetLearnedMaxRank(spell), ")")
    end
end
