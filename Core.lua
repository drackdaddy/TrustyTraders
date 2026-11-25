-- Core: the addon's single event-dispatch frame, SavedVariables defaults and
-- the helpers every feature shares (verdict scale, names, secret checks).
-- Events: ADDON_LOADED (sets SavedVariables defaults)
-- SavedVariables: TrustyTradersDB = {alts = {}, received = {}, verdicts = {},
--                 minimapAngle = 225, compact = false, sound = true}
local addonName, ns = ...

local dispatcher = CreateFrame("Frame")
local handlers = {}

-- Runs fn(...) with the event's payload whenever event fires. Handlers run in
-- the order they were added, which follows the TOC load order.
function ns.On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        dispatcher:RegisterEvent(event)
    end
    table.insert(handlers[event], fn)
end

dispatcher:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event]) do fn(...) end
end)

ns.On("ADDON_LOADED", function(name)
    if name ~= addonName then return end
    TrustyTradersDB = TrustyTradersDB or {}
    local db = TrustyTradersDB
    db.alts = db.alts or {}
    db.received = db.received or {}
    db.verdicts = db.verdicts or {}
    db.minimapAngle = db.minimapAngle or 225
    db.compact = db.compact == true
    db.sound = db.sound ~= false
    ns.db = db
end)

-- Verdicts from safest to riskiest, each with the lowest share of
-- unexplained gold (percent of peak gold) that reaches it.
ns.LEVELS = {{"Low", 0}, {"Moderate", 25}, {"Elevated", 50}, {"High", 75}}
ns.UNRATED = "Unrated"
local COLORS = {Low = "ff40ff40", Moderate = "ffffd100", Elevated = "ffff8000", High = "ffff4040"}
local MOODS = {Low = "Cheer", Moderate = "Talk", Elevated = "Exclaim", High = "Point"}

-- The word stamped on the goblin's badge for each verdict.
ns.STAMPS = {Low = "TRUSTY", Moderate = "FAIR", Elevated = "IFFY", High = "RISKY", [ns.UNRATED] = "???"}

-- What the goblin might say for each verdict; one is picked per trade.
ns.QUIPS = {
    Low = {
        "Their books look clean, friend. Deal away.",
        "Honest coin! Rarer than a cheap room in Gadgetzan.",
        "Clean as a fresh-minted copper. Go on, deal.",
        "Not a smudge on these books. I like 'em already.",
    },
    Moderate = {
        "Some of their gold has no paper trail. Probably alts. Probably.",
        "A few coins wandered in from nowhere. Keep an eye out.",
        "Mostly honest. Mostly. Count your change.",
        "Bit of fog around their gold. Nothing to panic over.",
    },
    Elevated = {
        "Half their gold came from somewhere I can't see. Keep it small.",
        "That's a lot of mystery money. Don't bet the shop.",
        "My nose is twitching. Small deals only, friend.",
        "Where'd all that come from? Keep your purse close.",
    },
    High = {
        "Most of their gold came from nowhere. I'd walk away.",
        "Whoa! These books smell worse than the Booty Bay docks.",
        "Nope. My ears are ringing just looking at this.",
        "If I were you, I'd find another buyer.",
    },
}

-- A random quip for a rated verdict.
function ns.Quip(verdict)
    local quips = ns.QUIPS[verdict]
    return quips[math.random(#quips)]
end

-- A verdict in its color, e.g. orange "Elevated". Unrated stays plain.
function ns.Colored(verdict)
    return COLORS[verdict] and ("|c" .. COLORS[verdict] .. verdict .. "|r") or verdict
end

-- A verdict's color as r, g, b (0-1); Unrated is grey.
function ns.RGB(verdict)
    local hex = COLORS[verdict] or "ff9a9a9a"
    return tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, tonumber(hex:sub(7, 8), 16) / 255
end

-- The goblin's mood for a verdict; Unrated or unknown gets "Question".
function ns.Mood(verdict)
    return MOODS[verdict] or "Question"
end

-- Returns a verdict's step on the scale (1 = Low ... 4 = High), or nil for
-- Unrated or anything unrecognized.
function ns.LevelIndex(verdict)
    for i, level in ipairs(ns.LEVELS) do
        if level[1] == verdict then return i end
    end
end

-- True for Midnight "secret" values, which must never be read or decoded.
function ns.IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end

-- A character's first name, without a realm suffix or Forever's surname, so
-- names from units, mail and addon messages compare equal.
function ns.ShortName(name)
    if type(name) ~= "string" or ns.IsSecret(name) then return nil end
    return name:match("^[^%s%-]+")
end

-- Formats a whole number with thousands separators ("1,500").
function ns.Count(number)
    local grouped = string.format("%d", number):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return grouped
end

-- Formats copper for display: whole gold ("1,500g"), or silver and copper
-- when there is some but under 1g.
function ns.Gold(copper)
    local gold = math.floor(copper / 10000)
    if gold == 0 and copper > 0 then
        return string.format("%ds %dc", math.floor(copper / 100) % 100, copper % 100)
    end
    return ns.Count(gold) .. "g"
end
