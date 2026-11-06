import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: create android/key.properties (never commit it) with
//   storePassword=…  keyPassword=…  keyAlias=upload  storeFile=/absolute/path/parker-upload.jks
// or set the same values as environment variables (CI): PWP_KEYSTORE_PATH,
// PWP_KEYSTORE_PASSWORD, PWP_KEY_ALIAS, PWP_KEY_PASSWORD.
// Without either, release builds fall back to the debug key (fine for testing only).
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}
val releaseStoreFile: String? = keyProps.getProperty("storeFile") ?: System.getenv("PWP_KEYSTORE_PATH")

android {
    namespace = "`in`.parkerwater.parker_orders"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "`in`.parkerwater.parker_orders"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseStoreFile != null) {
            create("release") {
                storeFile = file(releaseStoreFile)
                storePassword = keyProps.getProperty("storePassword") ?: System.getenv("PWP_KEYSTORE_PASSWORD")
                keyAlias = keyProps.getProperty("keyAlias") ?: System.getenv("PWP_KEY_ALIAS")
                keyPassword = keyProps.getProperty("keyPassword") ?: System.getenv("PWP_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseStoreFile != null) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
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
