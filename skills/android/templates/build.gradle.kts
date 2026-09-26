// Root build. Plugins are declared here with their catalog version and applied
// per module. ktlint and detekt are applied in each module's build file.
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.serialization) apply false
    alias(libs.plugins.ksp) apply false
    alias(libs.plugins.hilt) apply false
    alias(libs.plugins.android.junit) apply false
    alias(libs.plugins.ktlint) apply false
    alias(libs.plugins.detekt) apply false
    // OWASP dependency-check runs only from the CI dependency-scan job
    // (./gradlew dependencyCheckAnalyze --no-configuration-cache).
    alias(libs.plugins.dependency.check)
}

dependencyCheck {
    failBuildOnCVSS = 7.0f
    nvd.apiKey = providers.environmentVariable("NVD_API_KEY").orNull
}
