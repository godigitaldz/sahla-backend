plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Add the Google services Gradle plugin
    id("com.google.gms.google-services")
}

android {
    namespace = "com.godigital.sahla"
    compileSdk = 36  // Required by AndroidX dependencies (work-runtime, activity, core-ktx)
    ndkVersion = "27.0.12077973" // ✅ تم التعديل هنا

    // Suppress specific lint warnings and build warnings
    lint {
        disable += "InvalidPackage"
        disable += "OldTargetApi"
        checkReleaseBuilds = false
        abortOnError = false
    }

    // Suppress plugin SDK version warnings (plugins are backward compatible)
    tasks.withType<JavaCompile> {
        options.compilerArgs.add("-Xlint:-deprecation")
    }

    // Disable strict resource validation to avoid isar_flutter_libs lStar attribute issue
    aaptOptions {
        ignoreAssetsPattern = "!.svn:!.git:!.ds_store:!*.scc:.*:!CVS:!thumbs.db:!picasa.ini:!*~"
        @Suppress("DEPRECATION")
        additionalParameters("--warn-manifest-validation")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.godigital.sahla"
        minSdk = flutter.minSdkVersion  // Minimum SDK for most modern Android features
        targetSdk = 36  // Match compileSdk for best compatibility
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Split APKs per ABI to reduce size (only arm architectures for production)
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
    }

    buildTypes {
        release {
            // Enable code shrinking and resource shrinking for minimal APK size
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Workaround for isar_flutter_libs resource linking issue
    packaging {
        resources {
            excludes += listOf("META-INF/*.kotlin_module")
        }
    }

    // Additional configuration for resource processing
    androidResources {
        ignoreAssetsPattern = "!.svn:!.git:!.ds_store:!*.scc:.*:!CVS:!thumbs.db:!picasa.ini:!*~"
    }
}

flutter {
    source = "../.."
}

// Configuration to handle dependency conflicts
configurations.all {
    resolutionStrategy {
        force("androidx.core:core:1.15.0")
        force("androidx.core:core-ktx:1.15.0")
        force("androidx.activity:activity:1.9.3")
        force("androidx.activity:activity-ktx:1.9.3")
        force("androidx.work:work-runtime:2.9.1")
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // Firebase BoM - Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:34.3.0"))

    // Firebase dependencies - When using the BoM, don't specify versions
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-messaging")

    // Google Maps dependencies - Updated to latest stable versions
    implementation("com.google.android.gms:play-services-maps:18.2.0")
    implementation("com.google.android.gms:play-services-location:21.2.0")

    // Google Play Core library - Required for Flutter deferred components
    implementation("com.google.android.play:core:1.10.3")
}


// Workaround for isar_flutter_libs resource linking issue - disable verification for isar module
afterEvaluate {
    tasks.whenTaskAdded {
        if (name.contains("verifyReleaseResources") || name.contains("verifyDebugResources")) {
            enabled = false
            println("Disabled resource verification task: $name (isar_flutter_libs workaround)")
        }
    }
}

// ----- BEGIN APK Path Logic Fix -----
// Task to create standard APK locations for build tools
tasks.register("createStandardApkPaths") {
    group = "build"
    description = "Creates standard APK paths for build tools compatibility"

    doLast {
        val buildDir = layout.buildDirectory.get().asFile
        val outputsDir = File(buildDir, "outputs/apk")

        // Create standard APK directory if it doesn't exist
        outputsDir.mkdirs()

        // Find and copy the most recent APK files to standard locations
        val buildTypes = listOf("debug", "release")

        buildTypes.forEach { buildType ->
            val apkDir = File(buildDir, "outputs/apk/$buildType")
            if (apkDir.exists()) {
                val apkFiles = apkDir.listFiles { _, name -> name.endsWith(".apk") }
                apkFiles?.forEach { apkFile ->
                    val standardName = "app-$buildType.apk"
                    val standardPath = File(outputsDir, standardName)

                    // Copy APK to standard location
                    apkFile.copyTo(standardPath, overwrite = true)
                    println("Created standard APK path: $standardPath")
                }
            }
        }

        // Also copy APK files to Flutter build directory for Flutter tool compatibility
        val flutterBuildDir = File(project.rootDir.parent, "build/app/outputs/flutter-apk")
        flutterBuildDir.mkdirs()

        // Copy debug APK to Flutter build directory
        val flutterDebugApk = File(flutterBuildDir, "app-debug.apk")
        if (File(outputsDir, "app-debug.apk").exists()) {
            File(outputsDir, "app-debug.apk").copyTo(flutterDebugApk, overwrite = true)
            println("Copied debug APK to Flutter build directory: $flutterDebugApk")
        }

        // Copy release APK to Flutter build directory
        val flutterReleaseApk = File(flutterBuildDir, "app-release.apk")
        if (File(outputsDir, "app-release.apk").exists()) {
            File(outputsDir, "app-release.apk").copyTo(flutterReleaseApk, overwrite = true)
            println("Copied release APK to Flutter build directory: $flutterReleaseApk")
        }
    }
}

// Make the APK path creation task run after assemble tasks
tasks.whenTaskAdded {
    if (name.startsWith("assemble") && name.endsWith("Release")) {
        finalizedBy("createStandardApkPaths")
    }
    if (name.startsWith("assemble") && name.endsWith("Debug")) {
        finalizedBy("createStandardApkPaths")
    }
}
// ----- END APK Path Logic Fix -----
