# Hidden Object Adventure (Source Code Repository)

This repository contains the full source code, scripts, UI scenes, privacy policy, and systems for **Hidden Object Adventure** (built in Godot 4+).

---

## 📁 Repository Structure

- **`autoloads/`**: Singletons (`GameManager`, `MusicManager`, `AdManager`, `InAppPurchaseManager`, `SignalHub`)
- **`main/`**: Core game scenes & controllers (`main.tscn`, `main_menu.tscn`, `splash_screen.tscn`)
- **`hud/`**: Interactive HUD components (`bottom_hud.tscn`, `upper_hud.tscn`, `hint_button.tscn`, `drag_scroll.gd`)
- **`levels/`**: Item interaction controllers (`hidden_item.gd`, `hidden_item.tscn`)
- **`addons/`**: AdMob monetization plugin
- **`privacy_policy/`**: Full Google Play compliant Privacy Policy webpage (`index.html`)
- **`project.godot`**: Project configuration file

*(Note: Raw asset binaries, images, and level JSON files are excluded from this source code repository per build specifications).*

---

## 🚀 Git Setup & Initial Commit

To push this repository to GitHub:

```bash
cd "C:\Users\Supreme Traders\Documents\hidden-object-git"
git init
git add .
git commit -m "Initial commit: Hidden Object Adventure source code and privacy policy"
git branch -M main
git remote add origin https://github.com/<YOUR_USERNAME>/hidden-object-git.git
git push -u origin main
```
