plugins {
    kotlin("jvm") version "2.1.0"
    `java-library`
    `maven-publish`
    signing
    id("com.gradleup.nmcp") version "0.0.9"
}

repositories {
    mavenCentral()
}

// JVM 17: current enough for records and modern Gradle, old enough that an
// Android or Spring Boot consumer on an LTS runtime is not shut out.
kotlin {
    jvmToolchain(17)
    // Every public declaration must carry an explicit visibility and return
    // type. On a published library the API surface is a contract, and `strict`
    // makes widening it an explicit act rather than an accident.
    explicitApi()
}

java {
    withSourcesJar()
    withJavadocJar()
}

// kotlin-stdlib only, which every Kotlin library carries. Nothing else: the
// dataset is generated Kotlin source, so there is nothing to parse at runtime.
// That matters more here than elsewhere — the JVM has no JSON parser in its
// standard library, so reading the data at runtime would have meant taking a
// real dependency on one.
dependencies {
    testImplementation(kotlin("test"))
}

tasks.test {
    useJUnitPlatform()
    testLogging { events("failed") }
}

publishing {
    publications {
        create<MavenPublication>("maven") {
            from(components["java"])
            artifactId = "food-safety"

            pom {
                name.set("Menuella Food Safety")
                description.set(
                    "Open allergen and additive vocabulary for restaurant menus: 28 allergen " +
                        "keys from EU Reg. 1169/2011 Annex II, 22 declarations, codes, icons " +
                        "and six languages."
                )
                url.set("https://www.menuella.com/food-safety")
                inceptionYear.set("2026")

                licenses {
                    license {
                        name.set("MIT License")
                        url.set("https://opensource.org/licenses/MIT")
                        distribution.set("repo")
                    }
                }
                developers {
                    developer {
                        id.set("menuella")
                        name.set("Menuella")
                        email.set("developers@menuella.com")
                        organization.set("Menuella")
                        organizationUrl.set("https://www.menuella.com")
                    }
                }
                scm {
                    url.set("https://github.com/menuella/food-safety")
                    connection.set("scm:git:https://github.com/menuella/food-safety.git")
                    developerConnection.set("scm:git:ssh://git@github.com/menuella/food-safety.git")
                }
                issueManagement {
                    system.set("GitHub Issues")
                    url.set("https://github.com/menuella/food-safety/issues")
                }
            }
        }
    }
}

signing {
    // In-memory keys: CI has no keyring, and writing one to disk would leave a
    // private key on the runner. Absent locally, so a plain `gradle build`
    // still works without a signing setup.
    val key = providers.environmentVariable("GPG_PRIVATE_KEY").orNull
    val passphrase = providers.environmentVariable("GPG_PASSPHRASE").orNull
    if (key != null && passphrase != null) {
        useInMemoryPgpKeys(key, passphrase)
        sign(publishing.publications["maven"])
    }
}

nmcp {
    publishAllPublications {
        username.set(providers.environmentVariable("MAVEN_CENTRAL_USERNAME"))
        password.set(providers.environmentVariable("MAVEN_CENTRAL_PASSWORD"))
        // Publishes as soon as Central finishes validating, like every other
        // registry here.
        //
        // USER_MANAGED was the earlier setting, on the reasoning that Central
        // has no unpublish. That reasoning does not survive contact with the
        // rest of this repository: pub.dev and NuGet cannot unpublish either,
        // and both publish automatically. What the manual gate actually bought
        // was a step to forget — two releases sat validated and unreleased
        // while the other six registries had shipped.
        //
        // The deliberate act is the tag. Tests run before the upload, and a
        // version number is checked against the tag, so by the time Central has
        // the bundle there is nothing left for a human to decide.
        publicationType.set("AUTOMATIC")
    }
}
