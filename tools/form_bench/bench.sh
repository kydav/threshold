#!/bin/zsh
# Form import bench: prepare -> map with the app's real request -> score.
# Usage: tools/form_bench/bench.sh FORMS_DIR [OUT_DIR] [name-filter]
# Key: ANTHROPIC_API_KEY, or a file at ~/.config/threshold-bench/anthropic_key.
set -e
here=${0:A:h}
forms=${1:?forms folder}
out=${2:-$forms/results}
: ${ANTHROPIC_API_KEY:=$(cat ~/.config/threshold-bench/anthropic_key 2>/dev/null)}
export ANTHROPIC_API_KEY
mkdir -p $out
[[ -x $out/.ocr ]] || swiftc -O $here/ocr.swift -o $out/.ocr
(cd $here/../../functions && npm run build >/dev/null)
python3 -I $here/prep.py $forms $out $out/.ocr
node $here/run.mjs $out ${3:-}
python3 -I $here/score.py $out
