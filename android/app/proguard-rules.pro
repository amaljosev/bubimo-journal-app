# Suppress missing class warnings for Flutter dynamic Play Store deferred components
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# file_picker pulls in Apache Tika transitively for MIME detection.
# Tika references several javax.xml.stream / javax.activation /
# org.apache.commons.logging classes that exist on desktop JVMs but
# not on Android — they're never actually exercised at runtime on
# mobile, so we just tell R8 not to fail the build over them.
-dontwarn javax.xml.stream.**
-dontwarn javax.xml.bind.**
-dontwarn javax.activation.**
-dontwarn org.apache.commons.logging.**
-dontwarn org.apache.tika.**
-dontwarn org.osgi.**
-dontwarn org.slf4j.**

# AdMob Keep Rules
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }

# Flutter plugin embedding — R8 can strip the generated plugin
# registrant / GeneratedPluginRegistrant references without this,
# causing plugins to silently fail to register in release builds.
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.embedding.** { *; }

# Google Sign-In / Play Services Auth
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.signin.** { *; }

# WorkManager relies on Room-generated database implementation
# classes (WorkDatabase and its DAOs/entities) that R8 will strip or
# rename without an explicit keep rule, causing a crash at app start
# via androidx.startup.InitializationProvider before Dart code runs.
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
-keep class * extends androidx.room.RoomDatabase
-keep @androidx.room.Entity class *
-keep @androidx.room.Dao class *
-keepclassmembers class * extends androidx.room.RoomDatabase {
    public static <fields>;
}
-dontwarn androidx.work.**
-dontwarn androidx.room.**

# sqflite
-keep class com.tekartik.sqflite.** { *; }

# Supabase / gotrue / postgrest / realtime rely on Dart-side
# reflection-free codegen, but the underlying platform channel /
# http client classes still need to survive shrinking.
-keep class io.supabase.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Keep Play Core split install classes referenced by Flutter's deferred
# component support (you already suppress warnings for these — this
# ensures the classes that DO exist aren't stripped from being found).
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }