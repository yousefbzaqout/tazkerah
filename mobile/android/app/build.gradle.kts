plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.tazkerah.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Core library desugaring was removed alongside
        // flutter_local_notifications in the dependency audit. Phase 6 must
        // restore both together — that plugin fails the AAR metadata check
        // without it (see the coreLibraryDesugaring dependency below).
    }

    defaultConfig {
        // Permanent once published: Play will not accept a different id for
        // this listing afterwards, and changing it ships a second app rather
        // than an update. Matches the iOS bundle identifier and the
        // tazkerah.app domain that App Links verify against.
        applicationId = "app.tazkerah.mobile"
        // Inherits Flutter's default, currently 24. That already clears the
        // API 23 floor that flutter_secure_storage needs for
        // EncryptedSharedPreferences and that the hardware-backed Keystore
        // wants. If this is ever lowered, check both before doing so.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// Phase 6, when flutter_local_notifications returns, needs both of these back:
//
//   compileOptions { isCoreLibraryDesugaringEnabled = true }
//   dependencies {
//       coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
//   }
//
// Without them the build fails at :app:checkDebugAarMetadata rather than at
// compile time, which is a confusing error to meet cold.
