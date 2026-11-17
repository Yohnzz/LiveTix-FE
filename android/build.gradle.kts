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

// Paksa semua subproyek/plugin Android (mis. file_picker) memakai compileSdk 36
// agar memenuhi syarat flutter_plugin_android_lifecycle yang butuh API 36.
// Menggunakan property `compileSdk` (Int) via reflection agar kompatibel dengan
// DSL lama (newDsl=false) maupun baru, tanpa merujuk kelas AGP yang deprecated.
subprojects {
    if (project.name != "app") {
        afterEvaluate {
            val androidExt = project.extensions.findByName("android") ?: return@afterEvaluate
            runCatching {
                val m = androidExt.javaClass.methods.firstOrNull { it.name == "setCompileSdk" && it.parameterTypes.firstOrNull() == Int::class.javaPrimitiveType }
                    ?: androidExt.javaClass.methods.firstOrNull { it.name == "compileSdk" && it.parameterTypes.firstOrNull() == Int::class.javaPrimitiveType }
                m?.invoke(androidExt, 36)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
