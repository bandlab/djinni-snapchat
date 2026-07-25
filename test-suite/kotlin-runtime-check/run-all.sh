#!/usr/bin/env bash
# One-shot: generate -> build native dylib -> compile generated Kotlin (-Werror) ->
# compile driver -> run the HOST round-trip. Exit 0 == all round-trips green.
set -euo pipefail
KR="/private/tmp/claude-503/-Users-gildor-work-bandlab-audio-engine/288e8c3e-aa84-4907-a1b4-a80628f84e79/scratchpad/kt-runtime"
bash "$KR/gen.sh"
bash "$KR/build-dylib.sh"
exec bash "$KR/build-and-run.sh"
