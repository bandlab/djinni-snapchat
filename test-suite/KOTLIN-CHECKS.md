# Kotlin backend — test coverage

The golden snapshot under `generated-src/kotlin/` proves output *stability* (a diff),
but a diff can't catch "the golden diffs clean yet doesn't compile / emits warnings",
nor that the generated surface actually *runs*. These three checks close those gaps.
They already found real defects (missing `compareTo` for `deriving(ord)`, an
optional-`f32` constant literal, unqualified proto extern refs) that the diff missed.

## 1. `kotlin-compile-check/` — compiles clean under `-Werror` (the CI gate)

`./kotlin-compile-check/check.sh` compiles the committed Kotlin golden with
`kotlinc -Werror`, requiring **0 errors and 0 warnings**. Self-contained: it builds
the support-lib classpath from this repo's `support-lib/java` sources plus minimal
protobuf extern stubs (`stubs/`) — only `kotlinc` + `javac` needed, no external artifact.

**Why `-Werror`:** downstream consumers build with Kotlin `allWarningsAsErrors=true`,
so any warning the generator emits fails *their* CI. This gate makes such a regression
fail here first. It is wired into `run_djinni.sh` behind `DJINNI_VERIFY_KOTLIN=1`
(off by default so local regen stays fast; CI should set it), and also runs standalone.

## 2. `kotlin-feature-check/` — per-feature shape assertions

`./kotlin-feature-check/run.sh` generates Kotlin for focused fixtures and asserts each
idiomatic decision (self-describing PASS/FAIL, non-zero exit on any failure): `enum` →
`enum class`; `record` → `data class` with read-only `List/Set/Map` and `optional→T?`;
`get_/getX/is_` → `val` and paired `set_` → `var` (property, not `fun`); `static create`
→ non-null; statics → the `<Name>Statics` interface + `Cpp<Name>Statics` + companion
`<Name>StaticsCompat` triple; and api/impl separation. Uses the local `djinni/accessors.djinni`
fixture (no stock fixture exercises *instance* get/set accessors — every stock `get_*` is static).

## 3. `kotlin-runtime-check/` — host round-trip through JNI (gold standard)

`./kotlin-runtime-check/run-all.sh` mirrors what the Java backend's `handwritten-src/java`
+ JNI `.so` give: it generates cpp+jni+kotlin, builds a host `.dylib` (clang++) from the
generated JNI + support-lib JNI + a hand-written C++ impl, compiles the generated Kotlin
(`kotlinc -Werror`), and runs a JVM driver that `System.load`s the lib and asserts
round-trips through the *new* Kotlin surface — static factory (non-null, via the companion
`StaticsCompat`), property get/set, enum, optional, `List`/`Map`, and a record echoed
JVM→C++→JVM and built C++→JVM.

## Running the checks — no Bazel required

All three are turnkey and **Bazel-free**:

- **(1)** is self-contained — only `kotlinc` + `javac` (builds the support-lib classpath
  from this repo's `support-lib/java`).
- **(2)** and **(3)** run the generator via **`src/run-scalac`** — a Bazel-free build+run
  of the generator: it compiles `src/source/**/*.scala` with `scalac` (JDK 8 + the three
  Maven deps) and runs `djinni.Main`. Override with `DJINNI_RUN` / `BUILD_RUN` to use
  `src/run` (Bazel) instead. (3) also builds its native `.dylib` with host `clang++` — no
  NDK, no Bazel.

Regenerate the whole golden without Bazel:

```
DJINNI_NO_BAZEL=1 DJINNI_RUNNER="$PWD/../src/run-scalac" ./run_djinni.sh
```

Promoting 1–3 to first-class Bazel `test-suite/BUILD` targets (a `kt_jvm_library` compile
target + a `kt_jvm_test` runtime target beside `java_test`) is *optional* — the whole
Kotlin flow already runs end to end with zero Bazel.
