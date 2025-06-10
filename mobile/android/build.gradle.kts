allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = File("../build")

subprojects {
    afterEvaluate {
        if (hasProperty("android")) {
            configure<com.android.build.gradle.BaseExtension> {
                if (namespace == null) {
                    namespace = "${project.group}"
                }
            }
        }
    }
}

subprojects {
    project.buildDir = File(rootProject.buildDir, project.name)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}