-- Goblin: the advisor panel. Beside the trade window it advises on the trade;
-- opened from the minimap it shows how you're rated. The full layout puts the
-- game's own goblin model (NPC 7564) on the left, playing an emote that fits
-- the mood. On the right are a verdict badge drawn like a rubber stamp, a
-- speech bubble whose words type themselves out, and a few short lines of
-- facts. Each new verdict slams the badge down and, with sounds on, plays a
-- coin jingle or a warning horn. With the compact setting on, trades get a
-- small strip instead: no goblin or bubble, just the badge and a line or two.
-- Either way a Details button widens the panel to show the full reasoning in
-- its right half (see Details), and clicking it again collapses it. Escape
-- closes it.
-- Events: none
-- SavedVariables: reads TrustyTradersDB.compact and TrustyTradersDB.sound
local _, ns = ...

local GOBLIN = 7564 -- NPC ID, checked on Forever 1.60.1
-- Emote animation IDs; each mood picks one at random. Cheer (68), Talk,
-- Exclaim and Question checked on Forever 1.60.1.
local ANIMATIONS = {Cheer = {68, 70}, Talk = {60}, Exclaim = {64}, Point = {84}, Question = {65}, Wave = {67}}
local SOUNDS = {
    Low = SOUNDKIT.LOOT_WINDOW_COIN_SOUND,
    Moderate = SOUNDKIT.LOOT_WINDOW_COIN_SOUND,
    Elevated = SOUNDKIT.RAID_WARNING,
    High = SOUNDKIT.RAID_WARNING,
}
local TITLES = {trade = "Trusty Traders", self = "Your books"}
local CREAM = {0.98, 0.94, 0.82}
local FULL_WIDTH, COMPACT_WIDTH = 440, 260
local MODEL_WIDTH, MODEL_HEIGHT = 150, 200
local COLUMN = FULL_WIDTH - MODEL_WIDTH - 32 -- width of the badge, bubble and lines
local TYPE_SPEED, FADE = 60, 8 -- typing speed in characters per second; fade width in characters
local RETRY_DELAY, RETRIES = 0.5, 10

local panel
local said -- the last GoblinSay content, kept so a layout change can redraw it

-- Builds the verdict badge: a colored outline around a dark face, with the
-- stamp word on top and the verdict's name under it, plus the animation that
-- slams it down.
local function buildBadge()
    local badge = CreateFrame("Frame", nil, panel)
    badge.outline = badge:CreateTexture(nil, "BACKGROUND")
    badge.outline:SetAllPoints()
    local face = badge:CreateTexture(nil, "BORDER")
    face:SetPoint("TOPLEFT", 2, -2)
    face:SetPoint("BOTTOMRIGHT", -2, 2)
    face:SetColorTexture(0.08, 0.08, 0.08, 1)
    badge.word = badge:CreateFontString(nil, "ARTWORK")
    -- A font is needed before the first SetText; layout() resizes it.
    badge.word:SetFont(STANDARD_TEXT_FONT, 26, "OUTLINE")
    badge.word:SetPoint("TOP", 0, -6)
    badge.label = badge:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    badge.label:SetPoint("TOP", badge.word, "BOTTOM", 0, -2)

    badge.slam = badge:CreateAnimationGroup()
    local drop = badge.slam:CreateAnimation("Scale")
    drop:SetScaleFrom(2.2, 2.2)
    drop:SetScaleTo(1, 1)
    drop:SetDuration(0.18)
    drop:SetSmoothing("IN")
    local appear = badge.slam:CreateAnimation("Alpha")
    appear:SetFromAlpha(0)
    appear:SetToAlpha(1)
    appear:SetDuration(0.12)
    panel.badge = badge
end

-- OnUpdate for the bubble while it types: moves the fade along and stops
-- once every character is showing.
local function typing(bubble, elapsed)
    bubble.typed = bubble.typed + elapsed * TYPE_SPEED
    if bubble.typed > #bubble.text + FADE then
        bubble.words:SetAlphaGradient(1024, FADE)
        bubble:SetScript("OnUpdate", nil)
    else
        bubble.words:SetAlphaGradient(math.floor(bubble.typed), FADE)
    end
end

