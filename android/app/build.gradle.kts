plugins {
    id("com.android.application")
    id("kotlin-android")
    // This plugin should be applied here without 'version' or 'apply false'
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.apk_tb_care"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.apk_tb_care"
        minSdk = 36
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    // Import the Firebase BoM to manage your SDK versions
    implementation(platform("com.google.firebase:firebase-bom:33.16.0"))

    // Add the dependencies for the Firebase products you want to use
    // When using the BoM, you don't specify versions in individual Firebase library dependencies
    implementation("com.google.firebase:firebase-auth-ktx") // For Firebase Authentication
    implementation("com.google.firebase:firebase-firestore-ktx") // For Cloud Firestore
    implementation("com.google.firebase:firebase-storage-ktx") // For Cloud Storage
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-database")
    
}

flutter {
    source = "../.."
}
