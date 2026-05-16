plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.File
import org.gradle.api.tasks.Exec

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
    compileSdk = 36
    
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
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
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Enable multidex for apps exceeding 65536 methods
        multiDexEnabled = true

        // Reduce APK size by excluding emulator architectures.
        ndk {
            abiFilters.add("arm64-v8a")
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
                "META-INF/androidsupportmultidexversion.txt",
            )
            pickFirsts += setOf(
         "androidsupportmultidexversion.txt"
    )
        }
        jniLibs {
    useLegacyPackaging = true
  pickFirsts += setOf(
            "**/libc++_shared.so",
            "**/libjsc.so"
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

    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
}

// Force Flutter compile tasks to use an explicit absolute flutter.bat path.
tasks.withType<Exec>().configureEach {
    if (name.startsWith("compileFlutterBuild") && !flutterRoot.isNullOrBlank()) {
        val flutterBin = File(flutterRoot, "bin/flutter${if (org.gradle.internal.os.OperatingSystem.current().isWindows) ".bat" else ""}")
        if (flutterBin.exists()) {
            executable = flutterBin.absolutePath
            environment("FLUTTER_ROOT", flutterRoot)
        }
    }
}
configurations.all {
    resolutionStrategy {
        force("androidx.multidex:multidex:2.0.1")
    }
}