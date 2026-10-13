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

// Opt-in escape hatch for building a release APK with no signing material,
// which testers need for the release-build scenarios in
// docs/closed_testing_guide.md. Asked for by name so it cannot happen by
// accident:  flutter build apk --release -PallowDebugSigning=true
val allowDebugSigning = (project.findProperty("allowDebugSigning") as String?) == "true"

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
            //
            // A warning is not enough. Gradle prints hundreds of lines and CI
            // scrolls past all of them, so "must not be published" sat in the
            // log while the workflow uploaded the artifact under the name
            // StockSafe-release-aab. The fallback is still available — testers
            // need it — but it now has to be asked for by name:
            //
            //     flutter build apk --release -PallowDebugSigning=true
            //
            // Without the flag, a release build with no keystore fails. See
            // the task-graph check below.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
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

// Fails a release build that would be signed with the debug key, at the point
// one is actually requested.
//
// The check lives here rather than in the `release { }` block because that
// block is configured for every build, including debug ones — throwing inside
// it would break `flutter run`. Keyed on the task graph, it is inert until
// something actually asks for a release artifact.
gradle.taskGraph.whenReady {
    val buildingRelease = allTasks.any { task ->
        task.name.contains("Release") && (
            task.name.startsWith("assemble") ||
                task.name.startsWith("bundle") ||
                task.name.startsWith("package")
            )
    }
    if (buildingRelease && !hasReleaseKeystore && !allowDebugSigning) {
        throw GradleException(
            """
            |
            |Refusing to build a release artifact with the debug signing key.
            |
            |android/key.properties was not found. The debug keystore ships with
            |the Android SDK — same file, same password, on every machine — so
            |Play rejects anything signed with it, and if such a build reached
            |users, anyone could sign an update Android would accept over it.
            |
            |To build a real release:  see docs/release_signing.md
            |To test a release build:  flutter build apk --release -PallowDebugSigning=true
            |                          (never publish or distribute the result)
            """.trimMargin()
        )
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
