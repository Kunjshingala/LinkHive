import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("dev.flutter.flutter-gradle-plugin")

}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(localPropertiesFile.inputStream())
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode") ?: "1"
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

// Release signing. android/key.properties and the keystore are gitignored;
// without them, release builds fall back to the debug key.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.link.hive"
    compileSdk = (project.property("compileSdkVersion") as String).toInt()
    ndkVersion = project.property("ndkVersion") as String

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (java.time APIs) on API
        // levels below 26 — see the coreLibraryDesugaring dependency below.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.link.hive"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = (project.property("minSdkVersion") as String).toInt()
        targetSdk = (project.property("targetSdkVersion") as String).toInt()
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
//    implementation("com.google.firebase:firebase-analytics") // Example for Firebase
//    implementation(platform("com.google.firebase:firebase-bom:34.7.0")) // Example for Firebase
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // Home-screen widget (Today's pick + stats) — Jetpack Glance, the modern
    // Compose-style widget API (vs. hand-written RemoteViews/XML).
    implementation("androidx.glance:glance-appwidget:1.2.0")
}
