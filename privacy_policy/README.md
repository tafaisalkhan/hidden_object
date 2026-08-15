# 🔒 Privacy Policy Hosting (GitHub Pages)

This folder contains the complete, Google Play Store compliant **Privacy Policy** for **Hidden Object Adventure**.

---

## 🚀 How to Host on GitHub Pages (Free Live URL)

### Option 1: Deploy from a New Dedicated Repository

1. Open your terminal inside this `privacy_policy` folder:
   ```bash
   cd "C:\Users\Supreme Traders\Documents\difference-find\privacy_policy"
   ```
2. Initialize Git and commit:
   ```bash
   git init
   git add .
   git commit -m "Initial commit: Google Play Privacy Policy"
   ```
3. Create a public repository on GitHub (e.g. `hidden-object-privacy-policy`) and push:
   ```bash
   git remote add origin https://github.com/<YOUR_USERNAME>/<REPO_NAME>.git
   git branch -M main
   git push -u origin main
   ```
4. On GitHub, go to **Settings ➔ Pages**:
   - Source: **Deploy from a branch**
   - Branch: `main` / `/ (root)`
   - Click **Save**.
5. Your live privacy policy URL will be:
   ```
   https://<YOUR_USERNAME>.github.io/<REPO_NAME>/
   ```
6. Paste this URL into your **Google Play Console ➔ App content ➔ Privacy policy**.

---

## 📋 Sections Covered in this Privacy Policy:
- Information Collection & Offline Gameplay
- Google Play Services integration
- Google AdMob (Ad identifiers, advertising policies)
- Google Play In-App Billing (Remove Ads purchases)
- COPPA Compliance (Children's Privacy)
- User Choices & Opt-Out mechanisms
