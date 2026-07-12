local SH = SmartHealer
if not SH then return end

local function label(parent, text, x, y, width, justify, font)
    local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    if width then
        fs:SetWidth(width)
        fs:SetJustifyH(justify or "LEFT")
    end
    fs:SetText(text)
    return fs
end

local function edit(parent, x, y, width)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetWidth(width)
    box:SetHeight(22)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetJustifyH("CENTER")
    box:SetTextInsets(3, 3, 0, 0)
    box:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    box:SetBackdropColor(0, 0, 0, 0.85)
    box:SetBackdropBorderColor(0.55, 0.48, 0.18, 1)
    box:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    box:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    return box
end


local function addTooltip(frame, title, body)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(title or "SmartHealer", 1, 0.82, 0)
        if body and body ~= "" then GameTooltip:AddLine(body, 1, 1, 1, 1) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function rankSelector(parent, x, y, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetWidth(width or 54)
    b:SetHeight(22)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b.value = 1
    b.maxRank = 1
    function b:SetValue(value)
        value = math.floor(tonumber(value) or 1)
        if value < 1 then value = 1 end
        if value > (self.maxRank or 1) then value = self.maxRank or 1 end
        self.value = value
        self:SetText(tostring(value))
    end
    function b:GetValue() return self.value or 1 end
    function b:SetMaxRank(maxRank)
        self.maxRank = math.max(1, math.floor(tonumber(maxRank) or 1))
        self:SetValue(self.value or 1)
    end
    b:SetScript("OnClick", function() SH:OpenRankMenu(this) end)
    b:SetValue(1)
    return b
end

local function check(parent, x, y)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    c:SetWidth(22)
    c:SetHeight(22)
    return c
end

local function button(parent, text, x, y, width, fn)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetWidth(width or 90)
    b:SetHeight(22)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetText(text)
    b:SetScript("OnClick", fn)
    return b
end

function SH:CreateConfigUI()
    if self.v15Frame then return self.v15Frame end

    local f = CreateFrame("Frame", "SmartHealerV15ConfigFrame", UIParent)
    f:SetWidth(730)
    f:SetHeight(390)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -14)
    title:SetText("SmartHealer Capybara")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)

    local rankMenu = CreateFrame("Frame", "SmartHealerRankMenu", f)
    rankMenu:SetWidth(58)
    rankMenu:SetHeight(240)
    rankMenu:SetFrameStrata("TOOLTIP")
    rankMenu:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    rankMenu:SetBackdropColor(0, 0, 0, 0.96)
    rankMenu:Hide()
    rankMenu.buttons = {}
    for i = 1, 20 do
        local rb = CreateFrame("Button", nil, rankMenu, "UIPanelButtonTemplate")
        rb:SetWidth(42)
        rb:SetHeight(18)
        rb:SetPoint("TOPLEFT", rankMenu, "TOPLEFT", 8, -7 - (i - 1) * 19)
        rb.rankValue = i
        rb:SetText(tostring(i))
        rb:SetScript("OnClick", function()
            if rankMenu.owner then rankMenu.owner:SetValue(this.rankValue) end
            rankMenu:Hide()
        end)
        rankMenu.buttons[i] = rb
    end
    f.rankMenu = rankMenu

    f.tabs = {}
    f.panels = {}
    local tabNames = { "Spells", "Focus", "Debug", "About" }

    for i, name in ipairs(tabNames) do
        local tab = button(f, name, 18 + (i - 1) * 102, -42, 94, function()
            SH:ShowConfigTab(this.tabName)
        end)
        tab.tabName = name
        f.tabs[name] = tab
        local p = CreateFrame("Frame", nil, f)
        p:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -76)
        p:SetWidth(694)
        p:SetHeight(252)
        p:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        p:SetBackdropColor(0.03, 0.03, 0.03, 0.72)
        p:SetBackdropBorderColor(0.45, 0.39, 0.16, 0.9)
        p:Hide()
        f.panels[name] = p
    end

    -- Spell matrix
    local sp = f.panels.Spells
    local headers = {
        { "Spell", 12, 124, "LEFT" },
        { "Overheal", 132, 60, "CENTER" },
        { "Raid Rank Min", 200, 88, "CENTER" },
        { "Raid Rank Max", 288, 88, "CENTER" },
        { "Focus Rank Min", 376, 92, "CENTER" },
        { "Focus Rank Max", 468, 92, "CENTER" },
        { "Max Rank", 572, 62, "CENTER" },
    }
    for _, h in ipairs(headers) do label(sp, h[1], h[2], -10, h[3], h[4]) end

    local line = sp:CreateTexture(nil, "ARTWORK")
    line:SetTexture(0.55, 0.46, 0.12, 0.55)
    line:SetPoint("TOPLEFT", sp, "TOPLEFT", 10, -28)
    line:SetWidth(665)
    line:SetHeight(1)

    f.spellRows = {}

    f.applyButton = button(f, "Apply", 492, -350, 100, function() SH:ApplyConfigUI() end)
    f.closeButton = button(f, "Close", 602, -350, 100, function() f:Hide() end)

    -- Focus panel: one persistent list of priority players.
    local fp = f.panels.Focus
    label(fp, "Focus Players", 18, -18, 180, "LEFT", "GameFontNormal")
    label(fp, "Player", 18, -48, 180)
    fp.name = edit(fp, 18, -69, 190)
    button(fp, "Add", 220, -69, 110, function()
        local n = SH:Trim(fp.name:GetText())
        if n == "" and UnitExists("target") and UnitIsPlayer("target") then n = UnitName("target") or "" end
        local validName, nameError = SH:ValidateFocusName(n)
        if not validName then
            SH:Print(nameError)
            return
        end
        n = validName
        if SH:IsFocusName(n) then
            SH:Print(n, " is already a Focus player.")
            return
        end
        SH.db.account.registeredPlayers[n] = "focus"
        fp.name:SetText("")
        SH:Print(n, " added to Focus.")
        SH:RefreshConfigUI()
    end)
    button(fp, "Clean Focus", 220, -95, 110, function()
        StaticPopup_Show("SMARTHEALER_CLEAN_FOCUS")
    end)

    label(fp, "Add a typed name, or leave the field empty and target a player.", 18, -124, 320)
    label(fp, "Typed names are checked for sensible length and format.", 18, -144, 320)
    label(fp, "The client cannot verify arbitrary offline names.", 18, -162, 320)
    label(fp, "Focus Players automatically use the per-spell Focus Rank Min/Max range.", 18, -188, 320)
    label(fp, "Useful for yourself, tanks, healers, PvP flag carriers, or anyone important.", 18, -208, 320)

    local divider = fp:CreateTexture(nil, "ARTWORK")
    divider:SetTexture(0.55, 0.46, 0.12, 0.45)
    divider:SetPoint("TOPLEFT", fp, "TOPLEFT", 338, -14)
    divider:SetWidth(1)
    divider:SetHeight(220)

    fp.listHeader = label(fp, "Focus Players (0)", 354, -18, 320, "LEFT", "GameFontNormal")
    fp.listLeft = fp:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fp.listLeft:SetPoint("TOPLEFT", fp, "TOPLEFT", 354, -46)
    fp.listLeft:SetWidth(98)
    fp.listLeft:SetJustifyH("LEFT")
    fp.listLeft:SetJustifyV("TOP")
    fp.listMiddle = fp:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fp.listMiddle:SetPoint("TOPLEFT", fp, "TOPLEFT", 456, -46)
    fp.listMiddle:SetWidth(98)
    fp.listMiddle:SetJustifyH("LEFT")
    fp.listMiddle:SetJustifyV("TOP")
    fp.listRight = fp:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fp.listRight:SetPoint("TOPLEFT", fp, "TOPLEFT", 558, -46)
    fp.listRight:SetWidth(98)
    fp.listRight:SetJustifyH("LEFT")
    fp.listRight:SetJustifyV("TOP")

    StaticPopupDialogs["SMARTHEALER_CLEAN_FOCUS"] = {
        text = "Clear all Focus Players?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            for playerName in pairs(SH.db.account.registeredPlayers or {}) do
                local category = SH:GetRegisteredCategoryName(playerName)
                if category == "focus" or category == "tanks" or category == "maintanks" or category == "offtanks" then
                    SH.db.account.registeredPlayers[playerName] = nil
                end
            end
            SH:Print("Focus player list cleared.")
            SH:RefreshConfigUI()
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
    }

    -- Debug panel
    local dp = f.panels.Debug
    label(dp, "Debug Mode", 18, -18, 100)
    dp.mode = button(dp, "OFF", 105, -13, 100, function()
        local m = SH.db.account.debugMode or "off"
        if m == "off" then m = "on" elseif m == "on" then m = "verbose" else m = "off" end
        SH.db.account.debugMode = m
        if m == "off" then this:SetText("OFF") elseif m == "on" then this:SetText("STANDARD") else this:SetText("VERBOSE") end
    end)
    label(dp, "Output chat frame", 230, -18, 130)
    dp.frame = edit(dp, 350, -13, 50)
    button(dp, "Preview", 415, -13, 90, function() SH:PreviewDebugMessage() end)

    label(dp, "NORMAL output", 18, -58, 140, "LEFT", "GameFontNormal")
    label(dp, "Regrowth > Zipz > R6 > Missing 523 > Raid", 18, -78, 650)

    label(dp, "VERBOSE output", 18, -112, 140, "LEFT", "GameFontNormal")
    label(dp, "Regrowth > Zipz", 18, -132, 650)
    label(dp, "Missing HP: 523", 18, -150, 650)
    label(dp, "Required Heal: 628 (x1.2)", 18, -168, 650)
    label(dp, "Selected: R6 (641)", 18, -186, 650)
    label(dp, "Healing by Rank", 18, -210, 650)
    label(dp, "R4=433  R5=527  R6=641*  R7=786  R8=961  R9=1170", 18, -228, 650)
    label(dp, "* = selected rank", 18, -246, 650)

    -- About panel: concise two-column quick reference.
    local ap = f.panels.About

    -- Left column: healing settings.
    label(ap, "Healing Logic", 18, -18, 180, "LEFT", "GameFontNormal")
    label(ap, "Overheal", 18, -44, 220, "LEFT", "GameFontNormalSmall")
    label(ap, "Missing HP x multiplier.", 30, -62, 320)
    label(ap, "Example: 500 x 1.20 = 600 healing.", 30, -80, 320)

    label(ap, "Raid Rank Range", 18, -108, 220, "LEFT", "GameFontNormalSmall")
    label(ap, "Used for party and raid members.", 30, -126, 320)

    label(ap, "Focus Rank Range", 18, -154, 220, "LEFT", "GameFontNormalSmall")
    label(ap, "Used for Focus Players.", 30, -172, 320)

    label(ap, "Focus Players", 18, -200, 220, "LEFT", "GameFontNormalSmall")
    label(ap, "Prioritize tanks, healers, PvP carriers, or yourself.", 30, -218, 320)

    -- Right column: short debug explanation and credits.
    label(ap, "Debug Output", 362, -18, 180, "LEFT", "GameFontNormal")
    label(ap, "Standard", 362, -44, 200, "LEFT", "GameFontNormalSmall")
    label(ap, "Selected spell decision.", 374, -62, 300)

    label(ap, "Verbose", 362, -90, 200, "LEFT", "GameFontNormalSmall")
    label(ap, "Decision plus calculations.", 374, -108, 300)

    label(ap, "Credits", 362, -136, 170, "LEFT", "GameFontNormal")
    label(ap, "SmartHealer Capybara", 362, -162, 240, "LEFT", "GameFontNormalSmall")
    label(ap, "Zipz", 374, -180, 220)
    label(ap, "Based on SmartHealer", 362, -202, 300, "LEFT", "GameFontNormalSmall")
    label(ap, "Garkin, Melbaa & dsidirop", 374, -220, 250)

    f:SetScript("OnShow", function()
        SH:RefreshConfigUI()
        SH:ShowConfigTab(f.selectedTab or "Spells")
    end)
    f:Hide()
    self.v15Frame = f
    return f
