const { withProjectBuildGradle } = require('expo/config-plugins');

// io.purchasely 6.0.x brings kotlin-stdlib 2.3.21 and kotlinx-serialization 1.11.0, whose
// Kotlin metadata is 2.3.0. A Kotlin compiler reads metadata up to one minor version
// ahead, so the build needs a 2.2.x compiler at least. Two things stand in the way, and
// expo-build-properties' `android.kotlinVersion` fixes neither on its own:
//
//   1. React Native's gradle plugin pins the Kotlin Gradle Plugin to its own version
//      (2.1.20 on RN 0.83), so the compiler stays on 2.1.x.
//   2. Some third-party modules (react-native-gesture-handler 2.30.0) use language
//      constructs that Kotlin 2.2 rejects.
//
// The compiler version and the language version are independent: a 2.2 compiler reads
// 2.3 metadata even when it compiles the sources at language version 2.1.
const LANGUAGE_VERSION = 'KOTLIN_2_1';

const SUBPROJECTS_BLOCK = `
subprojects { subproject ->
  subproject.plugins.withId('org.jetbrains.kotlin.android') {
    subproject.tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile).configureEach {
      compilerOptions {
        languageVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.${LANGUAGE_VERSION})
      }
    }
  }
}
`;

module.exports = function withKotlinGradlePluginVersion(config) {
  return withProjectBuildGradle(config, (cfg) => {
    const classpath = "classpath('org.jetbrains.kotlin:kotlin-gradle-plugin')";
    if (!cfg.modResults.contents.includes(classpath)) return cfg;
    cfg.modResults.contents =
      cfg.modResults.contents
        .replace(
          'buildscript {',
          "buildscript {\n  ext.kotlinVersion = findProperty('android.kotlinVersion') ?: '2.0.21'"
        )
        .replace(classpath, 'classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")') +
      SUBPROJECTS_BLOCK;
    return cfg;
  });
};
