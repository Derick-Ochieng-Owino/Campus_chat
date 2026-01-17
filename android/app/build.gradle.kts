plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.campus_app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.example.campus_app"
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
    implementation("com.google.firebase:firebase-auth-ktx:22.1.1")
    implementation("com.google.android.gms:play-services-auth:20.7.0") // Google Sign-In
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
