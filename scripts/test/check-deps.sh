#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Bryan Richter
#
# SPDX-License-Identifier: Apache-2.0

#
# Pin check-deps' control-file parsing and repo-to-image mapping.
#
# Run: ./scripts/test/check-deps.sh

set -Eeuo pipefail
cd "$(dirname "$0")/../.." || exit 1

source scripts/check-deps

fail=0
expect() {
    local what=$1 got=$2 want=$3
    if [[ "$got" == "$want" ]]; then
        printf '  ok    %s\n' "$what"
    else
        fail=1
        printf '  FAIL  %s\n    got:  %s\n    want: %s\n' "$what" "$got" "$want"
    fi
}

control='Source: p4lang-demo
Build-Depends:
    debhelper (>= 12),
    libthrift | libthrift-0.17.0,
    p4lang-pi
Standards-Version: 4.5.0

Package: p4lang-demo
Architecture: amd64 arm64
Depends:
    ${shlibs:Depends},
    ${misc:Depends},
    gcc,
    p4lang-bmv2
Description: demo
 Depends: not-a-field'

expect "relations from Build-Depends and Depends, minus substvars and the stack" \
    "$(installable_relations <<<"$control" | paste -sd'|' -)" \
    "debhelper (>= 12)|libthrift | libthrift-0.17.0|gcc"

expect "a one-line field" \
    "$(installable_relations <<<'Build-Depends: cmake, flex' | paste -sd'|' -)" \
    "cmake|flex"

expect "Debian repo" "$(image_for_repo Debian_13)" "debian:13"
expect "Ubuntu repo" "$(image_for_repo xUbuntu_26.04)" "ubuntu:26.04"
expect "unknown repo" "$(image_for_repo Raspbian_11 2>/dev/null || echo rejected)" "rejected"

(( fail == 0 )) && echo "check-deps: all cases pass"
exit "$fail"
