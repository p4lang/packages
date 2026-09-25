#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Bryan Richter
#
# SPDX-License-Identifier: Apache-2.0

#
# Pin upload-stack's no-skip plan.
#
# Run: ./scripts/test/upload-stack-plan.sh

set -Eeuo pipefail
cd "$(dirname "$0")/../.." || exit 1

source scripts/upload-stack

fail=0
expect() {
    local pi=$1 bmv2=$2 p4c=$3 want=$4 got
    got=$(plan_uploads "$pi" "$bmv2" "$p4c" | paste -sd' ' -)
    if [[ "$got" == "$want" ]]; then
        printf '  ok    pi=%s bmv2=%s p4c=%s -> [%s]\n' "$pi" "$bmv2" "$p4c" "$got"
    else
        fail=1
        printf '  FAIL  pi=%s bmv2=%s p4c=%s -> [%s], want [%s]\n' \
            "$pi" "$bmv2" "$p4c" "$got" "$want"
    fi
}

expect current current current ""
expect ahead   current current ""
expect current ahead   current ""
expect ahead   ahead   current ""
expect current current ahead   "p4c"
expect ahead   current ahead   "p4c"
expect current ahead   ahead   "bmv2 p4c"
expect ahead   ahead   ahead   "pi bmv2 p4c"

(( fail == 0 )) && echo "upload-stack plan: all cases pass"
exit "$fail"
