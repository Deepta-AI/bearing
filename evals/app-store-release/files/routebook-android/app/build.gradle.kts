plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.google.services)
    alias(libs.plugins.crashlytics)
}

android {
    namespace = "com.example.routebook"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.example.routebook"
        minSdk = 26
        targetSdk = 35
        versionCode = 57
        versionName = "3.8.0"
    }

    buildFeatures { buildConfig = true }

    buildTypes {
        debug {
            buildConfigField("String", "API_BASE", "\"https://staging-api.routebook.example.com\"")
        }
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            buildConfigField("String", "API_BASE", "\"http://api.routebook.example.com\"")
        }
    }
}

dependencies {
    implementation(libs.play.services.location)
    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.crashlytics)
    implementation(libs.okhttp)
}
