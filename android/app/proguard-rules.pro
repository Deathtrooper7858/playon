# Flutter & Engine
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.engine.** { *; }

# AudioService & JustAudio (Essential for notification media buttons and background service)
-keep class com.ryanheise.** { *; }
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.just_audio_background.** { *; }

# AndroidX Media & MediaSessionCompat
-keep class androidx.media.** { *; }
-keep class androidx.media.session.** { *; }
-keep class android.support.v4.media.** { *; }
-keep class android.support.v4.media.session.** { *; }
-keep class * implements androidx.media.session.MediaButtonReceiver { *; }
-keep class android.graphics.drawable.Icon { *; }

# ExoPlayer / Media3
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media3.** { *; }

# Chaquopy Python
-keep class com.chaquo.python.** { *; }

# Suppress warnings for optional Flutter / Play Core deferred components
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-dontwarn androidx.**
-dontwarn org.conscrypt.**

