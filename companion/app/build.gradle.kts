plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

val keystorePath: String? = System.getenv("TOPOLINK_KEYSTORE")

android {
    namespace = "fr.lahocy.topolink"
    compileSdk = 34

    defaultConfig {
        applicationId = "fr.lahocy.topolink"
        minSdk = 26
        targetSdk = 34
        versionCode = (project.findProperty("versionCode") as String?)?.toIntOrNull() ?: 1
        versionName = (project.findProperty("versionName") as String?) ?: "0.0.0"
    }

    signingConfigs {
        // Clé fournie par le workflow (secrets GitHub) ; sinon clé de debug jetable.
        if (keystorePath != null && file(keystorePath).exists()) {
            create("release") {
                storeFile = file(keystorePath)
                storeType = "PKCS12"
                storePassword = System.getenv("TOPOLINK_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("TOPOLINK_KEY_ALIAS") ?: "topolink"
                keyPassword = System.getenv("TOPOLINK_KEY_PASSWORD") ?: System.getenv("TOPOLINK_KEYSTORE_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = if (keystorePath != null && file(keystorePath).exists())
                signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    sourceSets.getByName("main").java.srcDirs("src/main/kotlin")
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("org.nanohttpd:nanohttpd:2.3.1")
}
