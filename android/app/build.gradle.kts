import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 2026-08-25: real release signing, replacing the Flutter template's
// "sign with the debug keys for now" TODO that had survived since the
// project was generated. A debug-signed APK carries
// `CN=Android Debug, O=Android, C=US` as its certificate DN — which is
// what a recipient sees — and every Flutter install on every machine
// shares that one well-known keypair, so it identifies nobody and
// anyone can forge an "update" to it.
//
// The keystore is NEVER in this repository. It is looked for in two
// places, in order, and if neither exists the build FALLS BACK to
// debug signing rather than failing. That fallback is load-bearing:
// GitHub Actions has no keystore, and `release-android.yml` must keep
// producing its sideload APK.
//
//   1. android/key.properties     — the Flutter convention, already
//                                   covered by android/.gitignore
//   2. ~/.config/yswords/secrets/ — where this machine's secrets live
//
// Losing the keystore is unrecoverable: Android refuses an update
// signed with a different key, so a lost key forces every user to
// uninstall and reinstall, losing local data (this app has no cloud
// sync — Firebase was removed at v1.6.62). Hence the mirror at
// ~/Documents/secure-keys-backup/.
val keystoreProperties = Properties().apply {
    val candidates = listOf(
        rootProject.file("key.properties"),
        File(
            System.getProperty("user.home"),
            ".config/yswords/secrets/seeksparks-key.properties",
        ),
    )
    candidates.firstOrNull { it.exists() }?.inputStream()?.use { load(it) }
}
val releaseStoreFile: File? =
    keystoreProperties.getProperty("storeFile")?.let(::File)?.takeIf { it.exists() }

android {
    namespace = "com.example.yahwehswords"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // 2026-05-21 (v1.2.69): flutter_local_notifications uses
        // java.time APIs that need core library desugaring on older
        // Android. Enabled here + dependency added below.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.yahwehswords"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 2026-08-24: app_name is NOT a resValue any more. It lives in
        // res/values*/strings.xml so the home-screen label follows the
        // device language the way iOS's InfoPlist.strings does —
        // 雅伟之剑 on a Chinese device, Yahweh's Swords otherwise.
        // (A resValue also cannot hold an apostrophe: the Kotlin
        // escape \' reaches aapt verbatim and fails the build with
        // "Invalid unicode escape sequence in string".)
    }

    // 2026-05-24 (v1.3.38): product flavors so the international
    // (default) build and the China-mode build can coexist on the
    // same Android device. The `cn` flavor uses
    //   applicationIdSuffix=".cn"  → installs as `com.example.yahwehswords.cn`
    //   resValue app_name="YsWords CN" → distinct home-screen label
    // and is paired at build time with `--dart-define=CHINA_MODE=true`
    // which gates the runtime behavior (Firebase init skipped,
    // Google Fonts options hidden, etc.). Build commands:
    //   intl: flutter build apk --release --flavor intl
    //   cn:   flutter build apk --release --flavor cn --dart-define=CHINA_MODE=true
    flavorDimensions += "region"
    productFlavors {
        create("intl") {
            dimension = "region"
            // applicationId + app_name remain the defaultConfig
            // values; this flavor is just a symmetric label so the
            // build commands look parallel.
        }
        create("cn") {
            dimension = "region"
            applicationIdSuffix = ".cn"
            // The CN coexist build keeps a distinct label so both can
            // sit on one device — see src/cn/res/values*/strings.xml,
            // which overrides app_name for this flavor only.
        }
    }

    signingConfigs {
        if (releaseStoreFile != null) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // See the keystore note at the top of this file. Falls back
            // to the debug key when no keystore is present so CI — which
            // has none — still builds a sideloadable APK; a build that
            // failed there instead would break `release-android.yml`.
            signingConfig = if (releaseStoreFile != null) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "SeekSparks: no release keystore found — signing with " +
                        "the DEBUG key. This APK is for testing only; its " +
                        "certificate DN reads CN=Android Debug.",
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

// 2026-05-21 (v1.2.69): desugar_jdk_libs ships back-ports of java.time
// and other Java 8+ APIs that flutter_local_notifications relies on.
// Required by isCoreLibraryDesugaringEnabled above.
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

