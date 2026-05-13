# Flutter local notifications — Gson TypeToken fix.
# R8/ProGuard strips generic type signatures which breaks Gson's TypeToken
# deserialization used internally by flutter_local_notifications.
-keepattributes Signature
-keepattributes *Annotation*

# Keep all flutter_local_notifications plugin classes intact
-keep class com.dexterous.** { *; }

# Keep Gson TypeToken and all subclasses so generic type info survives R8
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# Keep Gson core
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# Firebase / Firestore
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Flutter engine
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
