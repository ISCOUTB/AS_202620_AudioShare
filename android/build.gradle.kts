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

// flutter_plugin_android_lifecycle 2.0.34 exige que quien dependa de él compile
// contra Android 36, pero file_picker 8.3.7 fija compileSdk 34 en su propio
// build.gradle y el APK falla en `:file_picker:checkReleaseAarMetadata`. Subir
// compileSdk no cambia el comportamiento en ejecución ni los dispositivos
// soportados (eso lo deciden minSdk y targetSdk). Se aplica en afterEvaluate,
// después de que cada plugin haya fijado su valor; va antes del
// evaluationDependsOn de abajo para registrarse antes de evaluar los proyectos.
subprojects {
    afterEvaluate {
        extensions.findByType<com.android.build.api.dsl.LibraryExtension>()?.apply {
            compileSdk = 36
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
