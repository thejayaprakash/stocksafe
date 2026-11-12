# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# Preserve all native methods (critical for JNI in SQLite, Flutter engine, CameraX)
-keepclasseswithmembernames class * {
    native <methods>;
}

# Google ML Kit Text Recognition Rules
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Specifically prevent R8 errors for unbundled optional language packages
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google_mlkit_text_recognition.**

# Mobile Scanner / CameraX
-dontwarn androidx.camera.**
-keep class androidx.camera.** { *; }
-keep class dev.steenbakker.mobile_scanner.** { *; }

# Drift / SQLite native
-keep class androidx.sqlite.db.** { *; }
-keep class androidx.sqlite.** { *; }

# Play Core deferred components (not used by app)
-dontwarn com.google.android.play.core.**

# Speech to Text
-dontwarn com.csdcorp.speech_to_text.**
-keep class com.csdcorp.speech_to_text.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Google Mobile Ads (AdMob)
-keep class com.google.android.gms.ads.** { *; }
-keep class io.flutter.plugins.googlemobileads.** { *; }
-dontwarn com.google.android.gms.ads.**

# In-App Purchase / Play Billing
-keep class com.android.vending.billing.** { *; }
-keep class io.flutter.plugins.inapppurchase.** { *; }
-dontwarn com.android.vending.billing.**

# Printing & Share Plus
-keep class net.nfet.flutter.printing.** { *; }
-keep class dev.fluttercommunity.** { *; }
