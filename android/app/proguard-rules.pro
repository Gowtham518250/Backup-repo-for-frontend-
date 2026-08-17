# ─────────────────────────────────────────────────────────────────────────
# 🔧 FIX: This project had NO ProGuard/R8 rules file at all, yet the release
# build runs R8 minification (Flutter's Gradle plugin defaults to
# minifyEnabled/shrinkResources = true for release builds). With no app-level
# keep rules, the app relied entirely on auto-merged "consumer" ProGuard
# rules bundled inside each dependency's AAR. That's normally enough — but
# it broke here specifically for Room's generated WorkDatabase (used
# internally by both WorkManager and, per the crash trace,
# com.google.firebase.firestore.f.k -> WorkManagerInitializer -> WorkDatabase).
#
# Root cause: Room generates its actual database/DAO implementation classes
# (e.g. WorkDatabase_Impl) at compile time via annotation processing, and
# instantiates them through reflection at runtime. If R8 renames or strips
# those generated classes (or the SQLite driver classes they depend on)
# because nothing told it they're needed, you get exactly this crash:
# "Failed to create an instance of androidx.work.impl.WorkDatabase" —
# and only in release/minified builds, never in debug, which matches what
# was reported (APK builds and installs, crash is release-specific and
# happens at startup, before Flutter/app code even runs).
# ─────────────────────────────────────────────────────────────────────────

# --- AndroidX Room: keep all generated implementation classes ---
-keep class androidx.room.** { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-keep @androidx.room.Database class * { *; }
-keep @androidx.room.Entity class * { *; }
-keep @androidx.room.Dao class * { *; }
-keepclassmembers class * extends androidx.room.RoomDatabase {
    public <init>();
}
-dontwarn androidx.room.**

# --- AndroidX SQLite: the framework Room's generated code depends on ---
-keep class androidx.sqlite.** { *; }
-dontwarn androidx.sqlite.**

# --- AndroidX WorkManager: keep WorkDatabase and its generated DAOs/entities ---
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class androidx.work.impl.** { *; }
-keep class androidx.work.impl.WorkDatabase { *; }
-keepclassmembers class androidx.work.impl.WorkDatabase { *; }
-dontwarn androidx.work.**

# --- AndroidX Startup: the ContentProvider whose onCreate() is where this crash surfaces ---
-keep class androidx.startup.** { *; }
-dontwarn androidx.startup.**

# --- Firebase Firestore: its internal maintenance tasks use WorkManager directly ---
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# --- General reflection-safety: keep default no-arg constructors used by Room/WorkManager factories ---
-keepclassmembers class * {
    public <init>();
}