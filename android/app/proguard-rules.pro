# Flutter's Gradle plugin enables R8 code shrinking for release builds. The
# rules below keep what release-mode R8 would otherwise strip and break.

# --- flutter_local_notifications ---------------------------------------------
# The plugin persists scheduled notifications by serializing its model classes
# with Gson. R8 strips the generic type signatures Gson relies on, which fails
# at runtime with "Missing type parameter" when it reloads them. Keep the
# plugin's classes and preserve generic/annotation metadata.
-keep class com.dexterous.** { *; }
-keepclassmembers class com.dexterous.** { *; }

# --- Gson --------------------------------------------------------------------
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses,EnclosingMethod
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
