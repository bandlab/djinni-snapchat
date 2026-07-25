#!/usr/bin/env bash
#
# KotlinGenerator / KotlinMarshal behavior assertions.
#
# For each language feature, generate Kotlin from the smallest fixture that
# exercises it, then assert the expected idiomatic shape appears (or is absent)
# in the output. Complementary to golden snapshots: these assert INTENT, so a
# regression names the feature that broke instead of dumping a diff.
#
# Exit code: 0 iff every assertion passed (CI-usable).
#
# Usage:  bash run.sh
# Env overrides: DJINNI_WT (generator+fixtures worktree), BUILD_RUN (build-and-run.sh)
set -uo pipefail

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH="/private/tmp/claude-503/-Users-gildor-work-bandlab-audio-engine/288e8c3e-aa84-4907-a1b4-a80628f84e79/scratchpad"
DJINNI_WT="${DJINNI_WT:-/Users/gildor/work/bandlab-audio-engine-wt-djinni-kotlin/engine/generated/djinni}"
BUILD_RUN="${BUILD_RUN:-$SCRATCH/djinni-build/build-and-run.sh}"
TS="$DJINNI_WT/test-suite"
FIXTURES_STOCK="$TS/djinni"
FIXTURES_LOCAL="$HERE/fixtures"
OUTROOT="$HERE/out"
PKG="com.dropbox.djinni.test"

rm -rf "$OUTROOT"; mkdir -p "$OUTROOT"

# ---------------------------------------------------------------------------
# Assertion helpers (grep -F: patterns are literal, incl. ( ) ? < > : )
# ---------------------------------------------------------------------------
PASS=0; FAIL=0

_pass() { PASS=$((PASS+1)); printf 'PASS  %s\n' "$1"; }
_fail() { FAIL=$((FAIL+1)); printf 'FAIL  %s\n' "$1"; printf '        file:     %s\n' "$2"; printf '        %s\n' "$3"; }

# assert_has <feature> <file> <literal-substring>
assert_has() {
  local feat="$1" file="$2" needle="$3"
  if [[ ! -f "$file" ]]; then _fail "$feat" "$file" "expected file to exist, but it was not generated"; return; fi
  if grep -Fq -- "$needle" "$file"; then _pass "$feat"
  else _fail "$feat" "$file" "expected to find: >>>$needle<<<"; fi
}

# assert_absent <feature> <file> <literal-substring>
assert_absent() {
  local feat="$1" file="$2" needle="$3"
  if [[ ! -f "$file" ]]; then _fail "$feat" "$file" "expected file to exist, but it was not generated"; return; fi
  if grep -Fq -- "$needle" "$file"; then
    _fail "$feat" "$file" "expected NOT to find, but it is present: >>>$needle<<<"
  else _pass "$feat"; fi
}

# assert_file <feature> <file>
assert_file() {
  local feat="$1" file="$2"
  if [[ -f "$file" ]]; then _pass "$feat"; else _fail "$feat" "$file" "expected this file to be generated"; fi
}

# assert_no_match_in_dir <feature> <dir> <regex>  (no file under dir may match)
assert_no_match_in_dir() {
  local feat="$1" dir="$2" re="$3"
  local hits
  hits="$(grep -rlE -- "$re" "$dir" 2>/dev/null || true)"
  if [[ -z "$hits" ]]; then _pass "$feat"
  else _fail "$feat" "$dir" "no file under this dir may match /$re/, but these do:"$'\n'"$hits"; fi
}

# generate <out-subdir> <idl-path> [extra args...]
generate() {
  local out="$OUTROOT/$1"; shift
  local idl="$1"; shift
  mkdir -p "$out"
  ( cd "$TS" && bash "$BUILD_RUN" -- \
      --java-package "$PKG" \
      --kotlin-out "$out" --kotlin-package "$PKG" \
      --idl "$idl" "$@" ) > "$out/.gen.log" 2>&1
  if [[ $? -ne 0 ]]; then
    echo "GENERATION FAILED for $idl (see $out/.gen.log):" >&2
    tail -20 "$out/.gen.log" >&2
    exit 2
  fi
}

