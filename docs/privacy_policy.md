# Privacy Policy for StockSafe: Inventory Manager

**Last Updated: October 13, 2026**

StockSafe ("we", "our", or "the app") is committed to protecting your privacy and providing transparent, sovereign data security. Our core architectural promise is: **your data belongs exclusively to you, and StockSafe operates 100% offline.**

---

## 1. Information Collection and Storage

StockSafe does **NOT** collect, transmit, sell, or monetize your personal or business data. 

- **Local Storage Only:** All inventory catalogs, product details, stock movements, supplier directory entries, audit records, and business settings are stored locally on your device in a private SQLite database. The file lives in StockSafe's private app storage, which Android keeps inaccessible to other apps, and is covered by your device's own disk encryption. StockSafe does not add a separate password or encryption layer of its own.
- **No Cloud Servers / No Accounts:** You do not need to create an account, provide an email address, or sign in to use StockSafe. We operate no remote servers to receive your inventory data.
- **No Third-Party Analytics or Trackers:** StockSafe contains no ad tracking networks, telemetry trackers, or third-party marketing SDKs.

---

## 2. Device Permissions Used and Purpose

StockSafe requests only minimal permissions necessary to execute its retail inventory operations:

| Permission | Technical Name | Purpose |
|---|---|---|
| **Camera** | `android.permission.CAMERA` | Used exclusively to scan product barcodes and capture product packaging labels for on-device ML Kit OCR (detecting MRP, Batch numbers, and Expiry dates). No camera frames or pictures are ever sent over the network. |
| **Microphone / Speech** | `android.permission.RECORD_AUDIO` | Used exclusively when the user explicitly taps the microphone button to dictate retail queries (e.g., checking stock or low-stock items in English or Tamil). Speech processing is handled on-device. |
| **Phone / Dialer** | `android.intent.action.DIAL` | Used solely when you tap the "Call Supplier" button to launch your device's native phone dialer with the supplier's number prefilled. StockSafe never makes calls automatically. |
| **Storage / Files** | Storage Access Framework | Used strictly when you explicitly choose to export or import a backup file or CSV spreadsheet. You pick the destination each time; StockSafe does not read or write anything outside its own storage without your action. |

---

## 3. Data Sovereignty & Backups

You retain total ownership of your data at all times:
- **Verified Local Backups:** You can generate and restore local rolling database backups at any time. Each is checksummed, and StockSafe verifies it before restoring.
- **Portable Backup Files:** You can export a backup as an ordinary `.zip` and keep it wherever you choose. It contains a standard SQLite file, so your records remain readable even without StockSafe.
- **Backup files are not password protected.** Anyone who opens an exported backup can read your stock list, prices, margins and supplier contact details. There is no password because a forgotten one would permanently lock you out of your own backup. Store exported files somewhere only you can reach.
- **Full CSV Data Export:** You can export your entire product catalog, movement history, and valuation metrics as universal CSV/Excel spreadsheets whenever you wish.
- **Data Deletion:** Uninstalling the application or clearing app data deletes all local records immediately — **including any backups held inside the app**. Keep an exported backup file elsewhere if you want your records to survive uninstalling.

---

## 4. Children’s Privacy

StockSafe does not address anyone under the age of 13. We do not knowingly collect personally identifiable information from children.

---

## 5. Changes to This Privacy Policy

We may update our Privacy Policy from time to time. Any updates will be reflected on this page with a revised "Last Updated" date.

---

## 6. Contact Us

If you have questions or suggestions regarding our Privacy Policy, please contact:
- **Developer:** Jayaprakash
- **Email:** support@stocksafe.app
- **Repository:** https://github.com/thejayaprakash/stocksafe
