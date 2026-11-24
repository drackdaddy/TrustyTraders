-- Rating: reads a character's gold statistics and turns two of them into a
-- verdict; the rest fill the Income and Spending tabs.
-- Unexplained gold is "Most gold ever owned" above "Total gold acquired". Gifts,
-- alt mail, guild funds and player trades look the same as bought gold, so a
-- verdict is a hunch to weigh, never proof. Method adapted from Forever IRS.
-- Events: INSPECT_ACHIEVEMENT_READY, ADDON_LOADED (Blizzard_AchievementUI guard)
-- SavedVariables: none
local addonName, ns = ...

local MIN_PEAK = 50000          -- 5g in copper; below this the ratio means little
local TIMEOUT = 10              -- seconds to wait for the server's reply
local COIN = {g = 10000, s = 100, c = 1}

local pending -- the open request: {guid, done}

-- Statistics read for each rating, grouped by details tab: {key, statistic
-- ID, label, true when the value is gold}. IDs checked on Forever 1.60.1.
ns.STATS = {
    Income = {
        {"peak", 334, "Most gold ever owned", true},
        {"acquired", 328, "Total gold acquired", true},
        {"looted", 333, "Gold looted", true},
        {"quests", 326, "Quest rewards", true},
        {"vendors", 921, "Vendor sales", true},
        {"auctions", 919, "Auction earnings", true},
        {"largestSale", 332, "Largest auction sale", true},
        {"daily", 753, "Average earned per day", true},
    },
    Spending = {
        {"travel", 1146, "Travel", true},
        {"postage", 1148, "Postage", true},
        {"barber", 1147, "Barber shops", true},
        {"respec", 1150, "Talent respecs", true},
        {"largestBid", 331, "Largest auction bid", true},
        {"posted", 329, "Auctions posted"},
        {"purchases", 330, "Auction purchases"},
    },
}

-- How a verdict is reached, for the details window. The scale itself is
-- drawn as the window's risk meter.
ns.METHOD = "Unexplained gold is the most gold a character has ever owned minus the total gold the game recorded it acquiring. The game doesn't record gold from player trades, and maybe not gifts or mail, so that gold shows up as unexplained. The verdict comes from the share of peak gold that's unexplained: Low under 25%, Moderate to 49%, Elevated to 74%, High from 75%. Under 5g peak gold isn't rated."

-- Reads digits that may use complete groups of three ("1,234" or "1.234").
-- Returns a number, or nil when the grouping is ambiguous.
local function integer(digits)
    if digits:match("^%d+$") then return tonumber(digits) end
    local head, rest = digits:match("^(%d%d?%d?)([,%.].+)$")
    if not head or #rest % 4 ~= 0 then return nil end
    local separator = rest:sub(1, 1)
    for i = 1, #rest, 4 do
        local group = rest:sub(i + 1, i + 3)
        if rest:sub(i, i) ~= separator or not group:match("^%d%d%d$") then return nil end
        head = head .. group
    end
    return tonumber(head)
end

-- Converts a statistic value to copper. Accepts a plain number or Blizzard's
-- coin markup; returns nil for anything else rather than guessing.
local function copper(raw)
    if ns.IsSecret(raw) then return nil end
    local number = tonumber(raw)
    if number then return number >= 0 and number % 1 == 0 and number or nil end
    if type(raw) ~= "string" or #raw > 400 then return nil end
    local known = true
    local function unit(token)
        local name = token:lower():gsub("\\", "/")
        local metal = name:match("^interface/moneyframe/ui%-(%a+)icon") or name:match("^:?coin%-(%a+)")
        local letter = metal and metal:sub(1, 1)
        if not (metal == "gold" or metal == "silver" or metal == "copper") then known = false end
        return letter or ""
    end
    local text = raw:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        :gsub("|T(.-)|t", unit):gsub("|A(.-)|a", unit)
        :gsub("\194\160", ""):gsub("\226\128\175", ""):gsub("%s", "")
    if not known or text == "" then return nil end
    local total, last, position = 0, math.huge, 1
    while position <= #text do
        local digits, letter, finish = text:match("^([%d,%.]+)([gsc])()", position)
        local amount = digits and integer(digits)
        if not amount or COIN[letter] >= last or (letter ~= "g" and amount > 99) then return nil end
        total, last, position = total + amount * COIN[letter], COIN[letter], finish
    end
    return total
end

-- Converts a count statistic to a whole number, or nil when unreadable.
local function count(raw)
    if ns.IsSecret(raw) then return nil end
    local number = tonumber(raw)
    if number then return number >= 0 and number % 1 == 0 and number or nil end
    if type(raw) == "string" and #raw <= 40 then return integer((raw:gsub("%s", ""))) end
end