-- Builds the speech bubble: a cream box with a stepped tail on its left edge
-- pointing at the goblin. Its words type out by sweeping a fade across the
-- finished text, so the wrapping never shifts while it types.
local function buildBubble()
    local bubble = CreateFrame("Frame", nil, panel)
    local box = bubble:CreateTexture(nil, "BACKGROUND")
    box:SetAllPoints()
    box:SetColorTexture(unpack(CREAM))
    for i, width in ipairs({3, 6, 9, 6, 3}) do
        local step = bubble:CreateTexture(nil, "BACKGROUND")
        step:SetColorTexture(unpack(CREAM))
        step:SetSize(width, 4)
        step:SetPoint("TOPRIGHT", bubble, "TOPLEFT", 0, -6 - i * 4)
    end
    bubble.words = bubble:CreateFontString(nil, "ARTWORK")
    bubble.words:SetFont(STANDARD_TEXT_FONT, 14, "")
    bubble.words:SetTextColor(0.15, 0.1, 0.05)
    bubble.words:SetJustifyH("LEFT")
    bubble.words:SetSpacing(2)
    bubble.words:SetWidth(COLUMN - 20)
    bubble.words:SetPoint("TOPLEFT", 10, -9)
    panel.bubble = bubble
end

-- Builds the panel on first use. Named so Escape can close it.
local function build()
    panel = CreateFrame("Frame", "TrustyTradersGoblin", UIParent, "TooltipBackdropTemplate")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function() panel:StartMoving() end)
    panel:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)
    tinsert(UISpecialFrames, "TrustyTradersGoblin")
    -- Details is a child, so it would reappear with the panel; close it instead.
    panel:SetScript("OnHide", function() ns.HideDetails() end)

    -- A near-solid backing so text never sits on the busy world behind it.
    local backing = panel:CreateTexture(nil, "BACKGROUND", nil, 7)
    backing:SetPoint("TOPLEFT", 3, -3)
    backing:SetPoint("BOTTOMRIGHT", -3, 3)
    backing:SetColorTexture(0.03, 0.03, 0.03, 0.92)

    panel.close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    panel.close:SetPoint("TOPRIGHT", 2, 2)

    panel.model = CreateFrame("PlayerModel", nil, panel)
    panel.model:SetSize(MODEL_WIDTH, MODEL_HEIGHT)
    panel.model:SetPoint("TOPLEFT", 8, -22)
    -- The model can finish loading after SetCreature returns; replay the
    -- emote then so it is not lost.
    if panel.model:HasScript("OnModelLoaded") then
        panel.model:SetScript("OnModelLoaded", function(self) self:SetAnimation(self.animation) end)
    end

    panel.title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    panel.title:SetPoint("TOPLEFT", 12, -9)
    buildBadge()
    buildBubble()
    panel.text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    panel.text:SetJustifyH("LEFT")
    panel.text:SetJustifyV("TOP")
    panel.text:SetSpacing(4)

    panel.button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.button:SetText("Details")
    panel.button:SetScript("OnClick", function() ns.ToggleDetails(panel.details, panel) end)
end

-- True when the panel should use the compact strip: trades with the setting on.
local function compact()
    return panel.mode == "trade" and ns.db.compact
end

-- Arranges the panel for the full or compact layout and sizes it to fit,
-- widening it for the details half when that is open.
local function layout()
    local small = compact()
    local badge, bubble, text, button = panel.badge, panel.bubble, panel.text, panel.button
    for _, region in ipairs({badge, bubble, text, button}) do region:ClearAllPoints() end
    panel.model:SetShown(not small)
    bubble:SetShown(not small)
    local width, height
    if small then
        badge:SetSize(COMPACT_WIDTH - 20, 44)
        badge:SetPoint("TOPLEFT", 10, -24)
        badge.word:SetFont(STANDARD_TEXT_FONT, 18, "OUTLINE")
        text:SetWidth(COMPACT_WIDTH - 24)
        text:SetPoint("TOPLEFT", badge, "BOTTOMLEFT", 2, -8)
        button:SetSize(80, 20)
        button:SetPoint("BOTTOMRIGHT", panel, "BOTTOMLEFT", COMPACT_WIDTH - 10, 10)
        width, height = COMPACT_WIDTH, 24 + 44 + 8 + text:GetStringHeight() + 38
    else
        badge:SetSize(COLUMN, 56)
        badge:SetPoint("TOPLEFT", MODEL_WIDTH + 20, -24)
        badge.word:SetFont(STANDARD_TEXT_FONT, 26, "OUTLINE")
        bubble:SetSize(COLUMN, bubble.words:GetStringHeight() + 18)
        bubble:SetPoint("TOPLEFT", badge, "BOTTOMLEFT", 0, -10)
        text:SetWidth(COLUMN)
        text:SetPoint("TOPLEFT", bubble, "BOTTOMLEFT", 0, -10)
        button:SetSize(100, 22)
        button:SetPoint("BOTTOMRIGHT", panel, "BOTTOMLEFT", FULL_WIDTH - 12, 10)
        local column = 24 + 56 + 10 + bubble:GetHeight() + 10 + text:GetStringHeight() + 42
        width, height = FULL_WIDTH, math.max(22 + MODEL_HEIGHT + 12, column)
    end
    local detailsWidth, detailsHeight = ns.DetailsSize()
    if detailsWidth then
        width, height = width + detailsWidth, math.max(height, detailsHeight)
    end
    panel:SetSize(width, height)