end

function SH:OpenRankMenu(selector)
    local f = self:CreateConfigUI()
    local menu = f.rankMenu
    menu.owner = selector
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", selector, "BOTTOMLEFT", 0, -2)
    local maxRank = selector.maxRank or 1
    local height = 14
    for i = 1, 20 do
        local rb = menu.buttons[i]
        if i <= maxRank then
            rb:Show()
            height = 10 + i * 19
        else
            rb:Hide()
        end
    end
    menu:SetHeight(height)
    menu:Show()
end

function SH:ShowConfigTab(name)
    local f = self:CreateConfigUI()
    if not f.panels[name] then name = "Spells" end
    f.selectedTab = name

    for panelName, panel in pairs(f.panels) do
        if panelName == name then
            panel:Show()
        else
            panel:Hide()
        end
    end

    for tabName, tab in pairs(f.tabs) do
        if tabName == name then
            tab:Disable()
            if tab.LockHighlight then tab:LockHighlight() end
        else
            tab:Enable()
            if tab.UnlockHighlight then tab:UnlockHighlight() end
        end
    end

    -- About contains no editable settings, so only Close is needed there.
    if f.applyButton then
        if name == "About" then f.applyButton:Hide() else f.applyButton:Show() end
    end

    -- Refresh dynamic information whenever its tab is opened.
    if name == "Focus" or name == "Debug" then
        self:RefreshConfigUI()
        -- RefreshConfigUI rebuilds values only; restore the selected panel.
        for panelName, panel in pairs(f.panels) do
            if panelName == name then panel:Show() else panel:Hide() end
        end
    end