echo "==> Building generator + generating fixtures (first run compiles Scala; ~30s)..."
generate enum         "$FIXTURES_STOCK/enum.djinni"
generate client       "$FIXTURES_STOCK/client_interface.djinni"
generate accessors    "$FIXTURES_LOCAL/accessors.djinni"
echo

# ===========================================================================
# Feature 1: enum -> `enum class` (a real Kotlin enum, not a Java enum)
# ===========================================================================
E="$OUTROOT/enum/api/Color.kt"
assert_has    "enum: emits 'enum class Color'"                 "$E" "enum class Color {"
assert_has    "enum: constant RED present"                     "$E" "RED,"
assert_has    "enum: constant VIOLET present"                  "$E" "VIOLET,"
assert_absent "enum: no Cpp proxy / native surface in api"     "$E" "external"

# ===========================================================================
# Feature 2: record -> `data class`
# ===========================================================================
R="$OUTROOT/enum/api/EnumUsageRecord.kt"
assert_has    "record: emits 'data class EnumUsageRecord('"    "$R" "data class EnumUsageRecord("

# ===========================================================================
# Feature 3: record collection fields are idiomatic AND read-only
#            (List/Set/Map, never ArrayList/HashSet/HashMap)
# ===========================================================================
assert_has    "record collections: read-only List field"      "$R" "val l: List<Color>,"
assert_has    "record collections: read-only Set field"       "$R" "val s: Set<Color>,"
assert_has    "record collections: read-only Map field"       "$R" "val m: Map<Color, Color>,"
assert_absent "record collections: no ArrayList"              "$R" "ArrayList"
assert_absent "record collections: no HashSet"               "$R" "HashSet"
assert_absent "record collections: no HashMap"               "$R" "HashMap"

# ===========================================================================
# Feature 4: record optional<T> field -> T?
# ===========================================================================
assert_has    "record optional field: 'val o: Color?'"        "$R" "val o: Color?,"

# ===========================================================================
# Feature 5: interface accessors -> val/var properties (not fun getX/isX)
#   get_x + set_x (paired)     -> var x
#   getX  + setX  (paired)     -> var x
#   is_x / isX  (no setter)    -> val isX
#   get_x with no/mismatched setter -> val x, setter stays fun
# ===========================================================================
A="$OUTROOT/accessors/api/Accessors.kt"
assert_has    "accessor get_+set_ pair -> 'var sampleRate: Int'"   "$A" "var sampleRate: Int"
assert_has    "accessor getX+setX pair -> 'var volume: Double'"    "$A" "var volume: Double"
assert_has    "accessor is_x -> 'val isMuted: Boolean'"            "$A" "val isMuted: Boolean"
assert_has    "accessor isX  -> 'val isReady: Boolean'"            "$A" "val isReady: Boolean"
assert_has    "accessor get_x (no setter) -> 'val name: String'"   "$A" "val name: String"
assert_absent "accessor: no 'fun getSampleRate' method"           "$A" "fun getSampleRate"
assert_absent "accessor: no 'fun getVolume' method"               "$A" "fun getVolume"
assert_absent "accessor: no 'fun isMuted' method"                 "$A" "fun isMuted"
# type-mismatched setter must NOT collapse into a var: property stays val, setter stays fun
assert_has    "accessor type-mismatch: property stays 'val gain: Int'" "$A" "val gain: Int"
assert_has    "accessor type-mismatch: setter stays 'fun setGain'"     "$A" "fun setGain(v: String)"
# non-accessors keep their fun shape
assert_has    "accessor guard: 'get_at(param)' stays 'fun getAt'"  "$A" "fun getAt(index: Int): Int"
assert_has    "accessor guard: 'setup()' stays 'fun setup'"        "$A" "fun setup()"

