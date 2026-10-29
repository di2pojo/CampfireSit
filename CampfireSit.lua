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
local REFRESH_BELOW = 15 * 60 -- show the button again when the buff has less than this left
local NO_AURA_GRACE = 3       -- seconds to wait for the countdown aura after clicking

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

-- Shift-drag moves the frame; the position is saved.
local function StartMove() if IsShiftKeyDown() then holder:StartMoving() end end
local function StopMove()
    holder:StopMovingOrSizing()
    local point, _, relPoint, x, y = holder:GetPoint()
    CampfireSitDB.pos = { point, relPoint, x, y }
end
button:SetScript("OnDragStart", StartMove)
button:SetScript("OnDragStop", StopMove)
timer:SetScript("OnDragStart", StartMove)
timer:SetScript("OnDragStop", StopMove)

-- State ---------------------------------------------------------------------

-- Set when the button is clicked: a local countdown runs until the server's
-- countdown aura shows up, and is dropped if it never does.
local clickedAt

local function Update()
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
    local nearFire = FindBuff(NEARBY) ~= nil
    local _, benefitExpires = FindBuff(BENEFIT)
    local fresh = benefitExpires and Remaining(benefitExpires) >= REFRESH_BELOW
    if nearFire and not fresh and not UnitAffectingCombat("player") then
        button:Show()
        holder:Show()
    else
        holder:Hide()
    end
end

button:SetScript("OnClick", function()
    DoEmote("SIT")
    clickedAt = GetTime()
    Update()
end)

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
        local pos = CampfireSitDB.pos
        if pos then
            holder:ClearAllPoints()
            holder:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
        end
        events:UnregisterEvent("ADDON_LOADED")
    end
    Update()
end)

-- Ticks the countdown and catches the buff dropping under 15 minutes.
C_Timer.NewTicker(0.2, Update)

-- Slash command --------------------------------------------------------------

SLASH_CAMPFIRESIT1 = "/campsit"
SlashCmdList.CAMPFIRESIT = function(msg)
    msg = strtrim(msg or ""):lower()
    if msg == "auras" then
        print("|cffff8c1aCampfire Sit|r: your buffs")
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
    elseif msg == "reset" then
        CampfireSitDB.pos = nil
        holder:ClearAllPoints()
        holder:SetPoint("CENTER", 0, -150)
        print("|cffff8c1aCampfire Sit|r: position reset.")
    else
        print("|cffff8c1aCampfire Sit|r: shift-drag the button to move it.")
        print("  /campsit auras - list your buffs with spell IDs")
        print("  /campsit reset - move the button back to the middle")
    end
end
