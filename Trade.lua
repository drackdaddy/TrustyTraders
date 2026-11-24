-- Trade: runs the goblin for each trade. Rates the partner from the game's
-- counters, swaps verdicts with a fellow Trusty Trader, remembers what it
-- learned, warns harder when a risky partner offers gold, and writes the
-- brief and the full reasoning the goblin shows. It never accepts or cancels
-- a trade; the decision stays with the player.
-- Events: TRADE_SHOW, TRADE_CLOSED, TRADE_MONEY_CHANGED
-- SavedVariables: TrustyTradersDB.verdicts {[guid] = {name, checked, claimed, at}}
local _, ns = ...

local CAVEATS = "This is a hunch, not proof. Gifts, guild funds, alt mail and honest trades look the same as bought gold. Their goblin's verdict is self-reported and can't be checked. Never use this to call someone out."

local trade -- the open trade: {guid, name, last, mine, sent, check, claimed}

-- What a claimed verdict means next to the one the goblin checked itself.
local function claimNote()
    local claimed = ns.LevelIndex(trade.claimed)
    local checked = trade.check and ns.LevelIndex(trade.check.verdict)
    if not claimed or not checked then return "I can't check that myself." end
    if claimed < checked then return "They say alts explain the rest; I can't check that." end
    if claimed == checked then return "Our books agree." end
    return "They rate themselves worse than I do."
end

-- Every fact behind the verdict, for the details window: {name, result,
-- sections = {{heading, text}, ...}, stats}.
local function details()
    local check, mine, last = trade.check, trade.mine, trade.last
    local verdict = {}
    if not check then verdict[1] = "Still checking their books..."
    else
        verdict[1] = check.reason or ns.ADVICE[check.verdict]
        if check.peak then
            verdict[2] = "Most gold ever owned: " .. ns.Gold(check.peak)
            verdict[3] = "Total gold acquired: " .. ns.Gold(check.acquired)
        end
        if check.percent then verdict[4] = "Unexplained: " .. ns.Gold(check.unexplained) end
    end
    local thisTrade = {
        "Gold they're offering: " .. ns.Gold(GetTargetTradeMoney()),
        "Your verdict sent to them: " .. (trade.sent and ns.Colored(mine.verdict) or "not sent (chat is locked down)"),
    }
    if mine.alt and mine.alt > 0 then
        thisTrade[#thisTrade + 1] = "Your verdict counts " .. ns.Gold(mine.alt) .. " mailed from your alts as explained."
    end
    if last then
        thisTrade[#thisTrade + 1] = "Last trade (" .. date("%b %d, %Y", last.at) .. "): I said "
            .. ns.Colored(last.checked or "nothing") .. ", their goblin said " .. ns.Colored(last.claimed or "nothing") .. "."
    end
    return {
        name = trade.name,
        whose = "their",
        result = check,
        stats = check and check.stats,
        sections = {
            {"The verdict", table.concat(verdict, "\n")},
            {"How I decide", ns.METHOD},
            {"Their addon", trade.claimed
                and ("A fellow Trusty Trader. Their goblin says " .. ns.Colored(trade.claimed) .. ". " .. claimNote())
                or "No word from their goblin. They may not have Trusty Traders."},
            {"This trade", table.concat(thisTrade, "\n")},
            {"Keep in mind", CAVEATS},
        },
    }
end

-- Redraws the goblin from everything known about the open trade.
local function render()
    local check, headline, paragraphs, short = trade.check, nil, {}, {}
    if not check then
        headline = "Checking..."
        paragraphs[1] = "Let me look at their books."
        short[1] = paragraphs[1]
        if trade.last and trade.last.checked then
            paragraphs[2] = "Last time (" .. date("%b %d", trade.last.at) .. ") I said " .. ns.Colored(trade.last.checked) .. "."
        end
    elseif check.reason then
        headline = check.verdict
        paragraphs[1] = check.reason
        short[1] = check.reason
    else
        headline = ns.Colored(check.verdict)
        paragraphs[1] = ns.ADVICE[check.verdict]
        paragraphs[2] = "|cffb0b0b0" .. ns.Brief(check, "their") .. "|r"
        short[1] = paragraphs[2]
    end
    if trade.claimed then
        paragraphs[#paragraphs + 1] = "Fellow Trusty Trader! Their goblin says " .. ns.Colored(trade.claimed) .. ". " .. claimNote()
    end
    local risky = check and (check.reason or ns.LevelIndex(check.verdict) >= 3)
    if risky and GetTargetTradeMoney() > 0 then
        paragraphs[#paragraphs + 1] = "|cffff6060They're offering gold. If it was bought, Blizzard can take it back from you.|r"
        short[#short + 1] = "|cffff6060They're offering gold. Careful.|r"
    end
    if trade.claimed then
        table.insert(short, 2, "Their goblin says " .. ns.Colored(trade.claimed) .. ".")
    end
    ns.GoblinSay("trade", ns.Mood(check and check.verdict), headline, paragraphs, details(), short)
end

-- Saves the latest checked and claimed verdicts for the partner. An Unrated
-- check never replaces an earlier real verdict.
local function store()
    local record = ns.db.verdicts[trade.guid] or {}
    record.name = trade.name
    if trade.check and not trade.check.reason then record.checked = trade.check.verdict end
    if trade.claimed then record.claimed = trade.claimed end
    record.at = time()
    ns.db.verdicts[trade.guid] = record
end

-- Called by Comms with a verdict another addon sent. Only the open trade's
-- partner is listened to.
function ns.TradeClaim(sender, claimed)
    if not trade or sender ~= trade.name then return end
    trade.claimed = claimed
    store()
    render()
end

ns.On("TRADE_SHOW", function()
    local guid, name = UnitGUID("NPC"), ns.ShortName(UnitName("NPC"))
    if not guid or not name or ns.IsSecret(guid) then
        trade = nil
        ns.GoblinOpen("trade")
        ns.GoblinSay("trade", "Question", "Who's this?", {"I can't tell who you're trading with."})
        return
    end
    -- Copy the saved record: store() updates it in place during this trade.
    local saved = ns.db.verdicts[guid]
    local this = {guid = guid, name = name, mine = ns.RateSelf(),
        last = saved and {checked = saved.checked, claimed = saved.claimed, at = saved.at}}
    trade = this
    ns.GoblinOpen("trade")
    this.sent = ns.SendVerdict(name, this.mine.verdict)
    render()
    ns.RatePartner("NPC", function(result)
        if trade ~= this then return end
        this.check = result
        store()
        render()
    end)
end)

ns.On("TRADE_CLOSED", function()
    ns.CancelRating()
    ns.GoblinClose("trade")
    trade = nil
end)

ns.On("TRADE_MONEY_CHANGED", function()
    if trade then render() end
end)
