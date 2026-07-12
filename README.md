# SmartHealer Capybara

> **Smart healing with automatic spell rank selection.**

Aautomatically chooses the appropriate spell rank based on the target's missing health. It helps reduce overhealing while giving you full control over how each healing spell behaves.

Based on earlier versions of SmartHealer, with an updated interface, Focus Players, and compatibility improvements.

---

# Features

- Automatic spell rank selection
- Configurable overheal multiplier
- Raid and Focus rank ranges for each spell
- Focus Players
- Simple configuration interface
- Compatible with Turtle WoW and Capybara clients

---

# Screenshots

## Spell Configuration

Configure spell ranks and overheal settings.

![Spell Configuration](docs/images/spells.png)

---

## Focus Players

Give selected players their own healing profile.

![Focus Players](docs/images/focus.png)

---

# Installation

Extract the addon to:

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

Create a macro using the spell you want SmartHealer to manage.

Example:

```text
/heal Healing Touch
```

or

```text
/heal Regrowth
```

The addon automatically selects the appropriate spell rank.

---

# Recommended

Works well together with **Puppeteer**.

Puppeteer handles targeting while SmartHealer Capybara handles spell rank selection.

---

# Credits

**Maintained by Zipz**

Based on earlier versions of **SmartHealer** by:

- Garkin
- Melbaa
- dsidirop
