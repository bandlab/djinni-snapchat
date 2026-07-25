#!/usr/bin/env bash
# Generate cpp + jni + kotlin for the curated runtime fixture using the
# kotlin-generator djinni build (no Bazel). Kotlin replaces the Java backend.
set -euo pipefail

SCRATCH="/private/tmp/claude-503/-Users-gildor-work-bandlab-audio-engine/288e8c3e-aa84-4907-a1b4-a80628f84e79/scratchpad"
KR="$SCRATCH/kt-runtime"
BAR="$SCRATCH/djinni-build/build-and-run.sh"
PKG="com.snapchat.djinni.rt"

rm -rf "$KR/gen"
mkdir -p "$KR/gen/cpp" "$KR/gen/jni" "$KR/gen/kotlin"

cd "$KR/idl"
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
  --idl-include-path "$KR/idl"

echo "=== generated files ==="
find "$KR/gen" -type f | sort
