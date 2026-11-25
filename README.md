# Trusty Traders

A goblin advisor for World of Warcraft: Forever. When you open a trade, a goblin from Gadgetzan pops up beside the window, checks your partner's gold counters, slams down a stamp (TRUSTY, FAIR, IFFY or RISKY) and tells you in a speech bubble how risky the deal looks. Fellow Trusty Traders swap a one-word verdict so each goblin knows who it's dealing with.

## What the goblin does
- **Rates your trade partner** from two of Blizzard's statistics: *Most gold ever owned* and *Total gold acquired*. Gold above what the game recorded as acquired is unexplained.
  - Low: under 25% unexplained
  - Moderate: 25–49%
  - Elevated: 50–74%
  - High: 75% or more
  - Unrated: under 5g peak gold, or no counters available
- **Has something to say.** Each trade gets a random goblin quip for its verdict, typed out in a speech bubble, with an emote to match.
- **Warns louder** when a risky or unrated partner puts gold into the trade, and louder still as the offer grows past 100g and 1,000g.
- **Remembers old friends.** A returning partner gets a wave and a count of how many times you've traded.
- **Shows its reasoning.** A one-line brief in the panel, and a Details window with a risk meter and four tabs: the verdict, income, spending, and How it works, with the math for every level.
- **Rates you too.** Click the coin button on the minimap to see what other goblins see in your counters, the verdict your goblin sends after counting alt gold, and your rank in the cartel, from Trusty Trader to Suspicious Speculator.
- **Compact mode.** In Details > Settings, switch trades to a small strip with just the verdict.
- **Sounds.** A coin jingle for a clean verdict, a warning horn for a risky one. Turn them off in Details > Settings.
- **Remembers** the last verdict for each partner, on your PC only.
- **Keeps an alt ledger.** Gold you mail between your own characters (on this WoW account, with the addon installed) counts as explained in your own verdict.
- **Talks to other Trusty Traders.** On trade open, each addon sends its owner's own verdict in one hidden addon message, as a single word. Nothing else is shared.

It never accepts or cancels a trade. You decide.

## Read this before trusting a verdict
- A verdict is a hunch, not proof. Gifts, guild funds, alt mail and player trades look the same as bought gold.
- A verdict another player's addon sends is self-reported and can be edited. The goblin only uses it to say whether it agrees with its own check.
- Never use a verdict to call someone out in public.

## Install
Copy the `TrustyTraders` folder into your WoW: Forever client's `Interface/AddOns/` folder and `/reload`.

## Privacy
Everything is stored locally in `TrustyTradersDB`. The only network traffic is one hidden addon whisper to your trade partner per trade.

## Made with AI
Trusty Traders was made with the assistance of AI (Claude by Anthropic).

## License
MIT. The rating method is adapted from Forever IRS (MIT).
