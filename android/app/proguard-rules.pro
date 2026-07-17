# Flutter specific
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# App
-keep class com.jleoz.chess.** { *; }

# Play Core (needed by Flutter deferred components)
-keep class com.google.android.play.core.** { *; }

# Enums
-keepclassmembers enum * { *; }

# Serializable
-keep class * implements java.io.Serializable { *; }
