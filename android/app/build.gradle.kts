plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.File

// Load local.properties and expose flutterRoot for tasks that need an absolute Flutter path
val localProperties = Properties().apply {
    rootProject.file("local.properties")
        .takeIf { it.exists() }
        ?.inputStream()
        ?.use { load(it) }
}
val flutterRoot: String? = localProperties.getProperty("flutter.sdk") ?: System.getenv("FLUTTER_ROOT")

android {
    namespace = "com.example.bharat_provision"
    compileSdk = 34
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    signingConfigs {
        // Uses `android/key.properties` if present (standard Flutter pattern).
        // Falls back to debug signing so `flutter run --release` still works locally.
        create("release") {
            val keyPropertiesFile = rootProject.file("key.properties")
            if (keyPropertiesFile.exists()) {
                val keyProperties = Properties().apply {
                    keyPropertiesFile.inputStream().use { load(it) }
                }
                storeFile =
                    keyProperties.getProperty("storeFile")?.takeIf { it.isNotBlank() }?.let { file(it) }
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.bharat_provision"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Enable multidex for apps exceeding 65536 methods
        multiDexEnabled = true

        // Reduce APK size by excluding emulator architectures.
        ndk {
            abiFilters.addAll(listOf("arm64-v8a", "armeabi-v7a"))
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )

            val hasReleaseKey = rootProject.file("key.properties").exists()
            signingConfig =
                if (hasReleaseKey) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }

    packaging {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/license.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/notice.txt",
                "META-INF/ASL2.0",
                "META-INF/*.kotlin_module",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

// Add commonly required AndroidX libs
dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
}

// Ensure compileFlutter* tasks can use an absolute flutter binary path when available
tasks.matching { it.name.contains("compileFlutter") }.configureEach {
    doFirst {
        if (!flutterRoot.isNullOrBlank()) {
            val flutterBin = File(flutterRoot, "bin/flutter${if (org.gradle.internal.os.OperatingSystem.current().isWindows) ".bat" else ""}")
            if (flutterBin.exists()) {
                try {
                    // Some Flutter plugin tasks call the `flutter` executable; expose an env var for those tasks
                    if (this is org.gradle.process.ExecSpec) {
                        environment("FLUTTER_BINARY", flutterBin.absolutePath)
                    }
                } catch (_: Exception) {}
            }
        }
    }
}
