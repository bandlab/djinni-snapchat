#!/usr/bin/env bash
# Generate cpp + jni + kotlin for the curated runtime fixture via the Bazel-free
# scalac generator runner (src/run-scalac). Kotlin replaces the Java backend.
# Override the generator with DJINNI_RUN (e.g. point it at src/run for Bazel).
set -euo pipefail

KR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DJINNI="$(cd "$KR/../.." && pwd)"                 # test-suite/kotlin-runtime-check -> repo root
BAR="${DJINNI_RUN:-$DJINNI/src/run-scalac}"
PKG="com.snapchat.djinni.rt"

rm -rf "$KR/gen"
mkdir -p "$KR/gen/cpp" "$KR/gen/jni" "$KR/gen/kotlin"

# kt_runtime.djinni @imports the stock enum.djinni, resolved via the include path.
bash "$BAR" -- \
  --cpp-out       "$KR/gen/cpp" \
  --cpp-namespace rt \
  --jni-out       "$KR/gen/jni" \
  --ident-jni-file NativeFooBar \
  --ident-jni-class NativeFooBar \
  --kotlin-out    "$KR/gen/kotlin" \
  --kotlin-package "$PKG" \
  --java-package   "$PKG" \
  --idl "$KR/idl/kt_runtime.djinni" \
  --idl-include-path "$DJINNI/test-suite/djinni"

echo "=== generated files ==="
find "$KR/gen" -type f | sort
