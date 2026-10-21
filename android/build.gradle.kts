allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// biometric_storage 5.0.1 compila contra android-31, pero sus dependencias de androidx exigen 33
// o más y la verificación de metadatos de los AAR rompe el build de release. Se sube su compileSdk.
subprojects {
    if (name == "biometric_storage") {
        fun subirCompileSdk() {
            (extensions.findByName("android") as? com.android.build.gradle.BaseExtension)
                ?.compileSdkVersion(36)
        }
        if (state.executed) subirCompileSdk() else afterEvaluate { subirCompileSdk() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
