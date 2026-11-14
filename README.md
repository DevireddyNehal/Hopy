# Hopy 🚀

> A fast-paced, physics-driven 2D vertical endless platformer built with **Godot 4**. Bounce higher, navigate hazardous ledges, survive unpredictable gameplay modifiers, and avoid plummeting into the abyss.

---

## 🎮 Gameplay Overview

**Hopy** is an arcade-style endless vertical jumper inspired by classic retro platformers like *Doodle Jump*, infused with physics-based steering, screen-wrapping mechanics, dynamic biome transitions, and hilarious real-time modifiers.

Bounce automatically off platforms, collect combo streaks, dodge floating spike mines, and react quickly when screen-warping nausea or inverted controls suddenly kick in!

---

## ✨ Features

- **Responsive Arcade Physics:**
  - Automatic bounce upon landing with juicy squash & stretch animations.
  - Seamless horizontal screen wrapping (go off the left edge to emerge on the right).
  - Progressive speed scaling and dynamic upward camera tracking.

- **Diverse Platform Arsenal:**
  | Platform | Tint | Behavior |
  | :--- | :--- | :--- |
  | **Normal** | Platinum White | Classic reliable bounce platform. |
  | **Moving** | Emerald Green | Patrols horizontally back and forth at dynamic speeds. |
  | **Crumble** | Cracked Basalt | Fractures upon contact and crumbles away after 0.15s. |
  | **Rainbow** | Lavender Crystal | Supercharges your jump with massive vertical lift & fanfare! |
  | **Thorn** | Crimson Red | Instant death upon touching the spiked surface. |
  | **Spike Mines** | Floating Steel Orb | Autonomous floating hazards placed in airspace above 300+ score. |

- **Signature Gameplay Modifiers:**
  - **Drunk Buff (500 pts):** 3-second non-intrusive warning $\rightarrow$ triggers a full-screen liquid wavy nausea shader, camera roll weaving, and a +10% vertical bounce boost for 8 seconds.
  - **Inverted Controls (700 pts):** 3-second siren countdown $\rightarrow$ reverses horizontal steering (`Left` $\leftrightarrow$ `Right`) for 5 intense seconds.
  - **Endless Modifier Cycle:** Beyond 700 points, every 500-point gap (1200, 1700, 2200...) triggers a random modifier challenge.

- **Dynamic Biome Progression:**
  - Palette dynamically shifts as you ascend higher into the cosmos:
    - **0 – 249:** Obsidian Void
    - **250 – 499:** Midnight Slate
    - **500 – 749:** Emerald Horizon
    - **750 – 999:** Twilight Violet
    - **1000+:** Celestial Supernova

- **Rich Audio & Comedy Feedback:**
  - Signature Mac Quack bounce sound with pitch scaling on combos.
  - Dynamic voice stingers & sound effects.
  - Dramatic falling scream when plunging past the lowest visible screen boundary.
  - Laughing cat game-over screen with tiered humorous roasts.

---

## 🕹️ Controls

| Key | Action |
| :--- | :--- |
| `A` / `D` or `←` / `→` | Steer character left / right |
| `Space` | Start game / Instant restart on Game Over |
| `Esc` | Pause / Resume game |
| `F11` | Toggle Fullscreen |

---

## 🚀 Getting Started

### Prerequisites
- **Godot Engine 4.3+** (Tested and verified on Godot 4.7.2 stable)

### Running Locally
1. Clone the repository:
   ```bash
   git clone git@github.com:DevireddyNehal/Hopy.git
   cd Hopy
   ```

2. Open the project in Godot:
   ```bash
   godot --editor .
   ```
   Or launch directly from terminal:
   ```bash
   godot scenes/TitleScreen.tscn
   ```

---

## 🧪 Automated Testing

Hopy includes a comprehensive headless test suite verifying physics, platform mechanics, HUD, game state transitions, and modifier loops.

Run all test suites headless via terminal:
```bash
for test in tests/Test*.tscn; do
    echo "Running $test..."
    godot --headless "$test" >/dev/null || exit 1
done
echo "All test suites passed!"
```

---

## 📦 Exporting & Building

### Web (HTML5 / WebAssembly)
Export preset configured for itch.io and web browser embedding:
```bash
mkdir -p build/web
godot --headless --export-release "Web" build/web/index.html
cd build/web && zip -r ../Hopy-Web.zip . && cd ../..
```

### Linux (x86_64)
```bash
mkdir -p build/linux
godot --headless --export-release "Linux" build/linux/Hopy.x86_64
cd build/linux && zip -r ../Hopy-Linux.zip . && cd ../..
```

---

## 📂 Project Structure

```
├── assets/
│   ├── audio/          # SFX, bounce sounds, and stingers
│   └── sprites/        # Character, platform textures, and backgrounds
├── scenes/
│   ├── Main.tscn       # Core gameplay scene
│   ├── TitleScreen.tscn# Main menu
│   ├── DeathScreen.tscn# Game over & roast interface
│   ├── PauseScreen.tscn# Pause overlay
│   ├── Platform.tscn   # Platform object
│   ├── Robot.tscn      # Player character
│   ├── SpikeBall.tscn  # Floating mine hazard
│   └── HUD.tscn        # Heads-up display & modifier badges
├── scripts/
│   ├── game_state.gd   # Global autoload tracking score, modifiers, & audio
│   ├── robot.gd        # Player physics, squashing, steering, & screen wrap
│   ├── spawner.gd      # Procedural platform & hazard generation
│   ├── platform.gd     # Platform collision, crumble, & boost logic
│   └── camera.gd       # Upward tracking & screen-shake controller
├── shaders/
│   ├── nausea.gdshader # Liquid wavy distortion post-processing
│   └── glitch.gdshader # CRT / aberration visual effects
└── tests/              # 9 Headless integration test suites
```

---

## 📜 License

This project is licensed under the MIT License - feel free to build upon and enjoy!
