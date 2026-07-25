#!/usr/bin/env bash
# Build the HOST JNI shared library (libktruntime.dylib) from:
#   - djinni support-lib C++ (core + JNI_OnLoad)
#   - the generated JNI glue (gen/jni/*.cpp)
#   - the hand-written C++ impl of runtime_iface (cpp-impl/runtime_iface_impl.cpp)
# Host Apple clang++ + a JDK that ships jni.h (no NDK, no Android).
set -euo pipefail

SCRATCH="/private/tmp/claude-503/-Users-gildor-work-bandlab-audio-engine/288e8c3e-aa84-4907-a1b4-a80628f84e79/scratchpad"
KR="$SCRATCH/kt-runtime"
SL="$SCRATCH/djinni-snapchat/support-lib"
JAVA_HOME="${JAVA_HOME:-$HOME/.sdkman/candidates/java/17.0.20-zulu}"

# -DNDEBUG => release semantics (matches how the app/production JNI lib is built).
# Without it, the support-lib Marshal.hpp asserts IsInstanceOf(j, java.util.ArrayList/
# HashMap/HashSet), which idiomatic Kotlin listOf()/mapOf()/setOf() (Arrays$ArrayList /
# SingletonMap / LinkedHashSet) fail. See REPORT.md "Findings". Set KR_DEBUG=1 to reproduce
# that debug-mode abort.
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
