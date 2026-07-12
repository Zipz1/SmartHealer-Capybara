local SH = SmartHealer
if not SH then return end

function SH:PreviewDebugMessage()
    self:DebugMessage("Regrowth > Zipz > R6 > Missing 523 > Raid")
    if (self.db.account.debugMode or "off") == "verbose" then
        self:DebugMessage("Regrowth > Zipz")
        self:DebugMessage("Missing HP: 523")
        self:DebugMessage("Required Heal: 628 (x1.2)")
        self:DebugMessage("Selected: R6 (641)")
        self:DebugMessage("Healing by Rank")
        self:DebugMessage("R4=433 R5=527 R6=641* R7=786 R8=961 R9=1170")
    end
end
