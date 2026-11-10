# Google Play Console — Data Safety Form Submission Guide

This guide provides exact answers to the **Data Safety** questionnaire in Google Play Console for **StockSafe: Inventory Manager**.

StockSafe is offline-first: the shop's data lives on the device and is never
transmitted. Two things do reach the network, and both are Google's own code
rather than ours — the bundled ML Kit diagnostics library, and **Google Play
Billing**, which handles buying and restoring the Pro unlock.

Neither carries the user's business data. Note that the purchase itself is
processed by Google as the seller of record: the app stores only the resulting
order id, on the device, and transmits it nowhere.

---

### Step 1: Data Collection and Security

| Question | Answer | Notes |
|---|---|---|
| **Does your app collect or share any of the required user data types?** | **Yes** | Not StockSafe's own code, which transmits nothing. The bundled Google ML Kit SDK collects diagnostics - see the App info and performance entry below. Google's Data Safety rules make you declare what a third-party SDK collects as though you collected it. |
| **Is all of the user data collected by your app encrypted in transit?** | **Yes** | The only transmission is Google ML Kit's own diagnostics, sent over HTTPS by Google's library. StockSafe sends nothing of its own. |
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
- **App info and performance (Crash logs, diagnostics):** **Yes - collected, not shared with us.** Two separate things sit under this heading, and only the second is declarable:
  - *StockSafe's own diagnostics* stay in a rolling local ring buffer on the phone, and leave only if the user exports them by hand or sends a problem report. The problem report is counts and health only - no product names, barcodes, prices, stock levels or supplier details - and the user sees the whole payload before choosing an app to send it with.
  - *Google ML Kit's diagnostics.* Barcode scanning and label OCR depend on ML Kit, which bundles Google's `datatransport` library. Google's published ML Kit data disclosure states its SDKs collect device information, app information and performance metrics for diagnostics and usage analytics. That library also merges `INTERNET` and `ACCESS_NETWORK_STATE` into the app. Purpose: **App functionality / Analytics**. Collected, **not** shared with the developer - we never receive it. **Not** user-tied in any way we control.

  Measured on a test device after install, launch and a full scanning session: Android's per-app traffic accounting attributed **no traffic to StockSafe**. Recorded as a measurement, not a guarantee - the library batches and schedules uploads, so an empty window proves nothing either way. Declared on the conservative side.
- **Device or other IDs:** **Yes (Advertising ID / AD_ID for optional Rewarded Ads)**
  - Google Mobile Ads SDK (AdMob) uses the Google Play Advertising ID to serve voluntary rewarded advertisements (earning product capacity) and prevent fraud.
  - Purposes: **Advertising or marketing**, **Fraud prevention, security, and compliance**.
  - Encrypted in transit: **Yes** (HTTPS).
  - Required vs Optional: **Optional** (only used when user voluntarily chooses to watch a rewarded ad to earn extra product slots).

---

### Step 3: Privacy Policy URL

Enter the public URL to your privacy policy (e.g., hosted on GitHub Pages or custom domain):
```text
https://thejayaprakash.github.io/stocksafe/privacy_policy.html
```
*(or point to the raw markdown URL on the GitHub repository).*

---

### Summary for Play Store Reviewer Notes:
> "StockSafe is an offline-first inventory management application for independent retail shops. All product catalog information, stock movements, supplier records, and audit sessions are stored strictly on the user's physical device in local SQLite. There is no backend server and no ad network, and none of the user's business data is transmitted anywhere. The app reaches the network for exactly two reasons, both Google's own code: the bundled ML Kit diagnostics library, and Google Play Billing for purchasing or restoring the one-time Pro unlock.
>
> The app bundles Google ML Kit for on-device barcode scanning and label OCR. Recognition runs locally and no image is uploaded by us, but ML Kit brings Google's datatransport diagnostics library, which merges the INTERNET and ACCESS_NETWORK_STATE permissions into the app and may report its own device and performance diagnostics to Google. We declare that under App info and performance. We do not receive it, and no inventory data forms part of it."

**Why this changed.** An earlier draft declared diagnostics as "No" and stated the app "transmits no analytics". That was accurate about StockSafe's own code and wrong about the app as shipped: the manifest merger pulls `INTERNET` and `ACCESS_NETWORK_STATE` in from `com.google.android.datatransport:transport-backend-cct`, reached via `google_mlkit_commons`, and the release manifest carries `MlKitInitProvider`, `CctBackendFactory` and an upload scheduler that start with the app. An inaccurate Data Safety declaration is a policy violation on its own, regardless of whether anything is actually sent - so this is declared on the conservative side.
