plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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