-- Reads every statistic in ns.STATS with getter (GetStatistic or
-- GetComparisonStatistic). Returns {[key] = number}; unreadable ones are absent.
local function readAll(getter)
    local values = {}
    for _, group in pairs(ns.STATS) do
        for _, stat in ipairs(group) do
            local ok, raw = pcall(getter, stat[2])
            if ok then values[stat[1]] = stat[4] and copper(raw) or not stat[4] and count(raw) or nil end
        end
    end
    return values
end

-- Returns an Unrated result carrying a reason the goblin can say.
local function unrated(reason)
    return {verdict = ns.UNRATED, reason = reason}
end

-- Rates statistics read by readAll. altGold, copper received from your own
-- alts, counts as explained. Returns {verdict, reason, stats, peak, acquired,
-- alt, unexplained, percent}; reason is set only when the verdict is Unrated.
local function rate(stats, altGold)
    local peak, acquired = stats.peak, stats.acquired
    local result = unrated("The game wouldn't show me the gold counters.")
    result.stats = stats
    if not peak or not acquired then return result end
    result.reason = "Barely any gold to judge."
    result.peak, result.acquired, result.alt = peak, acquired, altGold or 0
    if peak < MIN_PEAK then return result end
    result.reason = nil
    result.unexplained = math.max(0, peak - acquired - result.alt)
    -- Multiply first so 0.29 * 100 does not land one percent low.
    result.percent = math.floor(result.unexplained * 100 / peak)
    for _, level in ipairs(ns.LEVELS) do
        if result.percent >= level[2] then result.verdict = level[1] end
    end
    return result
end

-- Your own rating from your counters. Gold from your alts counts as explained
-- unless ignoreAlts is true, which gives what other goblins see.
function ns.RateSelf(ignoreAlts)
    local alts = not ignoreAlts and ns.AltGold() or 0
    return rate(readAll(GetStatistic), alts)
end

-- One sentence on where a rated result's peak gold came from. whose is
-- "your" or "their". Returns nil for an Unrated result without numbers.
function ns.Brief(result, whose)
    if not result.percent then return nil end
    if result.unexplained == 0 then
        return "All of " .. whose .. " " .. ns.Gold(result.peak) .. " peak gold is in " .. whose .. " recorded income."
    end
    return ns.Gold(result.unexplained) .. " of " .. whose .. " " .. ns.Gold(result.peak) .. " peak gold ("
        .. result.percent .. "%) isn't in " .. whose .. " recorded income."
end

-- Ends the open request and frees the shared comparison slot.
local function finish(result)
    local request = pending
    pending = nil
    ClearAchievementComparisonUnit()
    request.done(result)
end

-- Drops the open request without answering it, e.g. when the trade closes.
function ns.CancelRating()
    if pending then
        pending = nil
        ClearAchievementComparisonUnit()
    end
end

-- Asks the server for unit's statistics. done(result) is called once with a
-- rating table (see rate), which is Unrated with a reason when reading failed.
function ns.RatePartner(unit, done)
    ns.CancelRating()
    local guid = UnitGUID(unit)
    if InCombatLockdown() then done(unrated("Can't check anyone's books in the middle of a fight.")); return end
    if not guid or not CanInspect(unit, false) then done(unrated("I can't get a look at their books from here.")); return end
    if AchievementFrame and AchievementFrame:IsShown() and AchievementFrame.isComparison then
        done(unrated("Close the achievement comparison and reopen the trade so I can look."))
        return
    end
    local request = {guid = guid, done = done}
    pending = request
    SetAchievementComparisonUnit(unit)
    C_Timer.After(TIMEOUT, function()
        if pending == request then finish(unrated("They never showed me their books.")) end
    end)
end

ns.On("INSPECT_ACHIEVEMENT_READY", function(guid)
    if not pending or guid ~= pending.guid then return end
    if InCombatLockdown() then finish(unrated("A fight broke out before I could read their books.")); return end
    finish(rate(readAll(GetComparisonStatistic)))
end)

-- Blizzard's comparison panel listens for INSPECT_ACHIEVEMENT_READY even while
-- hidden and errors on inspections it did not start, so let it listen only
-- while it is shown. Its own scripts are left intact.
local guarded = false
local function guard()
    local panel = AchievementFrameComparison
    if guarded or not panel then return end
    guarded = true
    local function sync(self)
        if self:IsVisible() then self:RegisterEvent("INSPECT_ACHIEVEMENT_READY")
        else self:UnregisterEvent("INSPECT_ACHIEVEMENT_READY") end
    end
    panel:HookScript("OnShow", sync)
    panel:HookScript("OnHide", sync)
    sync(panel)
end

ns.On("ADDON_LOADED", function(name)
    if name == addonName or name == "Blizzard_AchievementUI" then guard() end
end)
