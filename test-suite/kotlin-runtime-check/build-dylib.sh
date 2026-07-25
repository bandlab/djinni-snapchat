#!/usr/bin/env bash
# Build the HOST JNI shared library (libkruntime.dylib) from:
#   - djinni support-lib C++ (core + JNI_OnLoad), from this repo's support-lib/
#   - the generated JNI glue (gen/jni/*.cpp)
#   - the hand-written C++ impl of runtime_iface (cpp-impl/runtime_iface_impl.cpp)
# Host Apple clang++ + a JDK that ships jni.h (no NDK, no Android, no Bazel).
set -euo pipefail

KR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DJINNI="$(cd "$KR/../.." && pwd)"
SL="$DJINNI/support-lib"
JAVA_HOME="${JAVA_HOME:-$HOME/.sdkman/candidates/java/17.0.20-zulu}"

# -DNDEBUG => release semantics (matches how the app/production JNI lib is built).
# Set KR_DEBUG=1 to build with asserts on; the support-lib Marshal.hpp collection
# guards now accept any java/util List/Set/Map, so idiomatic Kotlin listOf()/mapOf()/
# setOf() round-trip even in debug (previously they aborted on IsInstanceOf).
OPT="-DNDEBUG -O2"
[ "${KR_DEBUG:-0}" = "1" ] && OPT="-O0 -g"
clang++ -std=c++17 -shared -fPIC $OPT \
  -o "$KR/libkruntime.dylib" \
  -I "$KR/gen/cpp" \
  -I "$KR/gen/jni" \
  -I "$SL/jni" \
  -I "$SL" \
  -I "$SL/cpp" \
  -I "$JAVA_HOME/include" \
  -I "$JAVA_HOME/include/darwin" \
  "$KR/cpp-impl/runtime_iface_impl.cpp" \
  "$KR/gen/jni/NativeRuntimeIface.cpp" \
  "$KR/gen/jni/NativeRuntimeRecord.cpp" \
  "$KR/gen/jni/NativeEnumUsageInterface.cpp" \
  "$KR/gen/jni/NativeEnumUsageRecord.cpp" \
  "$SL/jni/djinni_support.cpp" \
  "$SL/jni/djinni_main.cpp"

echo "OK: built $KR/libkruntime.dylib"
