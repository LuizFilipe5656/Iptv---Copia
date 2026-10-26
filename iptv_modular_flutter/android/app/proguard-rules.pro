# Flutter Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.plugin.editing.** { *; }

# Flutter Play Store Deferred Components (Optional)
-dontwarn com.google.android.play.core.**

# Better Player Android plugin
-keep class pl.hasoft.better_player.** { *; }
-dontwarn androidx.media3.**

# Sqflite
-keep class com.tekartik.sqflite.** { *; }

# Flutter Secure Storage
-keep class com.it_ne.flutter_secure_storage.** { *; }

# Generated Plugin Registrant
-keep class io.flutter.plugins.** { *; }