end

function SH:BuildSpellRows()
    local f = self:CreateConfigUI()
    local panel = f.panels.Spells
    for _, row in ipairs(f.spellRows) do row.frame:Hide() end
    f.spellRows = {}

    local spells = self:GetProfileSpellList()
    for i, spell in ipairs(spells) do
        local y = -38 - (i - 1) * 38
        local rf = CreateFrame("Frame", nil, panel)
        rf:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)
        rf:SetWidth(670)
        rf:SetHeight(32)

        local bg = rf:CreateTexture(nil, "BACKGROUND")
        if math.mod(i, 2) == 0 then bg:SetTexture(0.18, 0.16, 0.08, 0.22) else bg:SetTexture(0, 0, 0, 0.12) end
        bg:SetAllPoints(rf)

        label(rf, spell, 6, -8, 124, "LEFT", "GameFontHighlightSmall")
        local row = { frame = rf, spell = spell }
        row.overheal = edit(rf, 124, -5, 60)
        row.raidMin = rankSelector(rf, 200, -5, 68)
        row.raidMax = rankSelector(rf, 288, -5, 68)
        row.focusMin = rankSelector(rf, 380, -5, 68)
        row.focusMax = rankSelector(rf, 472, -5, 68)
        row.learned = label(rf, "-", 572, -8, 62, "CENTER", "GameFontHighlightSmall")
        addTooltip(row.overheal, "Overheal", "Required healing equals missing HP multiplied by this value. Example: 1.20 means 120%.")
        addTooltip(row.raidMin, "Raid Rank Min", "Lowest rank allowed for normal party and raid members.")
        addTooltip(row.raidMax, "Raid Rank Max", "Highest rank allowed for normal party and raid members.")
        addTooltip(row.focusMin, "Focus Rank Min", "Lowest rank allowed for Focus Players.")
        addTooltip(row.focusMax, "Focus Rank Max", "Highest rank allowed for Focus Players.")
        table.insert(f.spellRows, row)
    end
