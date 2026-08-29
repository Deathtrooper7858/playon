plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.chaquo.python")
}

android {
    namespace = "com.example.playon"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.playon"
        // minSdk 21 = Android 5.0 — máxima compatibilidad con Chaquopy + Flutter
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Necesario para proyectos grandes con muchos métodos (>64k)
        multiDexEnabled = true

        ndk {
            abiFilters.clear()
            // arm64-v8a  → dispositivos modernos (64-bit)
            // armeabi-v7a → dispositivos antiguos/gama baja (32-bit)
            // x86_64     → emuladores
            // NOTA: armeabi-v7a requiere Python ≤ 3.11 en Chaquopy
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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

chaquopy {
    defaultConfig {
        // Python 3.11 = última versión compatible con armeabi-v7a (32-bit)
        // Python 3.12+ no soporta ABIs 32-bit en Chaquopy
        version = "3.11"
        // Ruta al ejecutable Python 3.11 (instalado via winget)
        buildPython = listOf("C:\\Users\\wrait\\AppData\\Local\\Programs\\Python\\Python311\\python.exe")
        pip {
            install("yt-dlp")
            install("mutagen")
        }
    }
}
