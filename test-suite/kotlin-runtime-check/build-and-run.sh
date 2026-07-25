#!/usr/bin/env bash
# End-to-end HOST runtime harness for the Kotlin generator backend:
#   1. compile the generated Kotlin api + impl with -Werror (0 warnings required)
#   2. compile the Kotlin driver
#   3. run it on the JVM, System.load-ing the native dylib, and assert round-trips
#
# Self-contained: the support-lib classpath is compiled from this repo's
# support-lib/java sources (no external artifact). Prereqs: ./gen.sh, ./build-dylib.sh.
set -euo pipefail

KR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DJINNI="$(cd "$KR/../.." && pwd)"
KOTLINC="${KOTLINC:-$HOME/.sdkman/candidates/kotlin/current/bin/kotlinc}"
KH="$(cd "$(dirname "$KOTLINC")/.." && pwd)"
STDLIB="$KH/lib/kotlin-stdlib.jar"
JAVA_HOME="${JAVA_HOME:-$HOME/.sdkman/candidates/java/17.0.20-zulu}"

# support-lib classpath, built from repo sources (com.snapchat.djinni.*, com.dropbox.djinni.*)
SUPPORT="$KR/gen/support-classes"
rm -rf "$SUPPORT"; mkdir -p "$SUPPORT"
"$JAVA_HOME/bin/javac" -d "$SUPPORT" $(find "$DJINNI/support-lib/java" -name '*.java')

GEN_KT=$(find "$KR/gen/kotlin" -name '*.kt' | sort)

# --- 1. compile generated Kotlin api+impl with warnings-as-errors ---
# Downstream consumers build with allWarningsAsErrors=true, so the generated code
# MUST be warning-clean under -Werror or their CI breaks.
rm -rf "$KR/classes"; mkdir -p "$KR/classes"
echo "=== compiling generated Kotlin (api+impl) with -Werror ==="
"$KOTLINC" -Werror -cp "$SUPPORT:$STDLIB" -d "$KR/classes" $GEN_KT

# --- 2. compile the driver ---
echo "=== compiling driver ==="
rm -rf "$KR/driver-out"; mkdir -p "$KR/driver-out"
"$KOTLINC" -cp "$KR/classes:$SUPPORT:$STDLIB" -d "$KR/driver-out" "$KR/driver/Main.kt"

# --- 3. run on the JVM ---
echo "=== running driver on JVM ==="
RUN_CP="$KR/driver-out:$KR/classes:$SUPPORT:$STDLIB"
exec "$JAVA_HOME/bin/java" -cp "$RUN_CP" MainKt "$KR/libkruntime.dylib"
