-- Campfire Sit: a Sit button near campfires, a 60 s countdown while sitting.
--
-- Spell IDs and names come from fan guides of the WoW Forever beta. If the
-- button never shows, stand by a fire and run /campsit auras to see the real
-- names, then fix them here.

local ADDON = ...

local NEARBY  = { id = 1283391, name = "Campfire Nearby" }    -- you are close to a fire
local SITTING = { id = 1289723, name = "Welcoming Campfire" } -- the 60 s countdown while sitting
local BENEFIT = { id = 1229741, name = "Camp Benefits" }      -- the buff you sit for

local SIT_SECONDS = 60
local NO_AURA_GRACE = 3 -- seconds to wait for the countdown aura after clicking

local DEFAULTS = {
    locked = true,
    refreshMinutes = 15, -- show the button again when the buff has less than this left
}

local db -- CampfireSitDB once loaded

local function Print(msg) print("|cffff8c1aCampfire Sit|r: " .. msg) end

-- Aura lookup ---------------------------------------------------------------

-- Returns duration, expirationTime of a player buff, or nil if absent.
-- Tries the spell ID first, then the name, so it survives either changing.
local function FindBuff(spell)
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spell.id)
        if aura then return aura.duration, aura.expirationTime end
    end
    for i = 1, 40 do
        local name, spellId, duration, expirationTime
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not aura then break end
            name, spellId, duration, expirationTime = aura.name, aura.spellId, aura.duration, aura.expirationTime
        else
            local _
            name, _, _, _, duration, expirationTime, _, _, _, spellId = UnitBuff("player", i)
            if not name then break end
        end
        if spellId == spell.id or name == spell.name then
            return duration, expirationTime
        end
    end
end

local function Remaining(expirationTime)
    if not expirationTime or expirationTime == 0 then return math.huge end -- no expiry
    return expirationTime - GetTime()
end

-- Frames --------------------------------------------------------------------

local holder = CreateFrame("Frame", "CampfireSitFrame", UIParent)
holder:SetSize(140, 40)
holder:SetPoint("CENTER", 0, -150)
holder:SetMovable(true)
holder:SetClampedToScreen(true)

local button = CreateFrame("Button", "CampfireSitButton", holder, "UIPanelButtonTemplate")
button:SetAllPoints()
button:SetText("Sit by the fire")
button:RegisterForDrag("LeftButton")

local timer = CreateFrame("StatusBar", "CampfireSitTimer", holder)
timer:SetAllPoints()
timer:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
timer:SetStatusBarColor(1, 0.55, 0.1)
timer:SetMinMaxValues(0, SIT_SECONDS)
local timerBg = timer:CreateTexture(nil, "BACKGROUND")
timerBg:SetAllPoints()
timerBg:SetColorTexture(0, 0, 0, 0.6)
local timerText = timer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
timerText:SetPoint("CENTER")
timer:RegisterForDrag("LeftButton")
timer:EnableMouse(true)

-- Dragging works only while unlocked; the position is saved.
local function StartMove() if not db.locked then holder:StartMoving() end end
local function StopMove()
    holder:StopMovingOrSizing()
    local point, _, relPoint, x, y = holder:GetPoint()
    db.pos = { point, relPoint, x, y }
end
button:SetScript("OnDragStart", StartMove)
button:SetScript("OnDragStop", StopMove)
timer:SetScript("OnDragStart", StartMove)
timer:SetScript("OnDragStop", StopMove)

local function ApplyPosition()
    holder:ClearAllPoints()
    local pos = db.pos
    if pos then
        holder:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        holder:SetPoint("CENTER", 0, -150)
    end
end

-- State ---------------------------------------------------------------------

-- Set when the button is clicked: a local countdown runs until the server's
-- countdown aura shows up, and is dropped if it never does.
local clickedAt

local function Update()
    if not db then return end
    local now = GetTime()
    local _, sitExpires = FindBuff(SITTING)

    -- Sitting: show the countdown, prefer the aura's own expiry.
    local endsAt
    if sitExpires and sitExpires > 0 then
        endsAt = sitExpires
        clickedAt = nil
    elseif clickedAt and now - clickedAt < NO_AURA_GRACE then
        endsAt = clickedAt + SIT_SECONDS
    else
        clickedAt = nil
    end

    if endsAt then
        local left = math.max(0, endsAt - now)
        button:Hide()
        timer:SetValue(left)
        timerText:SetFormattedText("Resting... %ds", math.ceil(left))
        timer:Show()
        holder:Show()
        return
    end
    timer:Hide()

    -- Not sitting: offer the button near a fire unless the buff is still fresh.
    -- While unlocked it always shows, so it can be dragged into place.
    local nearFire = FindBuff(NEARBY) ~= nil
    local _, benefitExpires = FindBuff(BENEFIT)
    local fresh = benefitExpires and Remaining(benefitExpires) >= db.refreshMinutes * 60
    if not db.locked then
        button:SetText(nearFire and "Sit by the fire" or "Drag me")
        button:Show()
        holder:Show()
    elseif nearFire and not fresh and not UnitAffectingCombat("player") then
        button:SetText("Sit by the fire")
        button:Show()
        holder:Show()
    else
        holder:Hide()
    end
end

