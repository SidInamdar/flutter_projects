plugins {
    // Add the dependency for the Google services Gradle plugin
    // **IMPORTANT: Please verify the LATEST STABLE version of this plugin from the Firebase documentation.**
    // Using an outdated version can lead to issues.
    // Example version (check for current):
    id("com.google.gms.google-services") version "4.4.2" apply false // Or "4.4.2" if that's confirmed latest and stable
}

allprojects {
    repositories {
        google()
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