# CppProxy mirrors the property with computed get()/set() over UNCHANGED native_* methods
AC="$OUTROOT/accessors/impl/CppAccessors.kt"
assert_has    "accessor impl: 'override var sampleRate: Int'"      "$AC" "override var sampleRate: Int"
assert_has    "accessor impl: native getter kept as external"     "$AC" "private external fun native_getSampleRate(_nativeRef: Long): Int"
assert_has    "accessor impl: native setter kept as external"     "$AC" "private external fun native_setSampleRate(_nativeRef: Long, value: Int)"

# ===========================================================================
# Feature 6: static create(...): T  ->  returns NON-NULL T (deliberate delta
#            from Java's @Nullable create). No trailing `?` on the api signature.
# ===========================================================================
CS="$OUTROOT/client/api/ReverseClientInterfaceStatics.kt"
assert_has    "static create: non-null return 'fun create(): ReverseClientInterface'" "$CS" "fun create(): ReverseClientInterface"
assert_absent "static create: return is NOT nullable"             "$CS" "fun create(): ReverseClientInterface?"

# ===========================================================================
# Feature 7: statics on an interface produce THREE artifacts:
#   api:  <Name>Statics interface (statics as instance methods)
#   impl: Cpp<Name>Statics (implements it; private external fun ..._native)
#   impl: <Name>StaticsCompat.kt  fun <Name>.Companion.<static>(...) backed by
#         a file-private lazy(LazyThreadSafetyMode.NONE) { Cpp<Name>Statics() }
# ===========================================================================
assert_file   "statics api: ReverseClientInterfaceStatics.kt exists"  "$CS"
assert_has    "statics api: 'interface ReverseClientInterfaceStatics'" "$CS" "interface ReverseClientInterfaceStatics {"

CSI="$OUTROOT/client/impl/CppReverseClientInterfaceStatics.kt"
assert_file   "statics impl: CppReverseClientInterfaceStatics.kt exists" "$CSI"
assert_has    "statics impl: implements the Statics interface"        "$CSI" "class CppReverseClientInterfaceStatics : ReverseClientInterfaceStatics"
assert_has    "statics impl: private external '..._native'"           "$CSI" "private external fun create_native(): ReverseClientInterface?"

CSC="$OUTROOT/client/impl/ReverseClientInterfaceStaticsCompat.kt"
assert_file   "statics compat: ReverseClientInterfaceStaticsCompat.kt exists" "$CSC"
assert_has    "statics compat: Companion extension fun"               "$CSC" "fun ReverseClientInterface.Companion.create(): ReverseClientInterface = instance.create()"
assert_has    "statics compat: lazy(NONE) instance backing"           "$CSC" "by lazy(LazyThreadSafetyMode.NONE) { CppReverseClientInterfaceStatics() }"

# ===========================================================================
# Feature 8: api/impl separation -- api/ has NO Cpp proxy class and NO external.
#            The Cpp<Name> proxy + external funcs live ONLY under impl/.
# ===========================================================================
assert_no_match_in_dir "api/impl split: no 'external' under api/"    "$OUTROOT/client/api" "external"
assert_no_match_in_dir "api/impl split: no 'class Cpp' under api/"   "$OUTROOT/client/api" "class Cpp"
CP="$OUTROOT/client/impl/CppReverseClientInterface.kt"
assert_has    "api/impl split: proxy 'class CppReverseClientInterface' in impl" "$CP" "class CppReverseClientInterface private constructor"
assert_has    "api/impl split: external fun lives in impl"           "$CP" "private external fun native_returnStr"

# ===========================================================================
# Feature 9: interface refs & optional<interface> -> nullable (?), mirrored policy
# ===========================================================================
CI="$OUTROOT/client/api/ClientInterface.kt"
assert_has    "interface ref -> nullable param 'ClientInterface?'"   "$CI" "fun methTakingInterface(i: ClientInterface?): String"
assert_has    "optional<interface> -> nullable param"                "$CI" "fun methTakingOptionalInterface(i: ClientInterface?): String"

# ---------------------------------------------------------------------------
echo
echo "-----------------------------------------------------------------------"
printf 'RESULT: %d passed, %d failed\n' "$PASS" "$FAIL"
if [[ "$FAIL" -ne 0 ]]; then exit 1; fi
