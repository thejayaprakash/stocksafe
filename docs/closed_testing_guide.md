# Closed Testing Guide — 12 Testers × 14 Continuous Days

This guide outlines the compliance protocol required by Google Play for Personal developer accounts created after November 13, 2023.

---

## 1. The Rule

- **12 testers** minimum must opt in to your closed testing track.
- All 12 testers must remain opted in continuously for **14 consecutive days**.
- If a tester opts out or uninstalls and drops the count below 12, Google restarts the 14-day clock from zero.

---

## 2. Setup Step-by-Step

### Step 2.1: Create a Google Group
1. Go to [Google Groups](https://groups.google.com/).
2. Create a group: `stocksafe-closed-testing@googlegroups.com`.
3. Add the Gmail addresses of your 12 to 15 testers (always have 2–3 backups to avoid dropouts).
   - Recommended circle: colleagues, family/friends with Android devices, local shopkeepers, accountants.

### Step 2.2: Link Group in Play Console
1. Open Google Play Console → Select **StockSafe: Inventory Manager**.
2. Navigate to **Testing** → **Closed testing**.
3. Under the track (e.g., *Alpha* or *Closed Test*), go to **Testers** tab.
4. Select **Google Groups** → Add `stocksafe-closed-testing@googlegroups.com`.
5. Copy the **Join on the web** and **Join on Android** opt-in URLs.

### Step 2.3: Tester Onboarding Message
Send the following message to your testers:

> "Hi! Thanks for agreeing to help test StockSafe.
> 1. Click this link to opt into testing: [OPT-IN URL]
> 2. Download and install StockSafe from the Play Store link provided after opting in.
> 3. **CRITICAL:** Please leave the app installed on your phone for 14 continuous days. Even opening it once every couple of days is super helpful!"

---

## 3. High-Priority Testing Scenarios for Testers

| Test Scenario | Goal |
|---|---|
| **Scenario 1: Bulk Catalog Intake** | Have at least 3 testers add 50+ real products using camera barcode scanning, label OCR, or CSV import. |
| **Scenario 2: Device-to-Device Backup Restore** | Have 2 testers export a backup snapshot, send it via WhatsApp or Drive to a second Android device, and restore it. Verify every single product row is identical. |
| **Scenario 3: Zero-Internet Kirana Simulation** | Turn phone on Airplane mode. Perform 20 barcode scans, record inward/outward movements, run a stock audit, and print/share an ESC/POS delivery slip. Confirm zero crashes or network stalls. |
| **Scenario 4: Monetization & Quota Check** | Verify that on product #51 the paywall sheet opens gracefully, explains the ₹499 one-time terms, and allows testing the offline key `PRO2026`. |

---

## 4. 14-Day Readiness Tracking Log

| Day | Milestone | Action Item |
|---|---|---|
| **Day 1** | Track Opt-In | Confirm all 12+ testers have accepted opt-in in Play Console. |
| **Day 3** | Smoke Check | Check Play Console Crashlytics / ANR report (must stay at 0 crashes). |
| **Day 5** | First Update | Push a minor patch via Closed Track to confirm auto-update flow works seamlessly. |
| **Day 8** | Ledger & Valuation Check | Verify large product counts scroll smoothly and inventory valuation recomputes instantly. |
| **Day 11** | Backup Drill | Run the backup restore test on alternative device. |
| **Day 14** | Production Access Application | Play Console will display the banner: *"You've satisfied the 14-day closed testing requirement. You can now apply for production access."* |