end

function SH:RefreshConfigUI()
    local f = self:CreateConfigUI()
    self:BuildSpellRows()

    for _, row in ipairs(f.spellRows) do
        local learnedMax = self:GetLearnedMaxRank(row.spell)
        local p = self:GetSpellProfile(row.spell)
        self:NormalizeProfile(p, learnedMax)
        row.overheal:SetText(tostring(p.overheal))
        row.raidMin:SetMaxRank(learnedMax)
        row.raidMax:SetMaxRank(learnedMax)
        row.focusMin:SetMaxRank(learnedMax)
        row.focusMax:SetMaxRank(learnedMax)
        row.raidMin:SetValue(p.raidMin)
        row.raidMax:SetValue(p.raidMax)
        row.focusMin:SetValue(p.focusMin)
        row.focusMax:SetValue(p.focusMax)
        row.learned:SetText("R" .. tostring(learnedMax))
    end

    local focusPlayers = {}
    for name in pairs(self.db.account.registeredPlayers or {}) do
        local c = self:GetRegisteredCategoryName(name)
        if c == "focus" or c == "tanks" or c == "maintanks" or c == "offtanks" then
            table.insert(focusPlayers, name)
        end
    end
    table.sort(focusPlayers)
    local focusPanel = f.panels.Focus
    local count = table.getn(focusPlayers)
    focusPanel.listHeader:SetText("Focus Players (" .. tostring(count) .. ")")
    local leftNames, middleNames, rightNames = {}, {}, {}
    for i, playerName in ipairs(focusPlayers) do
        if i <= 20 then
            table.insert(leftNames, playerName)
        elseif i <= 40 then
            table.insert(middleNames, playerName)
        elseif i <= 60 then
            table.insert(rightNames, playerName)
        end
    end
    focusPanel.listLeft:SetText(count > 0 and table.concat(leftNames, "\n") or "none")
    focusPanel.listMiddle:SetText(table.concat(middleNames, "\n"))
    focusPanel.listRight:SetText(table.concat(rightNames, "\n"))
    if count > 60 then
        focusPanel.listHeader:SetText("Focus Players (" .. tostring(count) .. "; first 60 shown)")
    end
    local debugMode = self.db.account.debugMode or "off"
    if debugMode == "off" then f.panels.Debug.mode:SetText("OFF") elseif debugMode == "on" then f.panels.Debug.mode:SetText("STANDARD") else f.panels.Debug.mode:SetText("VERBOSE") end
    f.panels.Debug.frame:SetText(tostring(self.db.account.debugFrame or 3))
end

function SH:ApplyConfigUI()
    local f = self:CreateConfigUI()
    for _, row in ipairs(f.spellRows) do
        local p = self:GetSpellProfile(row.spell)
        p.overheal = tonumber(row.overheal:GetText()) or p.overheal
        p.raidMin = row.raidMin:GetValue()
        p.raidMax = row.raidMax:GetValue()
        p.focusMin = row.focusMin:GetValue()
        p.focusMax = row.focusMax:GetValue()
        self:NormalizeProfile(p, self:GetLearnedMaxRank(row.spell))
    end
    local frameNumber = tonumber(f.panels.Debug.frame:GetText())
    if frameNumber then self.db.account.debugFrame = math.max(1, math.min(10, math.floor(frameNumber))) end
    self:RefreshConfigUI()
    self:Print("Configuration saved.")
end

function SH:ToggleConfigUI()
    local f = self:CreateConfigUI()
    if f:IsVisible() then f:Hide() else f:Show() end
end
