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

    // Force every Android library plugin up to the app's compileSdk. Some
    // plugins in this stack still declare 34 while their transitive
    // dependencies demand 36, which aborts CheckAarMetadata
    // (gray_part_pitfalls.md §2).
    //
    // This MUST be registered before the evaluationDependsOn(":app") block
    // below — after it, the target projects are already evaluated and
    // Gradle refuses to attach an afterEvaluate callback.
    afterEvaluate {
        extensions
            .findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?.apply {
                if ((compileSdk ?: 0) < 36) {
                    compileSdk = 36
                }
            }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
