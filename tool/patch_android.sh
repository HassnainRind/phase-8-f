#!/usr/bin/env bash
# Force every Android plugin module to compile against SDK 36.
# Needed because some plugins (e.g. file_picker 8.x) hardcode compileSdk 34 while
# flutter_plugin_android_lifecycle now requires >= 36 (CheckAarMetadata failure).
set -euo pipefail
if [ -f android/build.gradle.kts ]; then
  f=android/build.gradle.kts
  snippet='subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            try {
                androidExt.javaClass.getMethod("setCompileSdk", Integer::class.javaObjectType).invoke(androidExt, 36)
            } catch (e: Exception) {
                println("compileSdk override skipped for ${project.name}: ${e}")
            }
        }
    }
}
'
elif [ -f android/build.gradle ]; then
  f=android/build.gradle
  snippet='subprojects {
    afterEvaluate { p ->
        if (p.extensions.findByName("android") != null) {
            p.android.compileSdk = 36
        }
    }
}
'
else
  echo "No android/build.gradle(.kts) found" >&2; exit 1
fi
# Must come BEFORE the template's evaluationDependsOn(":app"), so prepend it.
printf '%s\n' "$snippet" | cat - "$f" > "$f.new" && mv "$f.new" "$f"
echo "Patched $f"
