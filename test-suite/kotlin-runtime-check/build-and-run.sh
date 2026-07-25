#!/usr/bin/env bash
# End-to-end HOST runtime harness for the Kotlin generator backend:
#   1. compile the generated Kotlin api + impl with -Werror (0 warnings required)
#   2. compile the Kotlin driver
#   3. run it on the JVM, System.load-ing the native dylib, and assert round-trips
#
# Prereqs (produced by the sibling scripts):
#   - gen/        : run ./gen.sh
#   - libkruntime.dylib : run ./build-dylib.sh
set -euo pipefail

SCRATCH="/private/tmp/claude-503/-Users-gildor-work-bandlab-audio-engine/288e8c3e-aa84-4907-a1b4-a80628f84e79/scratchpad"
KR="$SCRATCH/kt-runtime"
KH="$HOME/.sdkman/candidates/kotlin/current"
KOTLINC="$KH/bin/kotlinc"
STDLIB="$KH/lib/kotlin-stdlib.jar"
JAVA_HOME="${JAVA_HOME:-$HOME/.sdkman/candidates/java/17.0.20-zulu}"
SUPPORT_JAR="$SCRATCH/kotlin-publish-poc/libs/djinni-support-lib-1.1.1.jar"

GEN_KT=$(find "$KR/gen/kotlin" -name '*.kt' | sort)

# --- 1. compile generated Kotlin api+impl with warnings-as-errors ---
# Downstream consumers build with allWarningsAsErrors=true, so the generated code
# MUST be warning-clean under -Werror or their CI breaks.
rm -rf "$KR/classes"
mkdir -p "$KR/classes"
echo "=== compiling generated Kotlin (api+impl) with -Werror ==="
"$KOTLINC" -Werror -cp "$SUPPORT_JAR:$STDLIB" -d "$KR/classes" $GEN_KT

# --- 2. compile the driver ---
echo "=== compiling driver ==="
rm -rf "$KR/driver-out"
mkdir -p "$KR/driver-out"
"$KOTLINC" -cp "$KR/classes:$SUPPORT_JAR:$STDLIB" -d "$KR/driver-out" "$KR/driver/Main.kt"

# --- 3. run on the JVM ---
echo "=== running driver on JVM ==="
RUN_CP="$KR/driver-out:$KR/classes:$SUPPORT_JAR:$STDLIB"
exec "$JAVA_HOME/bin/java" -cp "$RUN_CP" MainKt "$KR/libkruntime.dylib"
