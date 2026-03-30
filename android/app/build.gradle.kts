import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")

    // Flutter Gradle Plugin must be applied AFTER Android + Kotlin
    id("dev.flutter.flutter-gradle-plugin")

    // Firebase / Google Services
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.knownoknow.ketchup"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.knownoknow.ketchup"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            // Must exist for release builds
            if (!keystorePropertiesFile.exists()) {
                throw GradleException("Missing key.properties at: ${keystorePropertiesFile.absolutePath}")
            }

            val storeFilePath = keystoreProperties["storeFile"] as String?
                ?: throw GradleException("key.properties missing: storeFile")
            storeFile = file(storeFilePath)

            keyAlias = keystoreProperties["keyAlias"] as String?
                ?: throw GradleException("key.properties missing: keyAlias")
            keyPassword = keystoreProperties["keyPassword"] as String?
                ?: throw GradleException("key.properties missing: keyPassword")
            storePassword = keystoreProperties["storePassword"] as String?
                ?: throw GradleException("key.properties missing: storePassword")
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }

        release {
            // ✅ ALWAYS sign release with your upload key (no debug fallback)
            signingConfig = signingConfigs.getByName("release")

            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
