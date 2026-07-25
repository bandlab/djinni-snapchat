#!/usr/bin/env bash
# One-shot: generate -> build native dylib -> compile generated Kotlin (-Werror) ->
# compile driver -> run the HOST round-trip. Exit 0 == all round-trips green.
# Fully Bazel-free (generator via src/run-scalac) and self-contained (support-lib
# built from this repo's sources). Set KR_DEBUG=1 to build the dylib with asserts on.
set -euo pipefail
KR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$KR/gen.sh"
bash "$KR/build-dylib.sh"
exec bash "$KR/build-and-run.sh"
