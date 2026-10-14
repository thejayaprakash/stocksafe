# Privacy Policy for StockSafe: Inventory Manager

**Last Updated: October 14, 2026**

StockSafe ("we", "our", or "the app") is committed to protecting your privacy and providing transparent, sovereign data security. Our core promise is: **your inventory data belongs exclusively to you and never leaves your device.** There is no account, no server of ours, and nothing in the app that uploads your catalogue, prices, stock levels or supplier details anywhere.

That promise is about *your business data*, and it is exact. StockSafe is not, however, a network-silent app: it includes Google's ML Kit to read barcodes and packaging labels on your device, and ML Kit brings Google's own diagnostics library with it. Section 1a sets out precisely what that means.

---

## 1. Information Collection and Storage

StockSafe does **NOT** collect, transmit, sell, or monetize your personal or business data. 

- **Local Storage Only:** All inventory catalogs, product details, stock movements, supplier directory entries, audit records, and business settings are stored locally on your device in a private SQLite database. The file lives in StockSafe's private app storage, which Android keeps inaccessible to other apps, and is covered by your device's own disk encryption. StockSafe does not add a separate password or encryption layer of its own.
- **No Cloud Servers / No Accounts:** You do not need to create an account, provide an email address, or sign in to use StockSafe. We operate no remote servers to receive your inventory data.
- **No Ad Networks or Marketing SDKs:** StockSafe contains no advertising networks, no attribution SDKs and no third-party marketing trackers. We do not profile you and we sell nothing.

---

## 1a. What uses the network, and what does not

**Buying Pro uses the network.** StockSafe sells its lifetime unlock through
Google Play Billing, so tapping *Upgrade* or *Restore Purchases* talks to
Google Play. That is how the purchase is remembered against your Google
account — and why reinstalling the app, or moving to a new phone, costs you
nothing.

Google sees the purchase. We do not send them your inventory, and there is no
StockSafe server for any of it to go to. If you would rather not use Play at
all, an offline activation voucher unlocks the app with no network and no
account.

Everything else works with no connection at all: scanning, stock movements,
stocktakes, printing, backups and reports.

## 1b. Google ML Kit, and the network permissions it brings

We would rather state this plainly than let you discover it in the permission list.

StockSafe uses **Google ML Kit** for barcode scanning and for reading MRP, batch and expiry off a packaging label. The recognition itself runs **on your device** - no photo, camera frame or scanned image is uploaded by StockSafe, and the feature works in aeroplane mode.

ML Kit ships with Google's `datatransport` diagnostics library. Including it has two consequences we are obliged to disclose:

- **The app requests `INTERNET` and `ACCESS_NETWORK_STATE`.** Neither is declared by StockSafe's own manifest; both are merged in automatically by that Google library. You will see them if you inspect the app's permissions.
- **Google's ML Kit may report its own diagnostics to Google.** Google's published ML Kit data disclosure states that its SDKs collect device information, app information and performance metrics for diagnostics and usage analytics. That channel belongs to Google, not to us: we neither receive nor have access to anything sent through it, and no inventory data is part of it.

We measured the app's network usage on a test device after installing, launching it and running a full scanning session: Android's per-app traffic accounting recorded **no traffic attributed to StockSafe**. We report that as a measurement, not a guarantee - the diagnostics library batches and schedules its uploads, so an empty window does not prove it never sends anything.

If you want ML Kit's diagnostics gone entirely, the only reliable answer is to remove barcode scanning and label OCR from the app. We have chosen to keep those features and tell you this instead.

---

## 2. Device Permissions Used and Purpose

StockSafe requests only the permissions its features need, plus two that arrive with Google's ML Kit (see section 1a):

| Permission | Technical Name | Purpose |
|---|---|---|
| **Network** | `android.permission.INTERNET`, `android.permission.ACCESS_NETWORK_STATE` | Used for **one thing only: buying or restoring the Pro unlock through Google Play.** That conversation is between your phone and Google; it carries your purchase, not your shop. The permissions are also declared automatically by Google's ML Kit library, which barcode scanning and label OCR depend on. StockSafe has no server of its own, and none of your products, prices, stock levels or supplier details are ever sent anywhere. |
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
