local SH = SmartHealer
if not SH then return end
local previous = SH.HandleCapybaraCommand

function SH:PrintFocusList()
    self:Print("Focus Players:")
    local names = {}
    for playerName in pairs(self.db.account.registeredPlayers or {}) do
        if self:IsFocusName(playerName) then table.insert(names, playerName) end
    end
    table.sort(names)
    if table.getn(names) == 0 then
        self:Print("- none")
    else
        for _, name in ipairs(names) do self:Print("- ", name) end
    end
end

function SH:HandleCapybaraCommand(arg)
    arg = self:Trim(arg or "")
    local _, _, command, rest = string.find(arg, "^(%S+)%s*(.-)$")
    command = string.lower(command or "")

    if command == "config" or command == "ui" then self:ToggleConfigUI(); return end
    if command == "preview" then self:PreviewDebugMessage(); return end
    if command == "version" then self:Print("SmartHealer Capybara 1.6.8"); return end
    if command == "spells" then self:PrintDetectedHealingSpells(); return end
    if command == "profiles" then
        for _, spell in ipairs(self:GetProfileSpellList()) do
            local p = self:GetSpellProfile(spell)
            self:Print(spell, ": OH ", p.overheal, " | Raid R", p.raidMin, "-", p.raidMax, " | Focus R", p.focusMin, "-", p.focusMax)
        end
        return
    end
    if command == "focus" then
        local name = self:Trim(rest)
        if name == "" and UnitExists("target") and UnitIsPlayer("target") then name = UnitName("target") or "" end
        local validName, nameError = self:ValidateFocusName(name)
        if not validName then self:Print(nameError); return end
        name = validName
        if self:IsFocusName(name) then self:Print(name, " is already a Focus player."); return end
        self.db.account.registeredPlayers[name] = "focus"
        self:Print(name, " added to Focus.")
        if self.v15Frame and self.v15Frame:IsVisible() then self:RefreshConfigUI() end
        return
    end
    if command == "cleanfocus" then
        for playerName in pairs(self.db.account.registeredPlayers or {}) do
            if self:IsFocusName(playerName) then self.db.account.registeredPlayers[playerName] = nil end
        end
        self:Print("Focus player list cleared.")
        if self.v15Frame and self.v15Frame:IsVisible() then self:RefreshConfigUI() end
        return
    end
    if command == "list" then self:PrintFocusList(); return end
    if command == "status" then
        self:Print("SmartHealer Capybara 1.6.8")
        self:Print("- HealComm: ", self:GetHealCommSpellCount() > 1 and "OK" or "ERROR", " (", self:GetHealCommSpellCount(), " spell entries)")
        self:Print("- Debug: ", string.upper(self.db.account.debugMode or "off"), " | Frame: ", tostring(self.db.account.debugFrame or 3))
        local count = 0
        for name in pairs(self.db.account.registeredPlayers or {}) do if self:IsFocusName(name) then count = count + 1 end end
        self:Print("- Focus Players: ", count)
        return
    end
    if command == "help" or command == "" then
        self:Print("SmartHealer Capybara 1.6.8")
        self:Print("/shc config   Open the configuration")
        self:Print("/shc status   Show current settings")
        self:Print("/shc focus <player>   Add a player to the Focus list")
        self:Print("/shc help   Show this help")
        self:Print("Most settings are available in /shc config.")
        return
    end
    if previous then return previous(self, arg) end
end
