-- Self: shows how you're rated, in the goblin panel, opened from the minimap
-- button. Two verdicts: what other goblins see in your game counters, and the
-- one your goblin sends them after counting gold mailed between your alts.
-- Events: none
-- SavedVariables: reads TrustyTradersDB.alts
local _, ns = ...

local NOTE = "Other goblins only see your game counters. Your alt gold is your own addon's record, so they can't check it. Gold you move to alts outside mail, such as by trading, isn't counted."

-- Your alts' names in the ledger, sorted, as one line.
local function altList()
    local names = {}
    for name in pairs(ns.db.alts) do names[#names + 1] = name end
    table.sort(names)
    return table.concat(names, ", ")
end

-- Every fact behind your verdicts, for the details window: {name, result,
-- sections = {{heading, text}, ...}, stats}.
local function details(seen, told)
    local seenLines = {seen.reason or "This is what their goblin works out from your game counters."}
    if seen.peak then
        seenLines[2] = "Most gold ever owned: " .. ns.Gold(seen.peak)
        seenLines[3] = "Total gold acquired: " .. ns.Gold(seen.acquired)
    end
    if seen.percent then seenLines[4] = "Unexplained: " .. ns.Gold(seen.unexplained) end
    local toldLines = {
        "Verdict sent: " .. ns.Colored(told.verdict),
        "Gold mailed to this character from your alts: " .. ns.Gold(told.alt or 0),
    }
    if told.percent then
        toldLines[3] = "Still unexplained after that: " .. ns.Gold(told.unexplained) .. " (" .. told.percent .. "% of peak)"
    end
    toldLines[#toldLines + 1] = "Alts in your ledger: " .. altList()
    return {
        name = UnitName("player"),
        whose = "your",
        result = seen,
        stats = seen.stats,
        sections = {
            {"What other goblins see", table.concat(seenLines, "\n")},
            {"What your goblin tells them", table.concat(toldLines, "\n")},
            {"How I decide", ns.METHOD},
            {"Keep in mind", NOTE},
        },
    }
end

-- Opens the panel with your own rating.
local function open()
    local seen, told = ns.RateSelf(true), ns.RateSelf()
    local paragraphs = {}
    if seen.reason then
        paragraphs[1] = seen.reason
    else
        paragraphs[1] = "That's how other goblins see your books."
        paragraphs[2] = "|cffb0b0b0" .. ns.Brief(seen, "your") .. "|r"
    end
    if (told.alt or 0) > 0 then
        paragraphs[#paragraphs + 1] = "Counting " .. ns.Gold(told.alt) .. " mailed from your alts, your goblin tells them "
            .. ns.Colored(told.verdict) .. "."
    else
        paragraphs[#paragraphs + 1] = "Your goblin tells them " .. ns.Colored(told.verdict) .. "."
    end
    ns.GoblinOpen("self")
    ns.GoblinSay("self", ns.Mood(seen.verdict), ns.Colored(seen.verdict), paragraphs, details(seen, told))
end

-- Opens your rating, or closes it if it is already showing.
function ns.ToggleSelf()
    if ns.GoblinIsOpen("self") then ns.GoblinClose("self") else open() end
end
