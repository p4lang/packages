#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Bryan Richter
#
# SPDX-License-Identifier: Apache-2.0

#
# Pin that build-pkg builds against the OBS project LOCALBUILD_PROJECT names,
# home:p4lang by default, and keeps each project's osc state apart.
#
# Run: ./scripts/test/build-pkg-project.sh

set -Eeuo pipefail
build_pkg="$(cd "$(dirname "$0")/.." && pwd)/build-pkg"

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

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/src"
printf 'Source: p4lang-demo\nBuild-Depends: debhelper\n' > "$scratch/src/p4lang-demo_1.0-1.dsc"

# The --alternative-project build-pkg passes to osc, and the project its osc
# working copy names, from a dry run in a fresh dir.
projects_used() {
    local dir
    dir="$(mktemp -d -p "$scratch")"
    (cd "$dir" && OBS_USERNAME=test "$build_pkg" --dry-run "$scratch/src" "$@" 2>/dev/null) \
        | grep -o -- '--alternative-project [^ ]*' | cut -d' ' -f2
    cat "$dir"/build/.osc-work/*/src/.osc/_project
}

expect "defaults to home:p4lang" \
    "$(projects_used | sort -u)" "home:p4lang"
expect "LOCALBUILD_PROJECT picks the project" \
    "$(LOCALBUILD_PROJECT=home:p4lang:latest projects_used | sort -u)" "home:p4lang:latest"

dir="$(mktemp -d -p "$scratch")"
for p in home:p4lang home:p4lang:latest; do
    (cd "$dir" && LOCALBUILD_PROJECT=$p OBS_USERNAME=test "$build_pkg" --dry-run "$scratch/src" >/dev/null 2>&1)
done
expect "each project gets its own osc workdir" \
    "$(cat "$dir"/build/.osc-work/*/src/.osc/_project | sort | tr '\n' ' ')" "home:p4lang home:p4lang:latest "

exit "$fail"
