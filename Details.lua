-- Details: the goblin's full reasoning, shown as the right half of the goblin
-- panel, which widens to hold it, so the two are one window. A header shows
-- the name, the verdict and a risk meter; tabs below hold the Verdict
-- reasoning, the game's Income and Spending counters with bars showing where
-- gold came from and went, How it works: one sub-tab per verdict level
-- with the math, a worked example and the current player's own numbers, and
-- Settings. The tabs hang below the panel's bottom edge. The panel's X and
-- Escape close the whole window; the Details button collapses this half.
-- Events: none
-- SavedVariables: TrustyTradersDB.compact, .sound and .inspect (Settings tab)
local _, ns = ...

local WIDTH, HEIGHT = 420, 600
local INNER = WIDTH - 48            -- usable width inside the side margins
local BODY_TOP = -168               -- where tab content starts, below the header
local ROW_HEIGHT = 28
local ROWS = 9                      -- enough rows for the longest stats tab
local SECTIONS = 6                  -- enough sections for the longest Verdict tab
local COIN = "|TInterface\\MoneyFrame\\UI-%sIcon:12:12:2:0|t"
local TABS = {"Verdict", "Income", "Spending", "How it works", "Settings"}
local LEVEL_TABS = {"Low", "Moderate", "Elevated", "High", ns.UNRATED}
local FORMULA = "Unexplained = most gold ever owned - total gold acquired\nShare = unexplained x 100 / most gold ever owned, rounded down\nYour own verdict, the one your goblin sends, also subtracts gold mailed from your alts first."
local EXAMPLE_PEAK = 10000000 -- 1,000g in copper
local EXAMPLE_SHARES = {Low = 10, Moderate = 35, Elevated = 60, High = 90}
local MOOD_WORDS = {Cheer = "cheers", Talk = "talks it over", Exclaim = "shouts a warning",
    Point = "points and shouts", Question = "scratches his head"}
local UNRATED_SECTIONS = {
    {"When it happens", "Peak gold is under 5g, the game won't share the counters, the player can't be inspected (too far away, in combat, or the achievement comparison is open), or no reply comes within 10 seconds."},
    {"The math", "None. Without both counters, or with under 5g of peak gold, a share would mislead, so I don't guess."},
    {"What gets saved", "Unrated never replaces a verdict saved from an earlier trade."},
    {"What the goblin does", "He scratches his head, stamps it ???, and tells you why. If they offer gold anyway, he warns you, louder the more they offer."},
}
local NOTES = {
    Income = "Bars show each source's share of total gold acquired. Gold from player trades, gifts and mail isn't recorded here.",
    Spending = "Bars compare the four kinds of spending. Auctions posted and purchases are counts, not gold.",
}
-- Rows that get a bar, and what the bar is measured against.
local BARS = {
    Income = {keys = {looted = true, quests = true, vendors = true, auctions = true, other = true}, base = "acquired"},
    Spending = {keys = {travel = true, postage = true, barber = true, respec = true}},
}

local window
local shown   -- details being displayed: {name, result, sections, stats}
local current = 1
local level = "Low" -- selected How it works sub-tab

-- Formats copper with Blizzard's coin icons, e.g. "1,500 [gold]".
local function coins(copper)
    local gold, silver = math.floor(copper / 10000), math.floor(copper / 100) % 100
    if gold > 0 or copper == 0 then return ns.Count(gold) .. " " .. COIN:format("Gold") end
    if silver > 0 then return silver .. " " .. COIN:format("Silver") .. " " .. copper % 100 .. " " .. COIN:format("Copper") end
    return copper .. " " .. COIN:format("Copper")
end

