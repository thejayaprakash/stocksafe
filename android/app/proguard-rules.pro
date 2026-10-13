# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

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

# Drift / SQLite native
-keep class androidx.sqlite.db.** { *; }

# Play Core deferred components (not used by app)
-dontwarn com.google.android.play.core.**

# Speech to Text
-dontwarn com.csdcorp.speech_to_text.**
-keep class com.csdcorp.speech_to_text.** { *; }
