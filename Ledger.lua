-- Alt ledger: remembers every character that logs in with TrustyTraders on
-- this WoW account and counts the gold each one takes from mail another of
-- them sent. That gold is outside the game's "Total gold acquired" counter, so
-- without the ledger moving gold between your own alts would make your own
-- verdict look worse.
-- Events: PLAYER_LOGIN, MAIL_INBOX_UPDATE
-- SavedVariables: TrustyTradersDB.alts {[name] = true},
--                 TrustyTradersDB.received {[name] = copper from own alts}
local _, ns = ...

local player
-- Inbox money as of the last update, by mail index. Read when gold is taken,
-- because the header may already be empty by the time the take hook runs.
local inbox = {}

ns.On("PLAYER_LOGIN", function()
    player = ns.ShortName(UnitName("player"))
    if player then ns.db.alts[player] = true end
end)

ns.On("MAIL_INBOX_UPDATE", function()
    wipe(inbox)
    for index = 1, GetInboxNumItems() do
        local _, _, sender, _, money, _, _, _, _, wasReturned = GetInboxHeaderInfo(index)
        -- Returned mail is your own gold coming back, not new gold.
        if not wasReturned and type(money) == "number" and money > 0 then
            inbox[index] = {sender = ns.ShortName(sender), money = money}
        end
    end
end)

-- Credits the gold in mail at index when another of your alts sent it. The
-- entry is emptied so a repeated click cannot count the same gold twice.
local function taken(index)
    local mail = inbox[index]
    if not mail or not player then return end
    inbox[index] = nil
    if mail.sender and mail.sender ~= player and ns.db.alts[mail.sender] then
        ns.db.received[player] = (ns.db.received[player] or 0) + mail.money
    end
end
hooksecurefunc("TakeInboxMoney", taken)
hooksecurefunc("AutoLootMailItem", taken)

-- Copper this character has received from your other alts by mail.
function ns.AltGold()
    return player and ns.db.received[player] or 0
end
