#!/usr/bin/env bash
#
# kotlin-compile-check — proves the committed Kotlin golden fixtures COMPILE and
# are WARNING-CLEAN under -Werror, not merely that their text is stable.
#
# Why: downstream consumers build with Kotlin allWarningsAsErrors=true, so any
# warning the generator emits fails their CI. A golden diff catches textual
# drift; it does NOT catch "diffs clean but doesn't compile / warns". This gate
# does. It is self-contained: it builds the support-lib from this repo's
# support-lib/java sources (no external artifact) + minimal protobuf extern stubs.
#
# Usage:  ./check.sh            # exit 0 iff golden compiles with 0 errors / 0 warnings
# Env overrides: JAVA_HOME, KOTLINC, GOLDEN, JAVAC
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE="$(cd "$HERE/.." && pwd)"              # test-suite
DJINNI="$(cd "$SUITE/.." && pwd)"            # djinni repo root

# --- Toolchain -------------------------------------------------------------
if [ -z "${KOTLINC:-}" ]; then
  if command -v kotlinc >/dev/null 2>&1; then KOTLINC="$(command -v kotlinc)"
  elif [ -x "$HOME/.sdkman/candidates/kotlin/current/bin/kotlinc" ]; then KOTLINC="$HOME/.sdkman/candidates/kotlin/current/bin/kotlinc"
  else echo "FATAL: kotlinc not found (set KOTLINC or 'sdk install kotlin')"; exit 2; fi
fi
JAVAC="${JAVAC:-javac}"
[ -n "${JAVA_HOME:-}" ] && export PATH="$JAVA_HOME/bin:$PATH"

GOLDEN="${GOLDEN:-$SUITE/generated-src/kotlin}"
SUPPORT_JAVA="$DJINNI/support-lib/java"
STUBS_SRC="$HERE/stubs"
BUILD="$HERE/build"

[ -d "$GOLDEN/api" ] || { echo "FATAL: golden not found at $GOLDEN/api"; exit 2; }
[ -d "$SUPPORT_JAVA" ] || { echo "FATAL: support-lib java sources not found at $SUPPORT_JAVA"; exit 2; }

rm -rf "$BUILD"; mkdir -p "$BUILD/support" "$BUILD/stubs"

echo "== toolchain =="; "$KOTLINC" -version 2>&1 | sed 's/^/  /'

# --- support-lib classpath (compiled from this repo's sources) -------------
echo "== compiling support-lib java (com.snapchat.djinni.*, com.dropbox.djinni.*) =="
"$JAVAC" -d "$BUILD/support" $(find "$SUPPORT_JAVA" -name '*.java') 2>"$BUILD/support.log" \
  || { echo "FATAL: support-lib javac failed"; sed 's/^/  /' "$BUILD/support.log"; exit 2; }
echo "  ok"

# --- protobuf extern stubs (the fixtures import generated proto message types) --
echo "== compiling extern stubs =="
"$JAVAC" -d "$BUILD/stubs" "$STUBS_SRC"/*.java 2>"$BUILD/stubs.log" \
  || { echo "FATAL: stub javac failed"; sed 's/^/  /' "$BUILD/stubs.log"; exit 2; }
echo "  ok"

# --- kotlinx.coroutines compile-only stub (the generated init-safe hatches use runBlocking + the
#     AudioCoreInit CompletableDeferred gate). Compiled WITHOUT -Werror so the stub's own bodies
#     don't gate the golden; the golden itself is still checked under -Werror against it.
echo "== compiling kotlinx.coroutines stub =="
"$KOTLINC" -d "$BUILD/coroutines-stub.jar" "$STUBS_SRC/kotlinx" > "$BUILD/coroutines.log" 2>&1 \
  || { echo "FATAL: coroutines stub kotlinc failed"; sed 's/^/  /' "$BUILD/coroutines.log"; exit 2; }
echo "  ok"

# --- compile the golden under -Werror --------------------------------------
CP="$BUILD/support:$BUILD/stubs:$BUILD/coroutines-stub.jar"
LOG="$BUILD/kotlinc.log"
echo "== kotlinc -Werror (api + impl) =="
"$KOTLINC" -Werror -cp "$CP" -d "$BUILD/golden.jar" "$GOLDEN/api" "$GOLDEN/impl" > "$LOG" 2>&1
rc=$?
errs=$(grep -c ': error:' "$LOG"); warns=$(grep -c ': warning:' "$LOG")
echo "  exit=$rc  errors=$errs  warnings=$warns  (log: $LOG)"
if [ "$errs" != 0 ] || [ "$warns" != 0 ]; then
  grep -E ': (error|warning):' "$LOG" | sed 's/^/    /' | head -40
fi

echo "=================================================================="
if [ "$rc" = 0 ] && [ "$errs" = 0 ] && [ "$warns" = 0 ]; then
  echo "RESULT: GREEN — Kotlin golden compiles clean under -Werror (0 errors, 0 warnings)."
  exit 0
fi
echo "RESULT: RED — the Kotlin golden does not compile warning-clean. See $LOG."
exit 1
