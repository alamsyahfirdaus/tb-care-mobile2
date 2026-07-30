plugins {
    // Add this line to declare the google-services plugin at the project level
    id("com.google.gms.google-services") version "4.4.3" apply false
    // Any other project-level plugins would go here, like the Android build tools if needed
}

allprojects {
    repositories {
        google() // Essential for finding Google and Firebase SDKs
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
