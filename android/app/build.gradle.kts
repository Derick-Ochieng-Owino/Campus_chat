plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.alma_mata"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.example.alma_mata"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true   // <-- note 'is' prefix
    }

    kotlinOptions {
        jvmTarget = "1.8"   // use string "1.8" here
    }
}


flutter {
    source = "../.."
}

// 🚨 ADD THIS DEPENDENCIES BLOCK 🚨
dependencies {
    implementation("com.google.android.material:material:1.10.0")
    implementation("androidx.core:core-ktx:1.12.0")
    // ... your other dependencies

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5") // <-- Kotlin DSL
}
