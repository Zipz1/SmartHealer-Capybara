# SmartHealer Capybara

> **Heal smarter. Waste less mana. Stay in control.**

Automatic spell rank selection for Turtle WoW 1.18.1 based realms.

SmartHealer Capybara selects the most appropriate healing spell rank based on your target's missing health. By reducing overhealing and unnecessary mana usage, it helps you heal more efficiently in dungeons, raids and PvP.

Originally inspired by SmartHealer, SmartHealer Capybara continues the project with a redesigned configuration interface, Focus Players, improved compatibility and ongoing community maintenance.

---

# Features

- Intelligent automatic spell rank selection
- Reduce overhealing and conserve mana
- Configurable overheal multiplier
- Priority healing with Focus Players
- Individual Raid and Focus rank ranges for every spell
- Modern and easy-to-use configuration UI
- Compatible with Turtle WoW and Capybara clients

---

# Screenshots

## Spell Configuration

Configure spell rank limits and overheal settings for each healing spell.

![Spell Configuration](docs/images/spells.png)

---

## Focus Players

Prioritize tanks, healers, PvP flag carriers, yourself or any important player.

![Focus Players](docs/images/focus.png)

---

# Installation

Extract the addon into:

```text
Interface/AddOns/SmartHealerCapybara
```

Restart the game or reload your UI.

Open the configuration with:

```text
/shc config
```

---

# Usage

Create a macro for the spell you want SmartHealer Capybara to manage.

Example:

```text
/heal Healing Touch
```

or

```text
/heal Regrowth
```

SmartHealer Capybara automatically selects the most appropriate spell rank for the current situation.

---

# Recommended

For the best experience, pair SmartHealer Capybara with **Puppeteer**.

Puppeteer handles targeting while SmartHealer Capybara automatically selects the optimal healing spell rank.

---

# Credits

**SmartHealer Capybara**

Maintained by **Zipz**

Based on earlier versions of **SmartHealer** by:

- Garkin
- Melbaa
- dsidirop
