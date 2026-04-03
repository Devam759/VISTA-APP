# ── Play Core (Tasks/Deferred Components) ─────────────────────────
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# ── Flutter JNI & Entry point ───────────────────────────────────
-keep class io.flutter.embedding.engine.deferredcomponents.DeferredComponentManager { *; }
-keep class io.flutter.embedding.engine.FlutterJNI { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# ── OkHttp (often used by http/firebase packages) ───────────────
-keepattributes Signature, InnerClasses, EnclosingMethod
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# ── Keep Flutter wrapper classes ─────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── TFLite & ML Kit ───────────────────────────────────────────────
-keep class org.tensorflow.lite.** { *; }
-keep class com.google.mlkit.** { *; }
-keep class io.github.7afe.tflite_flutter.** { *; }
-dontwarn org.tensorflow.lite.**
-dontwarn com.google.mlkit.**
-dontwarn io.github.7afe.tflite_flutter.**
-keep class org.tensorflow.lite.gpu.GpuDelegate { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory$Options { *; }

# ── Firebase ──────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
# Explicitly keep GenericIdpActivity for Microsoft SSO redirects
-keep class com.google.firebase.auth.internal.GenericIdpActivity { *; }
-keep public class com.google.firebase.auth.internal.RecaptchaActivity { *; }

# ── Gson ──────────────────────────────────────────────────────────
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**
