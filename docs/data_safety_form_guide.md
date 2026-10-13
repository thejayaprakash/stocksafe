# Google Play Console — Data Safety Form Submission Guide

This guide provides exact answers to the **Data Safety** questionnaire in Google Play Console for **StockSafe: Inventory Manager**. Because StockSafe is completely offline and does not transmit data, completing this form is straightforward and guarantees rapid review approval.

---

### Step 1: Data Collection and Security

| Question | Answer | Notes |
|---|---|---|
| **Does your app collect or share any of the required user data types?** | **No** | StockSafe operates locally on-device. All inventory and movement data remains in local SQLite. |
| **Is all of the user data collected by your app encrypted in transit?** | **N/A** (or Yes if prompted) | No data is transmitted over the internet to developer servers. |
| **Do you provide a way for users to request that their data be deleted?** | **Yes** | Deleting app data or uninstalling the app deletes all local databases and records immediately. |

---

### Step 2: Specific Data Types Verification

When prompted whether your app collects:
- **Location:** No
- **Personal info (Name, Email, Phone):** No (Suppliers' contacts are entered by the user and stored strictly in their local database; never sent anywhere).
- **Financial info (Credit cards, bank accounts):** No
- **Health and fitness:** No
- **Messages / Emails:** No
- **Photos and videos:** No (Camera is used live via ML Kit for barcode recognition and label text recognition in memory; images are not collected or transmitted).
- **Audio files:** No (Microphone is used in real-time for Speech-to-Text retail commands; no audio files are collected or uploaded).
- **Files and docs:** No
- **Calendar:** No
- **Contacts:** No (StockSafe does not read device address book; supplier contacts are private to the app's local database).
- **App activity:** No
- **Web browsing:** No
- **App info and performance (Crash logs, diagnostics):** No (Diagnostics are stored in a rolling local ring buffer on the phone and only copied manually if the user chooses to export).
- **Device or other IDs:** No

---

### Step 3: Privacy Policy URL

Enter the public URL to your privacy policy (e.g., hosted on GitHub Pages or custom domain):
```text
https://thejayaprakash.github.io/stocksafe/privacy_policy.html
```
*(or point to the raw markdown URL on the GitHub repository).*

---

### Summary for Play Store Reviewer Notes:
> "StockSafe is an offline-first inventory management application for independent retail shops. All product catalog information, stock movements, supplier records, and audit sessions are stored strictly on the user's physical device in local SQLite. The app collects no personal data, transmits no analytics, contains no third-party ad networks, and has no backend server."
