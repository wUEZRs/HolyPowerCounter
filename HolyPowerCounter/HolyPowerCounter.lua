local AddonName, _ = ...
local HPC = LibStub("AceAddon-3.0"):NewAddon("HolyPowerCounter", "AceConsole-3.0", "AceEvent-3.0")
local _, playerClass = UnitClass("player")

-- Define the Reload Popup Dialog
StaticPopupDialogs["HPC_RELOAD_UI"] = {
    text = "HolyPowerCounter: You need to reload your UI to show the Blizzard resource bar again. Reload now?",
    button1 = "Reload UI",
    button2 = "Later",
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3, 
}

local defaults = {
    profile = {
        locked = false,
        hideBlizzBar = false,
        showOnlyInCombat = false,
        showThreshold = 0,
        popOutMax = true,
        fontSize = 80,
        fontOutline = "THICKOUTLINE",
        fontColor = {r = 1, g = 0.82, b = 0, a = 1},
        alpha = 1.0,
        strata = "MEDIUM",
        pos = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
    }
}

function HPC:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("HolyPowerCounterDB", defaults, true)
    
    -- Increase frame bounds slightly to prevent clipping if the number scales up
    self.frame = CreateFrame("Frame", "HPC_DisplayFrame", UIParent)
    
    self.textDisplay = self.frame:CreateFontString(nil, "OVERLAY")
    self.textDisplay:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
    
    self:SetupOptions()
    self:ApplySettings()
    self:HandleBlizzardBar(true)

    self:RegisterEvent("UNIT_POWER_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateDisplay")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "UpdateDisplay")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "UpdateDisplay")
    
    self:RegisterChatCommand("hp", "OpenOptions")
    self:RegisterChatCommand("holypower", "OpenOptions")
    self:RegisterChatCommand("hpc", "OpenOptions")
end

function HPC:OpenOptions()
    -- Opening Blizzard settings from a chat command causes UI taint.
    -- Instead, we open the Ace3 standalone config dialog window.
    LibStub("AceConfigDialog-3.0"):Open("HolyPowerCounter")
end

function HPC:UpdateDisplay()
    if playerClass ~= "PALADIN" then
        self.frame:Hide()
        return
    end

    local p = self.db.profile

    if p.showOnlyInCombat and not UnitAffectingCombat("player") then
        self.frame:Hide()
        return
    end

    local power = UnitPower("player", Enum.PowerType.HolyPower)
    
    if power < (p.showThreshold or 0) then
        self.frame:Hide()
        return
    end

    self.frame:Show()

    -- Make it pop out dynamically instead of using a backdrop texture
    local targetSize = p.fontSize or 80
    if power >= 5 and p.popOutMax then
        targetSize = targetSize * 1.3
    end

    local outline = p.fontOutline or "THICKOUTLINE"
    if outline == "THICKEST" then
        self.textDisplay:SetFont("Fonts\\FRIZQT__.TTF", targetSize, "THICKOUTLINE")
    else
        self.textDisplay:SetFont("Fonts\\FRIZQT__.TTF", targetSize, outline)
    end

    self.textDisplay:SetText(tostring(power))
end

function HPC:UNIT_POWER_UPDATE(event, unit, powerToken)
    if unit == "player" then
        if powerToken == "HOLY_POWER" then
            self:UpdateDisplay()
        end
    end
end

function HPC:HandleBlizzardBar(isInitialLoad)
    if self.db.profile.hideBlizzBar then
        -- Midnight 12.0 Modern Class Power Bar approach (New HUD)
        if PlayerFrame and PlayerFrame.classPowerBar then
            PlayerFrame.classPowerBar:Hide()
            PlayerFrame.classPowerBar:SetAlpha(0)
            PlayerFrame.classPowerBar:UnregisterAllEvents()
        end
        -- Legacy fallback
        if PaladinPowerBarFrame then
            PaladinPowerBarFrame:Hide()
            PaladinPowerBarFrame:SetAlpha(0)
            PaladinPowerBarFrame:UnregisterAllEvents()
        end
    elseif not isInitialLoad then
        StaticPopup_Show("HPC_RELOAD_UI")
    end
end

