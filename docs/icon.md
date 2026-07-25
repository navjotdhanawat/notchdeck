# App Icon Guide

## Concept

The NotchDeck icon should immediately communicate:
- A **notch** (the physical MacBook hardware feature)
- **Multiple agents / status** (colored dots or activity indicators)
- **Control / command deck** feel (structured, purposeful)

## Design Direction

**Recommended concept:** A dark rounded-rect macOS icon background with a stylized notch cutout shape centered, containing 3–5 small glowing colored dots (matching the in-app status colors: blue=working, yellow=needs input, orange=needs permission, green=done).

**Style:** Flat / SF Symbols inspired. Dark background (`#0A0A0A` or deep navy). Notch shape in slightly lighter dark (`#1C1C1E`). Dots with subtle glow.

**Status dot colors to match:**
| State | Color |
|-------|-------|
| Working | `#007AFF` (blue) |
| Needs Input | `#FFD60A` (yellow) |
| Needs Permission | `#FF9F0A` (orange) |
| Done | `#30D158` (green) |
| Failed | `#FF453A` (red) |

## AI Generation Prompt

Use this prompt in Midjourney, DALL·E, or Stable Diffusion:

```
macOS app icon, dark rounded rectangle background, centered notch cutout shape,
3 small glowing colored status dots inside the notch (blue, yellow, green),
flat minimal design, Apple design language, no text, 1024x1024, high quality
```

## Export Pipeline

Once you have a 1024×1024 PNG:

```bash
mkdir NotchDeck.iconset

sips -z 16 16     icon.png --out NotchDeck.iconset/icon_16x16.png
sips -z 32 32     icon.png --out NotchDeck.iconset/icon_16x16@2x.png
sips -z 32 32     icon.png --out NotchDeck.iconset/icon_32x32.png
sips -z 64 64     icon.png --out NotchDeck.iconset/icon_32x32@2x.png
sips -z 128 128   icon.png --out NotchDeck.iconset/icon_128x128.png
sips -z 256 256   icon.png --out NotchDeck.iconset/icon_128x128@2x.png
sips -z 256 256   icon.png --out NotchDeck.iconset/icon_256x256.png
sips -z 512 512   icon.png --out NotchDeck.iconset/icon_256x256@2x.png
sips -z 512 512   icon.png --out NotchDeck.iconset/icon_512x512.png
sips -z 1024 1024 icon.png --out NotchDeck.iconset/icon_512x512@2x.png

iconutil -c icns NotchDeck.iconset
# Output: NotchDeck.icns — drop into Xcode's Assets.xcassets
```

## Resources

- [Apple macOS Icon Design Guidelines](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [Apple Design Resources (icon templates)](https://developer.apple.com/design/resources/)
- [Figma macOS icon kit](https://www.figma.com/community/file/1227200445/macos-app-icon-template)
