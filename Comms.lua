-- Comms: swaps one word with a fellow Trusty Trader. When a trade opens, each
-- addon sends its own verdict to the trade partner as one hidden addon
-- whisper. Nothing else is ever sent: no gold amounts, no alt names, no
-- stored verdicts about other players.
-- Events: CHAT_MSG_ADDON
-- SavedVariables: none
local _, ns = ...

local PREFIX = "TrustyTraders"
local VERSION = "1"

C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

-- Sends verdict, your own, to the player named name. Skipped while Blizzard's
-- chat messaging lockdown is active. Returns true when the message was sent.
function ns.SendVerdict(name, verdict)
    if C_ChatInfo.InChatMessagingLockdown() then return false end
    C_ChatInfo.SendAddonMessage(PREFIX, VERSION .. ":" .. verdict, "WHISPER", name)
    return true
end

ns.On("CHAT_MSG_ADDON", function(prefix, text, channel, sender)
    if prefix ~= PREFIX or channel ~= "WHISPER" or ns.IsSecret(text) or type(text) ~= "string" then return end
    local claimed = text:match("^" .. VERSION .. ":(%a+)$")
    if claimed and (claimed == ns.UNRATED or ns.LevelIndex(claimed)) then
        ns.TradeClaim(ns.ShortName(sender), claimed)
    end
end)
