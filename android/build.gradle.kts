buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.3")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Commented out custom build directory configuration
// This was causing Flutter build tool to not find the generated APK files
// val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
// rootProject.layout.buildDirectory.value(newBuildDir)

// subprojects {
//     val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
//     project.layout.buildDirectory.value(newSubprojectBuildDir)
// }
subprojects {
    // Workaround for isar_flutter_libs resource linking issue
    // Disable resource verification tasks that fail due to lStar attribute
    tasks.whenTaskAdded {
        if (name.contains("verifyReleaseResources") || name.contains("verifyDebugResources")) {
            enabled = false
            println("Disabled resource verification task: $name (isar_flutter_libs SDK 36 workaround)")
        }
    }

    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
