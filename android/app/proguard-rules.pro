# Release builds run R8 with resource shrinking, so every class reached
# only through reflection or a platform channel has to be kept by name.

# Flutter engine + plugin registration
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugins.webviewflutter.** { *; }

# Play Core (deferred components / split installs) — referenced by the
# engine but not bundled here.
-dontwarn com.google.android.play.core.**

# Firebase (Messaging resolves handlers reflectively)
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# AppsFlyer
-keep class com.appsflyer.** { *; }
-dontwarn com.appsflyer.**

# Native + Parcelable
-keepclasseswithmembernames class * {
    native <methods>;
}
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Strip Android logging in release
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