end

-- Sets the goblin on the model and plays its emote. SetCreature shows nothing
-- when the NPC isn't in the client's creature cache yet, so while the model
-- stays empty this tries again every RETRY_DELAY seconds, up to tries more
-- times, and stops once the panel is hidden.
local function loadGoblin(model, tries)
    model:SetCreature(GOBLIN)
    model:SetAnimation(model.animation)
    if tries > 0 then
        C_Timer.After(RETRY_DELAY, function()
            if model:IsVisible() and not model:GetModelFileID() then loadGoblin(model, tries - 1) end
        end)
    end
end

-- Fills the badge for said.verdict, or said.status while there is none.
-- A verdict new to this panel slams the badge down with its sound.
local function stamp()
    local badge, verdict = panel.badge, said.verdict
    local r, g, b = ns.RGB(verdict)
    badge.outline:SetColorTexture(r, g, b)
    badge.word:SetTextColor(r, g, b)
    badge.word:SetText(verdict and ns.STAMPS[verdict] or said.status)
    badge.label:SetText(verdict == ns.UNRATED and verdict or verdict and (verdict .. " risk") or "")
    if verdict and verdict ~= panel.stamped then
        badge.slam:Play()
        if SOUNDS[verdict] and ns.db.sound then PlaySound(SOUNDS[verdict], "SFX") end
    end
    panel.stamped = verdict
end

-- Shows the current content in the current layout.
local function draw()
    local small = compact()
    if not small then
        if said.mood ~= panel.model.mood then
            local choices = ANIMATIONS[said.mood]
            panel.model.mood = said.mood
            panel.model.animation = choices[math.random(#choices)]
        end
        loadGoblin(panel.model, RETRIES)
        local bubble = panel.bubble
        if said.bubble ~= bubble.text then
            bubble.text = said.bubble
            bubble.typed = 0
            bubble.words:SetText(said.bubble)
            bubble.words:SetAlphaGradient(0, FADE)
            bubble:SetScript("OnUpdate", typing)
        end
    end
    stamp()
    panel.text:SetText(table.concat(small and said.short or said.lines, "\n"))
    layout()
end

-- Shows the panel for mode: "trade" beside the trade window, or "self" in
-- the middle of the screen. GoblinSay calls for any other mode are ignored.
function ns.GoblinOpen(mode)
    if not panel then build() end
    panel.mode = mode
    panel.stamped = nil
    panel.model.mood = nil
    panel.bubble.text = nil
    panel.title:SetText(TITLES[mode])
    panel:ClearAllPoints()
    if mode == "trade" then
        panel:SetPoint("TOPLEFT", TradeFrame, "TOPRIGHT", 4, 0)
    else
        panel:SetPoint("CENTER")
    end
    panel:Show()
end

-- Hides the panel if it is open for mode.
function ns.GoblinClose(mode)
    if panel and panel.mode == mode then panel:Hide() end
end

-- True when the panel is showing for mode.
function ns.GoblinIsOpen(mode)
    return panel ~= nil and panel:IsShown() and panel.mode == mode
end

-- Resizes the panel to fit after the details half opens or closes.
function ns.GoblinFit()
    if panel then layout() end
end

-- Redraws the open panel after a setting changes.
function ns.GoblinRefresh()
    if panel and said then draw() end
end

-- For the panel's current mode only, shows say: {mood ("Cheer", "Talk",
-- "Exclaim", "Point", "Question" or "Wave"), verdict (a verdict word, or nil
-- while there is none), status (badge text when verdict is nil), bubble (the
-- goblin's words), lines (fact lines under the bubble), short (lines for the
-- compact strip; defaults to lines)}. details (optional, see
-- ns.ToggleDetails) is kept for the Details button and an open details window.
function ns.GoblinSay(mode, say, details)
    if not panel or panel.mode ~= mode then return end
    said = say
    said.short = said.short or said.lines
    draw()
    panel.details = details
    ns.UpdateDetails(details)
end
