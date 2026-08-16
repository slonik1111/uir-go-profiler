#!/usr/bin/env bash
# Shared by compare.sh and scripts/experiments/*.sh.
#
# check_regression_csv CSV THRESHOLD
#   Reads a `benchstat -format=csv` report and applies the magnitude part of
#   the regression criterion from раздел 2.2 (the p < ALPHA part is already
#   enforced by benchstat itself via its -alpha flag: it prints "~" instead
#   of a percentage for changes that aren't significant).
#   Only increases count — ns/op, B/op and allocs/op are all lower-is-better.
#   Sets globals: REGRESSED (0/1) and ROWS (markdown table rows, one per
#   flagged metric).
check_regression_csv() {
  local csv="$1" threshold="$2"
  local metric=""
  REGRESSED=0
  ROWS=""

  while IFS=, read -r name base_val base_ci cur_val cur_ci vs_base p_col; do
    if [[ "$name" == "" && "$base_val" == "sec/op" ]]; then metric="ns/op"; continue; fi
    if [[ "$name" == "" && "$base_val" == "B/op" ]]; then metric="B/op"; continue; fi
    if [[ "$name" == "" && "$base_val" == "allocs/op" ]]; then metric="allocs/op"; continue; fi
    [[ "$name" == "" || "$name" == "geomean" ]] && continue
    [[ "${vs_base:0:1}" != "+" ]] && continue

    local magnitude="${vs_base#+}"
    magnitude="${magnitude//%/}"

    if awk -v m="$magnitude" -v t="$threshold" 'BEGIN{exit !(m > t)}'; then
      local p_val="${p_col#p=}"
      p_val="${p_val%% *}"
      ROWS="${ROWS}| ${metric} | ${name} | ${vs_base} | ${p_val} |"$'\n'
      REGRESSED=1
    fi
  done <"$csv"
}
