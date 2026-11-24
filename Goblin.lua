-- Goblin: the advisor panel. Beside the trade window it advises on the trade;
-- opened from the minimap it shows how you're rated. The full layout shows the
-- game's own goblin model (NPC 7564) playing an emote that fits the mood, a
-- large verdict headline and a few short paragraphs. With the compact setting
-- on, trades get a small low-profile strip instead: no goblin, just the
-- verdict and a line or two. Either way a Details button opens the full
-- reasoning attached to the panel's right side. Escape closes it.
-- Events: none
-- SavedVariables: reads TrustyTradersDB.compact
local _, ns = ...

local GOBLIN = 7564 -- NPC ID, checked on Forever 1.60.1
-- Emote animation IDs, checked on Forever 1.60.1.
local ANIMATIONS = {Cheer = 68, Talk = 60, Exclaim = 64, Question = 65}
local TITLES = {trade = "Trusty Traders", self = "Your books"}
local FULL_WIDTH, FULL_HEIGHT, COMPACT_WIDTH = 240, 600, 260

local panel
local said -- the last GoblinSay content, kept so a layout change can redraw it

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

    panel.close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    panel.close:SetPoint("TOPRIGHT", 2, 2)

    panel.model = CreateFrame("PlayerModel", nil, panel)
    panel.model:SetSize(190, 220)
    panel.model:SetPoint("TOP", 0, -12)
    -- The model can finish loading after SetCreature returns; replay the
    -- emote then so it is not lost.
    if panel.model:HasScript("OnModelLoaded") then
        panel.model:SetScript("OnModelLoaded", function(self) self:SetAnimation(self.animation) end)
    end

    panel.title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    panel.headline = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    panel.text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    panel.text:SetJustifyV("TOP")
    panel.text:SetSpacing(3)

    panel.button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.button:SetText("Details")
    panel.button:SetScript("OnClick", function() ns.ToggleDetails(panel.details, panel) end)
end

-- True when the panel should use the compact strip: trades with the setting on.
local function compact()
    return panel.mode == "trade" and ns.db.compact
end

-- Arranges the panel for the full or compact layout and sizes it to fit.
local function layout()
    local small = compact()
    local title, headline, text, button = panel.title, panel.headline, panel.text, panel.button
    for _, region in ipairs({title, headline, text, button}) do region:ClearAllPoints() end
    panel.model:SetShown(not small)
    if small then
        title:SetPoint("TOPLEFT", 12, -10)
        headline:SetFontObject("GameFontNormalLarge")
        headline:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        text:SetFontObject("GameFontHighlightSmall")
        text:SetJustifyH("LEFT")
        text:SetWidth(COMPACT_WIDTH - 24)
        text:SetPoint("TOPLEFT", headline, "BOTTOMLEFT", 0, -6)
        button:SetSize(80, 20)
        button:SetPoint("BOTTOMRIGHT", -10, 10)
        panel:SetSize(COMPACT_WIDTH, 10 + title:GetStringHeight() + 4 + headline:GetStringHeight()
            + 6 + text:GetStringHeight() + 38)
    else
        title:SetPoint("TOP", panel.model, "BOTTOM", 0, -6)
        headline:SetFontObject("GameFontNormalHuge")
        headline:SetPoint("TOP", title, "BOTTOM", 0, -6)
        text:SetFontObject("GameFontHighlight")
        text:SetJustifyH("CENTER")
        text:SetWidth(FULL_WIDTH - 32)
        text:SetPoint("TOP", headline, "BOTTOM", 0, -12)
        button:SetSize(120, 22)
        button:SetPoint("BOTTOM", 0, 14)
        panel:SetSize(FULL_WIDTH, FULL_HEIGHT)
    end
end

-- Shows the current content in the current layout.
local function draw()
    local small = compact()
    if not small then
        local model = panel.model
        model.animation = ANIMATIONS[said.mood]
        model:SetCreature(GOBLIN)
        model:SetAnimation(model.animation)
    end
    panel.headline:SetText(said.headline)
    panel.text:SetText(table.concat(small and said.short or said.paragraphs, small and "\n" or "\n\n"))
    layout()
end

-- Shows the panel for mode: "trade" beside the trade window, or "self" in
-- the middle of the screen. GoblinSay calls for any other mode are ignored.
function ns.GoblinOpen(mode)
    if not panel then build() end
    panel.mode = mode
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

-- Redraws the open panel after a setting changes.
function ns.GoblinRefresh()
    if panel and said then draw() end
end

-- For the panel's current mode only: plays the emote for mood ("Cheer",
-- "Talk", "Exclaim" or "Question"), shows headline large and paragraphs (a
-- list of strings) with a blank line between them. short (a list of one or
-- two lines, optional) replaces the paragraphs in the compact layout.
-- details (optional, see ns.ToggleDetails) is kept for the Details button
-- and an open details window.
function ns.GoblinSay(mode, mood, headline, paragraphs, details, short)
    if not panel or panel.mode ~= mode then return end
    said = {mood = mood, headline = headline, paragraphs = paragraphs, short = short or paragraphs}
    draw()
    panel.details = details
    ns.UpdateDetails(details)
end
