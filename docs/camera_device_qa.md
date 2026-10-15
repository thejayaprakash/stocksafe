# Camera and photos — device QA

Written for: whoever runs the pre-release pass on a physical Android device.

Scanning and product photos are the parts of StockSafe that cannot be proven
by the test suite. `MobileScanner` needs a real camera, `analyzeImage` is
Android- and physical-iOS-only, the image picker is a separate activity with
its own permissions, and the behaviour that matters most — the camera being
released when it should be — only shows up as a symptom on hardware, usually
in the *next* app that tries to open the camera.

Everything below is unverified until someone ticks it on a device. The code
paths exist and the suite covers what it can; that is not the same claim.

## Before you start

- A physical Android device, not an emulator. The emulator's fake camera will
  pass checks that a real sensor fails.
- A release or profile build, so the ML Kit model is bundled the way users
  get it.
- At least one real barcode to hand: a packaged product, not a code on a
  screen. Screens introduce moiré and backlight that a printed label does not.
- One product in the catalogue whose barcode you know, and one barcode that
  is **not** in the catalogue.

## Camera lifecycle

The failure here is a camera left held. It shows as a black preview on
return, a torch that stays lit, or another app being unable to open the
camera until StockSafe is force-stopped.

- [ ] Open Scan. The preview appears within about a second.
- [ ] Press Home, wait five seconds, return. The preview is live again, not
      black or frozen.
- [ ] Open the recents switcher, move to another app, come back. Same.
- [ ] Open a different camera app while StockSafe is backgrounded, then
      return to StockSafe. The preview recovers.
- [ ] Turn the torch on, then background the app. The torch goes out.
- [ ] Rotate the device with the preview open. No crash, no stretched frame.
- [ ] Leave Scan with the back arrow. Open the system camera app
      immediately — it opens. (This is the one that catches a leaked camera.)
- [ ] Open and leave Scan ten times in a row. The tenth is as quick as the
      first and memory has not climbed.

## Permissions

- [ ] First launch after install: the permission prompt appears when Scan is
      opened, not before.
- [ ] Deny the permission. The screen explains itself and offers **Retry**
      and **Type Barcode** rather than a blank or a crash.
- [ ] With the permission denied, **Type Barcode** still finds a product.
- [ ] Grant the permission from Android settings and return. **Retry** brings
      the preview up without restarting the app.
- [ ] Choose "Only this time", then background and return. Behaviour is
      sane — either the preview recovers or the error state appears.

## Scanning through the lens

- [ ] A barcode already in the catalogue opens that product.
- [ ] A barcode that is not opens Add Product with the code pre-filled.
- [ ] Every scan beeps **and** vibrates. Shopkeepers scan without looking at
      the screen; this is the feedback that tells them it worked.
- [ ] The same code scanned twice quickly does not register twice.
- [ ] A damaged or partly covered label fails quietly — no crash, no
      incorrect product.
- [ ] In a dim room, the torch makes the difference between a read and a
      miss.

## Batch scanning

- [ ] The middle control switches to batch and the pill shows the running
      count.
- [ ] Scanning several products builds the tray; quantities increment for
      repeats.
- [ ] The plus and minus controls in the tray change quantities, and removing
      the last of an item drops it.
- [ ] **Stock In** applies to every item in the tray, and the ledger shows one
      movement per product.
- [ ] **Stock Out** likewise.
- [ ] Switching back to single scan mid-tray does not lose the tray.

## Gallery scan

This is the newest path and the least exercised.

- [ ] Photograph a barcode, then read it through **Gallery**. The product
      opens exactly as a live scan would.
- [ ] Cancel the picker without choosing anything. Nothing is said, and the
      camera preview comes back.
- [ ] Pick a photo with no barcode in it. "No barcode found in that picture",
      and the preview comes back.
- [ ] Pick a very large photo (12MP or more). It completes or fails cleanly;
      it does not hang.
- [ ] Pick a screenshot containing a barcode.
- [ ] Deny the gallery permission. The failure is explained, not silent.
- [ ] Tap **Gallery** twice quickly. Only one picker opens.
- [ ] In batch mode, a code read from the gallery lands in the tray rather
      than opening the product.
- [ ] While the picker is open, the camera is not also running — check the
      camera indicator in the status bar.

## Product photos

Capture shares `image_picker` with the gallery scan, so the permission and
lifecycle risks are the same ones again — but the storage behaviour is new.

- [ ] Add a product, take a photo with the camera, save. It shows on the
      product page and on the grid tile.
- [ ] Add a photo from the gallery instead. Same.
- [ ] Replace a photo. The **new** one appears immediately. (Seeing the old
      one for a few seconds is the image cache, and it is a bug.)
- [ ] Remove a photo. The tinted initial comes back.
- [ ] Take a photo, then leave the form with back rather than Save. The
      product has no photo, and the file is not left behind — check the
      app's storage size before and after.
- [ ] Cancel the camera without taking anything. Nothing is said and the
      form is unchanged.
- [ ] Deny the camera permission at the prompt. The failure is explained,
      and the form still saves without a photo.
- [ ] Photograph something with a lot of detail and check the stored size is
      in the low hundreds of KB, not megabytes. Settings › Apps › StockSafe ›
      Storage is the quickest way to watch it grow.
- [ ] Add photos to twenty products. The catalogue still scrolls smoothly,
      and app storage has grown by a few MB, not tens.

## Photos through a backup

This is the one that cannot be checked on a single device, and the one most
worth doing: photo paths are stored relative to the app's directory
precisely so that a restore onto a different phone finds them.

- [ ] Photograph several products, export a backup, and check the .zip size
      looks sensible for the number of photos.
- [ ] Open the .zip on a computer. The photos are in `images/`, and
      `README.txt` reports the right count.
- [ ] **Restore that backup onto a second device**, or onto the same device
      after an uninstall and reinstall. Every photo is still there.
- [ ] Restore a backup made *before* photos existed. It imports cleanly and
      every product falls back to its tinted initial.
- [ ] Import an archive, then check a product whose photo failed to write
      (delete one from the zip first). That product shows its initial; the
      rest of the import is unaffected.
- [ ] Export, delete a photo from the app, re-import the archive. The photo
      comes back.

## Offline

The whole point of this app. Run these in aeroplane mode with Wi-Fi off.

- [ ] Live scanning works.
- [ ] Gallery scanning works.
- [ ] Adding a product from an unknown barcode works.
- [ ] Taking and saving a product photo works.
- [ ] Exporting and importing a backup containing photos works.
- [ ] Nothing anywhere in the flow waits on a network or shows a connection
      error.

## What to record

For anything that fails, note the device model, the Android version, and
whether it was a debug, profile or release build — the camera stack differs
enough between manufacturers that "it worked on mine" settles nothing.
