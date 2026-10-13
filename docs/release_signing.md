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

**Store it outside the repository.** `key.properties` and every keystore
extension (`.jks`, `.keystore`, `.p12`, `.pfx`) are gitignored repository-wide,
but a path outside the working tree removes the question entirely — a file that
is not there cannot be committed by any mistake.

### 2. Point Gradle at it

```bash
cp android/key.properties.example android/key.properties
```

Fill in `storeFile`, `storePassword`, `keyAlias` and `keyPassword`.

Two things that cost an afternoon if you get them wrong:

- **`keyPassword` must equal `storePassword`.** A PKCS12 keystore has no
  separate key password — `keytool` forces them to match — but Gradle still
  reads both fields. Different values fail at signing with an error that does
  not explain itself.
- **Use forward slashes in `storeFile`, including on Windows.** Gradle reads
  this as a Java properties file, where a backslash escapes the next
  character, so `C:\keys\x.p12` silently becomes `C:keysx.p12`.

### 3. Check it worked

```bash
flutter build apk --release
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

The certificate DN must show **your** details. If it says
`C=US, O=Android, CN=Android Debug`, `key.properties` was not picked up.

### Building a release without a keystore

With no `android/key.properties`, a release build now **fails**:

```
Refusing to build a release artifact with the debug signing key.
```

Testers still need release builds on machines with no signing material, so the
fallback is available — by name:

```bash
flutter build apk --release -PallowDebugSigning=true
```

Never publish or distribute the result. It is signed with the public Android
debug key: the same file, with the same password, on every machine in the world.

This used to be the default behaviour with only a `logger.warn()` to mark it.
Gradle prints hundreds of lines, CI scrolled past the warning, and the workflow
then uploaded the artifact under the name `StockSafe-release-apk` — which read
like something you could ship.

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

The `release` job builds artifacts that are **not publishable**, because
`key.properties` is not in the repository. It passes `-PallowDebugSigning=true`
explicitly and names its outputs `StockSafe-TESTING-ONLY-debug-signed-*`, so
nobody downloads one expecting to upload it.

To produce a publishable AAB in CI, add the keystore as a base64 GitHub secret,
decode it during the job, and write `key.properties` from secrets. Do not commit
either.

## The launch gate

`test/release_readiness_test.dart` asserts the things that are permanent once
the app is on Play, or that silently yield a build nobody should publish: the
application ID, that the namespace matches it, that a release cannot fall back
to the debug key unasked, that no keystore is in the working tree, and that the
voucher secret is not the development placeholder.

It is tagged `release` and excluded from the ordinary suite, because the
voucher-secret check only passes when given the real secret. Run it before an
upload:

```bash
flutter test --tags release \
  --dart-define=STOCKSAFE_VOUCHER_SECRET="$STOCKSAFE_VOUCHER_SECRET"
```

Or run the **Launch Gate** job from the Actions tab, which needs
`STOCKSAFE_VOUCHER_SECRET` set as a repository secret.

### Before the first upload

- [ ] Keystore created, backed up in two places, passwords in a password manager
- [ ] `android/key.properties` filled in locally and **not** committed
- [ ] Play App Signing enrolment accepted on the first upload
- [ ] `flutter test --tags release` passes with the real voucher secret
- [ ] Release APK installed on a physical device and smoke-tested