button:SetScript("OnClick", function()
    if not FindBuff(NEARBY) then return end -- the unlocked preview
    DoEmote("SIT")
    clickedAt = GetTime()
    Update()
end)

-- Options panel -------------------------------------------------------------

local panel = CreateFrame("Frame")
panel.name = "Campfire Sit"
panel:Hide()

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Campfire Sit")

local lockBox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
lockBox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -2, -16)
local lockLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
lockLabel:SetPoint("LEFT", lockBox, "RIGHT", 4, 0)
lockLabel:SetText("Lock button position (unlock to drag it)")

local sliderLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
sliderLabel:SetPoint("TOPLEFT", lockBox, "BOTTOMLEFT", 2, -24)
sliderLabel:SetWidth(420)
sliderLabel:SetJustifyH("LEFT")

local slider = CreateFrame("Slider", nil, panel)
slider:SetPoint("TOPLEFT", sliderLabel, "BOTTOMLEFT", 0, -12)
slider:SetSize(260, 17)
slider:SetOrientation("HORIZONTAL")
slider:SetMinMaxValues(0, 60)
slider:SetValueStep(1)
slider:SetObeyStepOnDrag(true)
slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
local sliderBg = slider:CreateTexture(nil, "BACKGROUND")
sliderBg:SetPoint("LEFT", 0, 0)
sliderBg:SetPoint("RIGHT", 0, 0)
sliderBg:SetHeight(6)
sliderBg:SetColorTexture(0.2, 0.2, 0.2, 0.9)
local sliderMin = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
sliderMin:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
sliderMin:SetText("0")
local sliderMax = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
sliderMax:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
sliderMax:SetText("60")

local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
resetButton:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -32)
resetButton:SetSize(160, 24)
resetButton:SetText("Reset position")

local function UpdateSliderLabel()
    local m = db.refreshMinutes
    if m == 0 then
        sliderLabel:SetText("Show the button again only when Camp Benefits has run out")
    else
        sliderLabel:SetFormattedText("Show the button again when Camp Benefits has less than |cffffd100%d min|r left", m)
    end
end

local function SetLocked(locked)
    db.locked = locked
    lockBox:SetChecked(locked)
    Update()
end

lockBox:SetScript("OnClick", function(self) SetLocked(self:GetChecked() and true or false) end)
slider:SetScript("OnValueChanged", function(_, value)
    db.refreshMinutes = math.floor(value + 0.5)
    UpdateSliderLabel()
    Update()
end)
resetButton:SetScript("OnClick", function()
    db.pos = nil
    ApplyPosition()
end)
panel:SetScript("OnShow", function()
    lockBox:SetChecked(db.locked)
    slider:SetValue(db.refreshMinutes)
    UpdateSliderLabel()
end)

local category
local function RegisterPanel()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

local function OpenPanel()
    if category and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        -- Called twice: the first call only opens the frame on old clients.
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end

-- Events --------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterUnitEvent("UNIT_AURA", "player")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        CampfireSitDB = CampfireSitDB or {}
        db = CampfireSitDB
        for k, v in pairs(DEFAULTS) do
            if db[k] == nil then db[k] = v end
        end
        ApplyPosition()
        RegisterPanel()
        events:UnregisterEvent("ADDON_LOADED")
    end
    Update()
end)

-- Ticks the countdown and catches the buff dropping under the refresh window.
C_Timer.NewTicker(0.2, Update)

-- Slash command --------------------------------------------------------------

SLASH_CAMPFIRESIT1 = "/campsit"
SlashCmdList.CAMPFIRESIT = function(msg)
    local cmd, arg = strtrim(msg or ""):lower():match("^(%S*)%s*(.-)$")
    if cmd == "" or cmd == "config" or cmd == "options" then
        OpenPanel()
    elseif cmd == "lock" then
        SetLocked(true)
        Print("button locked.")
    elseif cmd == "unlock" then
        SetLocked(false)
        Print("button unlocked, drag it where you want it.")
    elseif cmd == "minutes" and tonumber(arg) then
        db.refreshMinutes = math.max(0, math.min(60, math.floor(tonumber(arg))))
        Print(("button shows again when Camp Benefits has less than %d min left."):format(db.refreshMinutes))
        Update()
    elseif cmd == "reset" then
        db.pos = nil
        ApplyPosition()
        Print("position reset.")
    elseif cmd == "auras" then
        Print("your buffs")
        for i = 1, 40 do
            local name, spellId, expirationTime
            if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
                local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
                if not aura then break end
                name, spellId, expirationTime = aura.name, aura.spellId, aura.expirationTime
            else
                local _
                name, _, _, _, _, expirationTime, _, _, _, spellId = UnitBuff("player", i)
                if not name then break end
            end
            local left = Remaining(expirationTime)
            print(("  %s (id %s) %s"):format(name, tostring(spellId),
                left == math.huge and "no expiry" or ("%dm %ds left"):format(left / 60, left % 60)))
        end
    else
        Print("commands")
        print("  /campsit - open the options")
        print("  /campsit lock | unlock - lock or free the button position")
        print("  /campsit minutes <0-60> - when to show the button again")
        print("  /campsit reset - move the button back to the middle")
        print("  /campsit auras - list your buffs with spell IDs")
    end
end
