// The JVM library lives in packages/java and stays a build of its own — its own
// settings file, its own wrapper, its own gradle.properties (which is where
// `group` and `version` live, and a subproject would silently stop reading it).
// This root build only includes it, so `cd packages/java && ./gradlew build`
// keeps working exactly as before.
rootProject.name = "food-safety-repo"

includeBuild("packages/java")
