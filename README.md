# SmartHealer Capybara 1.6.8

Smart rank selection for healing spells on Turtle WoW 1.18.1 based realms.

## Quick start

1. Install this folder as `Interface/AddOns/SmartHealerCapybara/`.
2. Restart the game.
3. Open the configuration with `/shc config`.
4. Create one macro per healing spell:

```text
/heal Regrowth
/heal Rejuvenation
/heal Healing Touch
```

Do not specify a rank. SmartHealer selects it automatically.

Use `/cast Spell Name` when you want to bypass SmartHealer.

## Puppeteer recommendation

SmartHealer works especially well with Puppeteer: Puppeteer handles mouseover or raid-frame targeting, while SmartHealer selects the spell rank.

## Supported clients

Designed for Turtle WoW 1.18.1 based realms and tested with:

- Capybara client on the Capybara realm
- Turtle WoW client connected to Capybara with a changed realmlist

## Empty spell list after upgrading

Fully exit WoW and delete these old SavedVariables files:

```text
WTF/Account/<AccountName>/SavedVariables/SmartHealerCapybara.lua
WTF/Account/<AccountName>/SavedVariables/SmartHealerCapybara.lua.bak
```

Restart the client. The files are recreated automatically.

## Credits

- SmartHealer Capybara: Zipz
- Based on earlier versions of SmartHealer by Garkin, Melbaa & dsidirop

See the project README on GitHub for screenshots and full documentation.
