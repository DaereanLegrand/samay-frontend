import java.io.File
// Must be imported (not `java.util.Properties()`): once the google-services
// plugin is applied, the `java` extension accessor is in scope and Kotlin parses
// `java.util` as `(java).util` → "Unresolved reference 'util'".
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Firebase (FCM). Reads android/app/google-services.json — the build fails
    // if that file is missing. Version is declared in settings.gradle.kts.
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Release signing — §3.3 keystore env contract (M-27, mirrors the M-18
// fastlane guard semantics) ──────────────────────────────────────────────────
// The keystore is NEVER in the repo (android/app/keystores/ is absent; *.jks
// is gitignored; DEPLOYMENT-PLACEHOLDER.md §3.3 row R22). The four
// ANDROID_KEYSTORE_* env vars are the ONLY signing source:
//   - ALL FOUR set  → the release buildType signs with the keystore.
//   - ANY unset     → release builds FAIL FAST at task time with a clear
//                     message. Release NEVER falls back to the debug key.
// File-first: KEYSTORE_PROPERTIES points at a RAM-disk keystore.properties
// (written by tools/release-signing-not-in-repo.sh). Env vars remain as a fallback for the
// existing §3.3 contract. Release still fails fast when nothing is configured.
val keystoreProps = Properties().apply {
    System.getenv("KEYSTORE_PROPERTIES")?.let { p ->
        File(p).takeIf(File::isFile)?.inputStream()?.use { load(it) }
    }
}
fun ksProp(key: String, env: String): String? =
    keystoreProps.getProperty(key) ?: System.getenv(env)

val keystoreEnv = mapOf(
    "ANDROID_KEYSTORE_PATH" to ksProp("storeFile", "ANDROID_KEYSTORE_PATH")?.let { v ->
        val p = System.getenv("KEYSTORE_PROPERTIES")
        if (!v.startsWith("/") && p != null) File(File(p).parentFile, v).absolutePath else v
    },
    "ANDROID_KEYSTORE_ALIAS" to ksProp("keyAlias", "ANDROID_KEYSTORE_ALIAS"),
    "ANDROID_KEYSTORE_PASSWORD" to ksProp("storePassword", "ANDROID_KEYSTORE_PASSWORD"),
    "ANDROID_KEY_ALIAS_PASSWORD" to ksProp("keyPassword", "ANDROID_KEY_ALIAS_PASSWORD"),
)
val releaseSigningConfigured = keystoreEnv.values.all { !it.isNullOrBlank() }

android {
    namespace = "com.qallariy.samay"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        // Gradle 9 turns Kotlin-DSL deprecation warnings into compile errors:
        // the legacy `kotlinOptions` DSL is rejected, so the compilerOptions
        // DSL is the required form (kotl.in/u1r8ln). JVM target must mirror
        // the compileOptions above.
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.qallariy.samay"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Per-environment flavors. Every flavor keeps applicationId
    // "com.qallariy.samay" (set in defaultConfig) — an applicationIdSuffix would
    // break the OAuth Android client (its package name must match) and the
    // Play/App Store identity. Only one flavor is installable at a time.
    // Each flavor resolves its own android/app/src/<flavor>/google-services.json
    // (com.google.gms.google-services reads the variant source set); a flavor
    // with no file fails the build — there is no shared fallback.
    // The "dev" flavor is the shared testing environment: AGP reserves product
    // flavor names starting with "test", so the testing env's flavor is "dev".
    flavorDimensions += "env"
    productFlavors {
        create("dev") { dimension = "env" }
        create("staging") { dimension = "env" }
        create("prod") { dimension = "env" }
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                storeFile = file(keystoreEnv.getValue("ANDROID_KEYSTORE_PATH")!!)
                storePassword = keystoreEnv.getValue("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = keystoreEnv.getValue("ANDROID_KEYSTORE_ALIAS")
                keyPassword = keystoreEnv.getValue("ANDROID_KEY_ALIAS_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Debug builds keep the default debug signing; the release
            // buildType NEVER signs with the debug key (see the guard below).
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = null
            }
        }
    }
}

// Fail-fast guard (always registered): with any §3.3 keystore env unset, or
// the keystore file missing at ANDROID_KEYSTORE_PATH, every release-packaging
// task dies before producing an unsigned artifact. Message mirrors the M-18
// fastlane guard ("credentials not configured" contract) — release builds
// must never silently fall back to debug signing.
val releaseKeystoreFile: File? =
    keystoreEnv["ANDROID_KEYSTORE_PATH"]?.let { if (it.isBlank()) null else File(it) }
tasks.matching {
    it.name == "assembleRelease" || it.name == "bundleRelease" ||
        it.name.startsWith("packageRelease")
}.configureEach {
    doFirst {
        val missing = keystoreEnv.filterValues { it.isNullOrBlank() }.keys
        if (missing.isNotEmpty()) {
            throw GradleException(
                "Android release signing is not configured: set the §3.3 keystore envs " +
                    "ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_ALIAS, ANDROID_KEYSTORE_PASSWORD, " +
                    "ANDROID_KEY_ALIAS_PASSWORD (see <private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md §3.3 / R22). " +
                    "Release builds NEVER fall back to the debug key."
            )
        }
        if (releaseKeystoreFile == null || !releaseKeystoreFile.isFile) {
            throw GradleException(
                "Android release signing keystore not found at " +
                    "'${keystoreEnv["ANDROID_KEYSTORE_PATH"]}' (ANDROID_KEYSTORE_PATH). " +
                    "Generate + keep the .jks in a secret store — never in the repo " +
                    "(<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md §3.3 / R22)."
            )
        }
    }
}

flutter {
    source = "../.."
}

// Firebase Android BoM — aligns any `com.google.firebase:*` artifacts on one
// version. FlutterFire pulls its own versions, so nothing is required here
// today; add unversioned native artifacts (e.g. firebase-messaging) if needed.
dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.19.0"))
}
