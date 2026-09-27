plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.example.parcels"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.parcels"
        minSdk = 26
        targetSdk = 34
        versionCode = 41
        versionName = "2.6.0"
    }

    buildFeatures { compose = true }
    composeOptions { kotlinCompilerExtensionVersion = "1.5.14" }

    lint {
        // Translators lag behind releases; do not block CI on it.
        disable += "MissingTranslation"
        abortOnError = true
    }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.06.00"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.activity:activity-compose:1.9.0")
    implementation("androidx.appcompat:appcompat:1.7.0")
    testImplementation("junit:junit:4.13.2")
}