function HPC:ApplySettings()
    local p = self.db.profile
    
    -- Keep frame bounds wide enough for the 1.3 default font pop-out scale
    self.frame:SetSize((p.fontSize or 80) * 1.5 * 1.3, (p.fontSize or 80) * 1.5 * 1.3)
    
    if self.textDisplay then
        local outline = p.fontOutline or "THICKOUTLINE"
        if outline == "THICKEST" then
            self.textDisplay:SetShadowColor(0, 0, 0, 1)
            self.textDisplay:SetShadowOffset(4, -4)
        else
            self.textDisplay:SetShadowColor(0, 0, 0, 0)
        end
        
        local c = p.fontColor or {r = 1, g = 0.82, b = 0, a = 1}
        self.textDisplay:SetTextColor(c.r, c.g, c.b, c.a)
    end
    
    self.frame:ClearAllPoints()
    self.frame:SetPoint(p.pos.point or "CENTER", UIParent, p.pos.relativePoint or "CENTER", p.pos.x or 0, p.pos.y or 0)
    self.frame:SetAlpha(p.alpha)
    self.frame:SetFrameStrata(p.strata)
    
    if not p.locked then
        self.frame:EnableMouse(true)
        self.frame:SetMovable(true)
        self.frame:RegisterForDrag("LeftButton")
        self.frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
        self.frame:SetScript("OnDragStop", function(f)
            f:StopMovingOrSizing()
            local point, _, relPoint, x, y = f:GetPoint()
            p.pos = { point = point, relativePoint = relPoint, x = x, y = y }
        end)
    else
        self.frame:EnableMouse(false)
        self.frame:SetMovable(false)
    end
    self:UpdateDisplay()
end

function HPC:SetupOptions()
    local options = {
        name = "Holy Power Counter",
        type = "group",
        args = {
            general = {
                name = "General Settings",
                type = "group", inline = true, order = 1,
                args = {
                    lock = {
                        name = "Lock Position",
                        width = "full",
                        type = "toggle", order = 1,
                        get = function() return self.db.profile.locked end,
                        set = function(_, val) self.db.profile.locked = val; self:ApplySettings() end,
                    },
                    explanation = {
                        name = "|cFFFFD100\nMessing with the Blizzard UI may require a reload.|r",
                        type = "description",
                        fontSize = "medium",
                        width = "full", order = 2.5, 
                    },
                    hideBlizz = {
                        name = "Hide Blizzard Bar",
                        width = "full",
                        type = "toggle", order = 3,
                        get = function() return self.db.profile.hideBlizzBar end,
                        set = function(_, val) self.db.profile.hideBlizzBar = val; self:HandleBlizzardBar(false) end,
                    },
                    showInCombat = {
                        name = "Only Show In Combat",
                        width = "full",
                        type = "toggle", order = 3.2,
                        get = function() return self.db.profile.showOnlyInCombat end,
                        set = function(_, val) self.db.profile.showOnlyInCombat = val; self:UpdateDisplay() end,
                    },
                    showThreshold = {
                        name = "Show Only if >= X Power",
                        width = "full",
                        type = "select", order = 3.5,
                        values = {
                            [0] = "0",
                            [1] = "1",
                            [2] = "2",
                            [3] = "3",
                            [4] = "4",
                            [5] = "5",
                        },
                        get = function() return self.db.profile.showThreshold or 0 end,
                        set = function(_, val) self.db.profile.showThreshold = val; self:UpdateDisplay() end,
                    },
                    popOutMax = {
                        name = "Pop Out at Max Power",
                        desc = "Dynamically increases the size of the number to 130% when you reach 5 Holy Power.",
                        width = "full",
                        type = "toggle", order = 3.6,
                        get = function() return self.db.profile.popOutMax end,
                        set = function(_, val) self.db.profile.popOutMax = val; self:UpdateDisplay() end,
                    },
                    fontSize = {
                        name = "Font Size",
                        type = "range", order = 4, min = 10, max = 200, step = 1,
                        get = function() return self.db.profile.fontSize or 80 end,
                        set = function(_, val) self.db.profile.fontSize = val; self:ApplySettings() end,
                    },
                    fontOutline = {
                        name = "Border Thickness",
                        type = "select", order = 4.1,
                        values = {
                            ["NONE"] = "None",
                            ["OUTLINE"] = "Normal",
                            ["THICKOUTLINE"] = "Thick",
                            ["THICKEST"] = "Thickest (Outline + Heavy Shadow)",
                        },
                        get = function() return self.db.profile.fontOutline or "THICKOUTLINE" end,
                        set = function(_, val) self.db.profile.fontOutline = val; self:ApplySettings() end,
                    },
                    fontColor = {
                        name = "Color",
                        type = "color", hasAlpha = true, order = 4.2,
                        get = function() 
                            local c = self.db.profile.fontColor or {r = 1, g = 0.82, b = 0, a = 1}
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a) 
                            self.db.profile.fontColor = {r = r, g = g, b = b, a = a}
                            self:ApplySettings() 
                        end,
                    },
                    alpha = {
                        name = "Alpha",
                        type = "range", order = 5, min = 0, max = 1, step = 0.1,
                        get = function() return self.db.profile.alpha end,
                        set = function(_, val) self.db.profile.alpha = val; self:ApplySettings() end,
                    },
                },
            },
        },
    }

LibStub("AceConfig-3.0"):RegisterOptionsTable("HolyPowerCounter", options)
self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("HolyPowerCounter", "HolyPowerCounter")

end