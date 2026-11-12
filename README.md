# Tap to Pin Tooltip

![Tap to Pin Tooltip](assets/2x/tap-to-pin-icon.png)

A quality-of-life mod for **Balatro** that makes card inspection more intuitive with persistent tooltips, customizable scaling, and optional interface cleanup.

Designed primarily for touch controls, while preserving the game's original mouse interactions.

**Author:** GlowlineStd  
**Requires:** [Steamodded](https://github.com/Steamodded/smods)

## Features

### Persistent Tooltips

- **Tap to pin:** Tap a Joker, consumable, or other eligible card to keep its tooltip visible without holding it.
- **Tap to dismiss:** Tap the same card, another card, or an empty area to close the current tooltip.
- **Drag to dismiss:** Tooltips automatically disappear when a card is dragged and remain hidden throughout the gesture.
- **Automatic deselection:** Cards return to their normal position when their tooltip is dismissed or when released after dragging.
- **Hand card behavior:** Playing cards in your hand retain their original press-and-hold inspection behavior.

### Customization

- **Tooltip scaling:** Adjust tooltip size from 1.00× to 1.50× in increments of 0.05×.
- **Clean interface:** Optionally hide attached card action buttons without modifying the underlying game actions.
- **In-game settings:** Configure everything directly through the Steamodded mod menu.
- **Localization:** Automatic English and Spanish localization, including Latin American Spanish.

## Installation

1. Install [Steamodded](https://github.com/Steamodded/smods).
2. Download the latest `TapToPinTooltip` ZIP from the **Releases** section of this repository.
3. Extract the archive into your Balatro `Mods` directory.
4. Launch Balatro and open the **Mods** menu to configure Tap to Pin Tooltip.

Your installation should look like this:

```text
Mods/
└── TapToPinTooltip/
    ├── main.lua
    ├── config.lua
    ├── assets/
    ├── localization/
    └── ...
```

## Configuration

Navigate to **Mods → Tap to Pin Tooltip → Config**.

| Setting | Default | Description |
|---------|---------|-------------|
| Tooltip Scale | 1.00× | Adjusts tooltip size from 1.00× to 1.50×. |
| Hide Attached Card Buttons | Off | Hides individual action buttons attached to cards. |

Settings are automatically localized based on your selected game language. Unsupported languages fall back to English.

> [!IMPORTANT]
> Hiding attached card buttons does not introduce alternative controls for buying, selling, or using cards. Make sure you have another way to perform these actions before enabling this option.

## Compatibility

### Sticky Fingers

Tap to Pin Tooltip pairs particularly well with [Sticky Fingers](https://github.com/eramdam/sticky-fingers).

While Sticky Fingers provides drag-based interactions for buying, selling, and using cards, Tap to Pin Tooltip enhances card inspection and allows attached action buttons to be hidden for a cleaner interface.

**Recommended setup:**
- Enable **Hide Attached Card Buttons** in Tap to Pin Tooltip.
- Use Sticky Fingers' drag-based controls to interact with cards.
- Tap cards to inspect their descriptions without holding them.

Both mods complement each other without requiring any additional configuration.

**Sticky Fingers is entirely optional.** Tap to Pin Tooltip works independently and only requires Steamodded.

## Input Behavior

Tap-to-pin functionality activates when Balatro detects touch input.

Standard mouse interactions retain their original hover and click behavior. Tooltip scaling and button visibility settings remain available regardless of input method.

## Updating

1. Close Balatro.
2. Download the latest release.
3. Replace the existing `TapToPinTooltip` folder with the updated version.
4. Launch the game.

To uninstall, simply remove the `TapToPinTooltip` folder from your `Mods` directory.

## Feedback and Bug Reports

Found a bug or have a suggestion? Open an issue in this repository.

When reporting a problem, please include:
- Balatro version
- Steamodded version
- Steps to reproduce the issue
- Expected and actual behavior
- Screenshots, if applicable

---

Developed and maintained by **GlowlineStd**.
