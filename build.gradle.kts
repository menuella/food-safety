// Why a Gradle build sits at the root of a repository whose JVM package is two
// directories down: CodeQL's Java autobuilder only looks for a build file in
// the checkout root, and code scanning's default setup gives no way to point it
// elsewhere. Without this, `Analyze (java-kotlin)` fails with "Could not detect
// a suitable build command" and the Kotlin is never scanned at all.
//
// Nothing is defined here. Every task hands straight to the real build in
// packages/java, which stays the single place the library is described.
val jvm = gradle.includedBuild("java")

// The two the autobuilder actually runs, in this order.
tasks.register("clean") { dependsOn(jvm.task(":clean")) }

tasks.register("testClasses") { dependsOn(jvm.task(":testClasses")) }

// Not used by the autobuilder — here so that `./gradlew build` from the root
// does the obvious thing instead of failing with "task not found".
tasks.register("build") { dependsOn(jvm.task(":build")) }
