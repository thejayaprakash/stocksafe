import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials, kept out of the repository.
// Copy android/key.properties.example to android/key.properties and fill it in;
// android/.gitignore already excludes key.properties, *.jks and *.keystore.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "app.stocksafe.inventory"
    compileSdk = 36
    // ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Permanent. Google Play ties the listing, the signing key, every
        // install and every review to this string, and it can never be changed
        // after the first upload. Reverse-DNS of stocksafe.app.
        applicationId = "app.stocksafe.inventory"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Signed with the real key when android/key.properties exists,
            // otherwise with the debug key so `flutter run --release` still
            // works on a fresh clone.
            //
            // The debug keystore ships with the Android SDK: same file, same
            // password ("android"), on every machine in the world. A build
            // signed with it cannot be uploaded to Play, and if it ever
            // reached users anyone could sign a malicious update that Android
            // would accept in its place. Never publish one.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "WARNING: no android/key.properties found - signing the " +
                    "release build with the PUBLIC DEBUG KEY. This build must " +
                    "not be published or distributed."
                )
                signingConfigs.getByName("debug")
            }

            // proguardFiles was declared but isMinifyEnabled was never set, so
            // R8 never ran and the rules below had no effect: release builds
            // shipped with full class and method names, and nothing was
            // shrunk.
            //
            // What this does NOT do: protect the offline-voucher HMAC secret.
            // R8 obfuscates Java and Kotlin bytecode. Dart is compiled ahead
            // of time into libapp.so, and its string literals survive intact —
            // verified by byte-searching a release APK, where the secret is
            // found in plain UTF-8. `--obfuscate` would rename Dart symbols
            // but not literals either. The voucher scheme is honest about
            // this (see LicenseKey): it deters sharing and guessing, and Play
            // Billing is the answer to anything stronger.
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
