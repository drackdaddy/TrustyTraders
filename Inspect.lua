-- Inspect: when you inspect a player, the goblin opens beside the inspect
-- window and runs the same gold check it runs on trades. Nothing is sent to
-- the other player and nothing is saved; a verdict saved from an earlier trade
-- with them is shown for comparison. Skipped when the "Check players I
-- inspect" setting is off, in combat, and while a trade is open, because the
-- trade's own check comes first.
-- Events: INSPECT_READY, ADDON_LOADED (follows the inspect window closing)
-- SavedVariables: reads TrustyTradersDB.inspect and TrustyTradersDB.verdicts
local addonName, ns = ...

local CAVEATS = "This is a hunch, not proof. Gifts, guild funds, alt mail and honest trades look the same as bought gold. Never use this to call someone out."

local looking -- the inspected player: {guid, name, saved, check, quip}

-- Every fact behind the verdict, for the details window.
local function details()
    local check = looking.check
    local verdict = {check and (check.reason or looking.quip) or "Still checking their books..."}
    if check and check.peak then
        verdict[2] = "Most gold ever owned: " .. ns.Gold(check.peak)
        verdict[3] = "Total gold acquired: " .. ns.Gold(check.acquired)
    end
    if check and check.percent then verdict[4] = "Unexplained: " .. ns.Gold(check.unexplained) end
    return {
        name = looking.name,
        whose = "their",
        result = check,
        stats = check and check.stats,
        sections = {
            {"The verdict", table.concat(verdict, "\n")},
            {"How I decide", ns.METHOD},
            {"Keep in mind", CAVEATS},
        },
    }
end

-- Redraws the goblin from everything known about the inspected player.
local function render()
    local check, saved = looking.check, looking.saved
    local lines, short = {}, {}
    local say = {lines = lines, short = short}
    if not check then
        say.status, say.mood = "...", "Talk"
        say.bubble = "Let me size up " .. looking.name .. "."
        short[1] = "Checking their books..."
    else
        say.verdict, say.mood = check.verdict, ns.Mood(check.verdict)
        say.bubble = check.reason or looking.quip
        short[1] = check.reason or ("|cffd0d0d0" .. ns.Brief(check, "their") .. "|r")
        if not check.reason then lines[1] = short[1] end
    end
    if saved and saved.checked then
        lines[#lines + 1] = "You've traded before. Last time I said " .. ns.Colored(saved.checked) .. "."
    end
    ns.GoblinSay("inspect", say, details())
end

-- Closes the goblin and drops its request when the inspect window closes,
-- unless a trade has taken the goblin over since.
local function closed()
    if not ns.GoblinIsOpen("inspect") then return end
    ns.CancelRating()
    ns.GoblinClose("inspect")
    looking = nil
end

-- Blizzard's inspect window loads on demand; follow its closing once it exists.
local followed = false
local function follow()
    if followed or not InspectFrame then return end
    followed = true
    InspectFrame:HookScript("OnHide", closed)
end

ns.On("ADDON_LOADED", function(name)
    if name == addonName or name == "Blizzard_InspectUI" then follow() end
end)

-- INSPECT_READY also fires for other addons' inspections, so only the player
-- shown in Blizzard's inspect window is checked, once per player.
ns.On("INSPECT_READY", function(guid)
    if not ns.db.inspect or InCombatLockdown() or ns.GoblinIsOpen("trade") then return end
    if not InspectFrame or not InspectFrame:IsShown() or not InspectFrame.unit then return end
    local unit = InspectFrame.unit
    local unitGUID = UnitGUID(unit)
    if ns.IsSecret(guid) or ns.IsSecret(unitGUID) or guid ~= unitGUID then return end
    if looking and looking.guid == guid and ns.GoblinIsOpen("inspect") then return end
    local this = {guid = guid, name = ns.ShortName(UnitName(unit)) or "this player", saved = ns.db.verdicts[guid]}
    looking = this
    ns.GoblinOpen("inspect")
    render()
    ns.RatePartner(unit, function(result)
        if looking ~= this then return end
        this.check = result
        this.quip = not result.reason and ns.Quip(result.verdict) or nil
        render()
    end)
end)