-- Builds a stats tab's rows: {label, value text or nil, bar share 0-1 or nil}.
local function statRows(tab, stats)
    local rows, bars = {}, BARS[tab]
    local values = setmetatable({}, {__index = stats})
    values.other = stats.acquired
    for _, key in ipairs({"looted", "quests", "vendors", "auctions"}) do
        values.other = values.other and stats[key] and values.other - stats[key]
    end
    values.other = values.other and math.max(0, values.other)
    local list = {}
    for _, stat in ipairs(ns.STATS[tab]) do list[#list + 1] = stat end
    if tab == "Income" then table.insert(list, 7, {"other", nil, "Other recorded income", true}) end
    local base = bars.base and values[bars.base]
    if not bars.base then
        base = 0
        for key in pairs(bars.keys) do base = math.max(base, values[key] or 0) end
    end
    for _, stat in ipairs(list) do
        local value = values[stat[1]]
        local share = bars.keys[stat[1]] and value and base and base > 0 and math.min(1, value / base) or nil
        rows[#rows + 1] = {stat[3], value and (stat[4] and coins(value) or ns.Count(value)), share}
    end
    return rows
end

-- A level's share range on the scale: low, high (high is nil for the top).
local function range(index)
    local nextLevel = ns.LEVELS[index + 1]
    return ns.LEVELS[index][2], nextLevel and nextLevel[2] - 1
end

-- Sections explaining how name (a verdict level) is reached, with a worked
-- example and the math redone on the displayed player's numbers.
local function levelSections(name)
    if name == ns.UNRATED then return UNRATED_SECTIONS end
    local low, high = range(ns.LevelIndex(name))
    local share = EXAMPLE_SHARES[name]
    local unexplained = EXAMPLE_PEAK * share / 100
    local example = "Most gold ever owned 1,000g, total gold acquired " .. ns.Gold(EXAMPLE_PEAK - unexplained) .. "\n"
        .. "Unexplained = 1,000g - " .. ns.Gold(EXAMPLE_PEAK - unexplained) .. " = " .. ns.Gold(unexplained) .. "\n"
        .. "Share = " .. ns.Count(unexplained / 10000) .. " x 100 / 1,000 = " .. share .. "%, so " .. ns.Colored(name)
    local whose, result = shown.whose or "their", shown.result
    local applied
    if result and result.percent then
        local from = math.ceil(result.peak * low / 100)
        local to = high and math.ceil(result.peak * (high + 1) / 100) - 1
        applied = (whose == "your" and "Your" or "Their") .. " share is " .. result.percent .. "%, so this level "
            .. (result.verdict == name and "is the one that applies." or "doesn't apply.") .. "\n"
            .. "With " .. ns.Gold(result.peak) .. " of peak gold, " .. name .. " means " .. ns.Gold(from)
            .. (to and (" to " .. ns.Gold(to)) or " or more") .. " unexplained."
    else
        applied = "Once a player is rated, I'll work this level out with their numbers."
    end
    return {
        {"The math", FORMULA},
        {ns.Colored(name) .. " range", "A share of " .. low .. (high and ("% to " .. high .. "%") or "% or more")
            .. " of peak gold unexplained, with at least 5g of peak gold."},
        {"Worked example", example},
        {"With " .. whose .. " numbers", applied},
        {"What the goblin does", "He " .. MOOD_WORDS[ns.Mood(name)] .. " and stamps it " .. ns.STAMPS[name]
            .. ", with lines like: \"" .. ns.QUIPS[name][1] .. "\""},
    }
end

-- Fills the header: name, verdict and the risk meter's marker.
local function renderHeader()
    local result = shown.result or {verdict = ns.UNRATED}
    local r, g, b = ns.RGB(result.verdict)
    window.band:SetColorTexture(r, g, b, 0.18)
    window.name:SetText(shown.name or "")
    window.verdict:SetText(ns.Colored(result.verdict))
    if result.percent then
        window.marker:ClearAllPoints()
        window.marker:SetPoint("CENTER", window.meter, "LEFT", INNER * math.min(result.percent, 100) / 100, 0)
        window.marker:Show()
        window.meterText:SetText(result.percent .. "% of peak gold unexplained")
    else
        window.marker:Hide()
        window.meterText:SetText(result.reason or "Not rated yet")
    end
end

-- Stacks sections ({{heading, text}, ...}) from top: heading, text, divider.
local function renderSections(sections, top)
    local y = top
    for i, section in ipairs(window.sections) do
        local data = sections and sections[i]
        section.heading:SetShown(data ~= nil)
        section.body:SetShown(data ~= nil)
        section.rule:SetShown(data ~= nil and i > 1)
        if data then
            section.rule:SetPoint("TOPLEFT", 24, y + 8)
            section.heading:SetPoint("TOPLEFT", 24, y)
            section.heading:SetText(data[1])
            section.body:SetPoint("TOPLEFT", 24, y - 18)
            section.body:SetText(data[2])
            y = y - 18 - section.body:GetStringHeight() - 18
        end
    end
end

-- Shows the selected tab's content.
local function render()
    PanelTemplates_SetTab(window, current)
    renderHeader()
    local tab, stats = TABS[current], shown.stats
    for i, button in ipairs(window.levels) do
        button:SetShown(tab == "How it works")
        if LEVEL_TABS[i] == level then button:LockHighlight() else button:UnlockHighlight() end
    end
    if current == 1 then renderSections(shown.sections, BODY_TOP)
    elseif tab == "How it works" then renderSections(levelSections(level), BODY_TOP - 38)
    else renderSections(nil) end
    window.settings:SetShown(tab == "Settings")
    window.compact:SetChecked(ns.db.compact)
    window.sound:SetChecked(ns.db.sound)
    window.inspect:SetChecked(ns.db.inspect)
    for _, row in ipairs(window.rows) do row:Hide() end
    window.note:SetText("")
    window.empty:SetShown(BARS[tab] ~= nil and not stats)
    if not BARS[tab] or not stats then return end
    for i, data in ipairs(statRows(tab, stats)) do
        local row = window.rows[i]
        row.label:SetText(data[1])
        row.value:SetText(data[2] or "|cff808080Unavailable|r")
        row.bar:SetShown(data[3] ~= nil)
        row.bar:SetWidth(math.max(1, INNER * (data[3] or 0)))
        row:Show()
    end
    window.note:SetText(NOTES[tab])
end

-- Builds the header: tinted band, name, verdict word and a four-color meter.
local function buildHeader()
    window.band = window.content:CreateTexture(nil, "BACKGROUND", nil, 1)
    window.band:SetPoint("TOPLEFT", 8, -62)
    window.band:SetPoint("TOPRIGHT", -8, -62)
    window.band:SetHeight(96)

    window.name = window.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    window.name:SetPoint("TOPLEFT", 24, -74)
    window.verdict = window.content:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    window.verdict:SetPoint("TOPRIGHT", -24, -70)

    window.meter = CreateFrame("Frame", nil, window.content)
    window.meter:SetSize(INNER, 10)
    window.meter:SetPoint("TOPLEFT", 24, -108)
    local segment = INNER / #ns.LEVELS
    for i, level in ipairs(ns.LEVELS) do
        local block = window.meter:CreateTexture(nil, "ARTWORK")
        block:SetColorTexture(ns.RGB(level[1]))
        block:SetSize(segment - 2, 10)
        block:SetPoint("LEFT", (i - 1) * segment + 1, 0)
        local label = window.meter:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        label:SetPoint("TOP", block, "BOTTOM", 0, -3)
        label:SetText(level[1])
    end
    window.marker = window.meter:CreateTexture(nil, "OVERLAY")
    window.marker:SetColorTexture(1, 1, 1, 1)
    window.marker:SetSize(3, 18)
    window.meterText = window.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    window.meterText:SetPoint("TOPLEFT", 24, -136)
end

-- Builds the Verdict tab's section slots and the stats tabs' rows.
local function buildBody()
    window.sections = {}
    for i = 1, SECTIONS do
        local rule = window.content:CreateTexture(nil, "ARTWORK")
        rule:SetColorTexture(1, 0.82, 0, 0.25)
        rule:SetSize(INNER, 1)
        local heading = window.content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        local body = window.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        body:SetWidth(INNER)
        body:SetJustifyH("LEFT")
        body:SetSpacing(2)
        window.sections[i] = {rule = rule, heading = heading, body = body}
    end

    window.rows = {}
    for i = 1, ROWS do
        local row = CreateFrame("Frame", nil, window.content)
        row:SetSize(INNER, ROW_HEIGHT - 2)
        row:SetPoint("TOPLEFT", 24, BODY_TOP - (i - 1) * ROW_HEIGHT)
        local stripe = row:CreateTexture(nil, "BACKGROUND")
        stripe:SetAllPoints()
        stripe:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.04 or 0.08)
        row.bar = row:CreateTexture(nil, "BORDER")
        row.bar:SetPoint("TOPLEFT")
        row.bar:SetPoint("BOTTOMLEFT")
        row.bar:SetColorTexture(1, 0.75, 0.1, 0.28)
        row.label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        row.label:SetPoint("LEFT", 8, 0)
        row.value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.value:SetPoint("RIGHT", -8, 0)
        window.rows[i] = row
    end

    window.note = window.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    window.note:SetPoint("TOPLEFT", 24, BODY_TOP - ROWS * ROW_HEIGHT - 12)
    window.note:SetWidth(INNER)
    window.note:SetJustifyH("LEFT")
    window.note:SetSpacing(2)

    window.levels = {}
    for i, name in ipairs(LEVEL_TABS) do
        local button = CreateFrame("Button", nil, window.content, "UIPanelButtonTemplate")
        button:SetSize(70, 22)
        button:SetPoint("TOPLEFT", 24 + (i - 1) * 74, BODY_TOP + 4)
        button:SetText(ns.Colored(name))
        button:SetScript("OnClick", function()
            level = name
            render()
        end)
        window.levels[i] = button
    end

    window.settings = CreateFrame("Frame", nil, window.content)
    window.settings:SetAllPoints()
    window.compact = CreateFrame("CheckButton", nil, window.settings, "UICheckButtonTemplate")
    window.compact:SetSize(26, 26)
    window.compact:SetPoint("TOPLEFT", 20, BODY_TOP)
    window.compact:SetScript("OnClick", function(self)
        ns.db.compact = self:GetChecked() and true or false
        ns.GoblinRefresh()
    end)
    local label = window.settings:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", window.compact, "RIGHT", 4, 0)
    label:SetText("Compact trade window")
    local help = window.settings:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", window.compact, "BOTTOMLEFT", 30, -2)
    help:SetWidth(INNER - 30)
    help:SetJustifyH("LEFT")
    help:SetSpacing(2)
    help:SetText("Trades and inspects open a small strip instead of the goblin: just the verdict, one line of reasoning and any gold warning. Details still opens the full reasoning. Your own rating from the minimap always uses the full goblin.")

    window.sound = CreateFrame("CheckButton", nil, window.settings, "UICheckButtonTemplate")
    window.sound:SetSize(26, 26)
    window.sound:SetPoint("TOPLEFT", help, "BOTTOMLEFT", -30, -14)
    window.sound:SetScript("OnClick", function(self) ns.db.sound = self:GetChecked() and true or false end)
    local soundLabel = window.settings:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    soundLabel:SetPoint("LEFT", window.sound, "RIGHT", 4, 0)
    soundLabel:SetText("Goblin sounds")
    local soundHelp = window.settings:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    soundHelp:SetPoint("TOPLEFT", window.sound, "BOTTOMLEFT", 30, -2)
    soundHelp:SetWidth(INNER - 30)
    soundHelp:SetJustifyH("LEFT")
    soundHelp:SetText("A coin jingles when the goblin stamps a clean verdict, and a warning horn sounds for a risky one.")

    window.inspect = CreateFrame("CheckButton", nil, window.settings, "UICheckButtonTemplate")
    window.inspect:SetSize(26, 26)
    window.inspect:SetPoint("TOPLEFT", soundHelp, "BOTTOMLEFT", -30, -14)
    window.inspect:SetScript("OnClick", function(self) ns.db.inspect = self:GetChecked() and true or false end)
    local inspectLabel = window.settings:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    inspectLabel:SetPoint("LEFT", window.inspect, "RIGHT", 4, 0)
    inspectLabel:SetText("Check players I inspect")
    local inspectHelp = window.settings:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    inspectHelp:SetPoint("TOPLEFT", window.inspect, "BOTTOMLEFT", 30, -2)
    inspectHelp:SetWidth(INNER - 30)
    inspectHelp:SetJustifyH("LEFT")
    inspectHelp:SetText("When you inspect a player, the goblin opens beside the inspect window and checks their gold counters. Nothing is sent to them or saved.")

    window.empty = window.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    window.empty:SetPoint("TOP", 0, BODY_TOP - 20)
    window.empty:SetText("The game hasn't shown me these counters yet.")
end

-- Builds the window on first use as the right part of panel: a plain frame
-- along the panel's right edge, with a divider on its left. Dragging it drags
-- the panel, and showing or hiding it resizes the panel to fit. Tabs use
-- Blizzard's PanelTabButtonTemplate, which needs a named frame and named tabs.
local function build(panel)
    window = CreateFrame("Frame", "TrustyTradersDetails", panel)
    -- Start hidden so the first Show fires OnShow and widens the panel.
    window:Hide()
    window:SetSize(WIDTH, HEIGHT)
    window:SetPoint("TOPRIGHT")
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function() panel:StartMoving() end)
    window:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)
    window:SetScript("OnShow", ns.GoblinFit)
    window:SetScript("OnHide", ns.GoblinFit)

    window.content = CreateFrame("Frame", nil, window)
    window.content:SetAllPoints()
    local divider = window.content:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 0.82, 0, 0.3)
    divider:SetPoint("TOPLEFT", 0, -12)
    divider:SetPoint("BOTTOMLEFT", 0, 12)
    divider:SetWidth(1)
    local title = window.content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 24, -28)
    title:SetText("The goblin's books")

    buildHeader()
    buildBody()

    for i, name in ipairs(TABS) do
        local tab = CreateFrame("Button", "TrustyTradersDetailsTab" .. i, window, "PanelTabButtonTemplate")
        tab:SetID(i)
        tab:SetText(name)
        tab:SetScript("OnClick", function()
            current = i
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            render()
        end)
        if i == 1 then tab:SetPoint("TOPLEFT", window, "BOTTOMLEFT", 11, 2)
        else tab:SetPoint("TOPLEFT", _G["TrustyTradersDetailsTab" .. (i - 1)], "TOPRIGHT", 3, 0) end
        PanelTemplates_TabResize(tab, 0)
    end
    PanelTemplates_SetNumTabs(window, #TABS)
end

-- Closes the window if it is open; otherwise opens it in panel on the
-- Verdict tab with details ({name, whose ("your"
-- or "their"), result, sections = {{heading, text}, ...}, stats}), or a
-- placeholder when there are none yet. How it works starts on the player's level.
function ns.ToggleDetails(details, panel)
    if not window then build(panel)
    elseif window:IsShown() then window:Hide(); return end
    shown = details or {sections = {{"Nothing yet", "Open a trade, inspect a player, or click the minimap button, and I'll show my reasoning here."}}}
    current = 1
    level = shown.result and shown.result.verdict or "Low"
    window:Show()
    render()
end

-- The details half's width and height while it is open; nil while closed.
function ns.DetailsSize()
    if window and window:IsShown() then return WIDTH, HEIGHT end
end

-- Closes the window, e.g. when the goblin panel closes.
function ns.HideDetails()
    if window then window:Hide() end
end

-- Refreshes the open window, keeping its tab, so it follows the trade.
function ns.UpdateDetails(details)
    if details and window and window:IsShown() then
        shown = details
        render()
    end
end
