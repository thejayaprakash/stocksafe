# Release signing

StockSafe release builds were signed with the Android **debug** keystore
(audit C-01). That file ships with the SDK: the same key, with the password
`android`, on every machine in the world. Google Play rejects uploads signed
with it, and had such a build ever reached users, anyone could have signed a
malicious update that Android would accept in its place.

This is now wired to a real key. Nothing here needs a Play Console account —
that is only required to publish.

## One-time setup

### 1. Create the keystore

```bash
keytool -genkey -v -keystore ~/keystores/stocksafe-upload.p12 \
  -storetype PKCS12 -keyalg RSA -keysize 2048 -validity 10000 \
  -alias stocksafe
```

It asks for a password and your name and organisation. The 10,000-day validity
is the Play recommendation — a key that expires before your app does is a
problem you cannot fix later.

PKCS12 rather than JKS: `keytool` warns that JKS is a proprietary format and
tells you to migrate. Gradle accepts either, so there is no reason to start on
the one that prints a warning.

**Store it outside the repository.** `android/.gitignore` already excludes
`key.properties`, `*.jks` and `*.keystore`, but a path outside the working tree
removes the question entirely.

### 2. Point Gradle at it

```bash
cp android/key.properties.example android/key.properties
```

Fill in `storeFile`, `storePassword`, `keyAlias` and `keyPassword`.

### 3. Check it worked

```bash
flutter build apk --release
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

The certificate DN must show **your** details. If it says
`C=US, O=Android, CN=Android Debug`, `key.properties` was not picked up — the
build also prints a warning in that case.

## Losing the key

Since August 2021 every new app on Play must use **Play App Signing**: Google
generates and holds the key that actually signs what users install, and the key
you created above becomes your *upload key*, which only proves an upload came
from you.

That distinction matters. **If you lose an upload key, Google can reset it.**
Under the older model, where the developer held the real signing key, losing it
ended the app — no updates, ever, and a new listing under a new package name
with every install and review gone.

So you are in the recoverable case. Back the file up anyway; a reset is support
correspondence you would rather not have.

## Application ID

`app.stocksafe.inventory`, set in `android/app/build.gradle.kts`.

**This can never change after the first upload.** Play ties the listing, the
signing key, every install and every review to it. It was previously
`com.example.stocksafe`, which Play rejects outright.

## CI

The `release` job builds unsigned-for-publication artifacts, because
`key.properties` is not in the repository. To produce a publishable AAB in CI,
add the keystore as a base64 GitHub secret, decode it during the job, and write
`key.properties` from secrets. Do not commit either.
