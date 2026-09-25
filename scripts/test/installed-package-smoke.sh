#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Bryan Richter
#
# SPDX-License-Identifier: Apache-2.0

#
# Smoke test the published packages the way a user installs them: add the OBS
# apt repo to a clean Ubuntu container, apt install p4lang-p4c, then drive the
# binaries -- compile a P4 program with p4c, generate tests from it with
# p4testgen, generate a fresh program with p4smith and compile that one too.
#
# Run: ./scripts/test/installed-package-smoke.sh [project] [distro]
# SMOKE_IMAGE overrides the base image (default ubuntu:22.04).

set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

project="${1:-home:p4lang}"
distro="${2:-xUbuntu_22.04}"
image="${SMOKE_IMAGE:-ubuntu:22.04}"
# OBS serves project home:p4lang:latest at .../home:/p4lang:/latest/
repo_url="https://download.opensuse.org/repositories/${project//:/:/}/${distro}/"

echo "Smoke-testing $project ($distro) in $image"
echo "  repo: $repo_url"

docker run --rm -i -e REPO_URL="$repo_url" "$image" bash -s <<'CONTAINER'
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive

fail=0; pass=0
ok() { pass=$((pass + 1)); printf '  ok    %s\n' "$*"; }
ng() { fail=$((fail + 1)); printf '  FAIL  %s\n' "$*"; }
# run <name> <cmd...> -- pass if the command exits 0, else show its tail
run() {
    local name="$1"; shift
    if "$@" >/tmp/out 2>&1; then ok "$name"; else ng "$name"; sed 's/^/        /' /tmp/out | tail -20; fi
}
# exists <name> <path> -- pass if the path is a non-empty file
exists() {
    if [[ -s "$2" ]]; then ok "$1"; else ng "$1 (missing or empty: $2)"; fi
}
die() { ng "$1"; tail -30 /tmp/apt.log | sed 's/^/        /'; echo "cannot continue"; exit 1; }

echo "== apt repo =="
apt-get update -qq >/dev/null 2>&1
apt-get install -y --no-install-recommends curl gpg ca-certificates >/tmp/apt.log 2>&1 \
    || die "install apt prerequisites"
install -d /etc/apt/keyrings
curl -fsSL "${REPO_URL}Release.key" | gpg --dearmor -o /etc/apt/keyrings/p4lang.gpg 2>/tmp/apt.log \
    || die "fetch repo signing key"
echo "deb [signed-by=/etc/apt/keyrings/p4lang.gpg] $REPO_URL ./" > /etc/apt/sources.list.d/p4lang.list
apt-get update -qq >/tmp/apt.log 2>&1 || die "apt-get update against the repo"
ok "repo added and indexed"

echo "== minimal install =="
# --no-install-recommends pins that the hard Depends alone are enough to run the
# compiler.
apt-get install -y --no-install-recommends p4lang-p4c >/tmp/apt.log 2>&1 \
    || die "apt-get install --no-install-recommends p4lang-p4c"
ok "minimal install"
if command -v cc >/dev/null 2>&1; then ok "cc available"; else ng "cc available"; fi

mkdir -p /work && cd /work
cat > basic.p4 <<'P4'
#include <core.p4>
#include <v1model.p4>

header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

struct headers_t { ethernet_t ethernet; }
struct metadata_t { }

parser ParserImpl(packet_in packet, out headers_t hdr, inout metadata_t meta,
                  inout standard_metadata_t standard_metadata) {
    state start {
        packet.extract(hdr.ethernet);
        transition accept;
    }
}

control VerifyChecksumImpl(inout headers_t hdr, inout metadata_t meta) { apply { } }

control IngressImpl(inout headers_t hdr, inout metadata_t meta,
                    inout standard_metadata_t standard_metadata) {
    action drop() { mark_to_drop(standard_metadata); }
    action forward(bit<9> port) { standard_metadata.egress_spec = port; }
    table dmac {
        key = { hdr.ethernet.dstAddr : exact; }
        actions = { forward; drop; }
        size = 1024;
        default_action = drop();
    }
    apply { dmac.apply(); }
}

control EgressImpl(inout headers_t hdr, inout metadata_t meta,
                   inout standard_metadata_t standard_metadata) { apply { } }

control ComputeChecksumImpl(inout headers_t hdr, inout metadata_t meta) { apply { } }

control DeparserImpl(packet_out packet, in headers_t hdr) {
    apply { packet.emit(hdr.ethernet); }
}

V1Switch(ParserImpl(), VerifyChecksumImpl(), IngressImpl(), EgressImpl(),
         ComputeChecksumImpl(), DeparserImpl()) main;
P4

run    "p4c runs minimally"     p4c --target bmv2 --arch v1model -o /work /work/basic.p4
rm -f /work/basic.json

echo "== full install =="
# Recommends should pull the runtime in for the default `apt install` path.
apt-get install -y p4lang-p4c >/tmp/apt.log 2>&1 || die "apt-get install p4lang-p4c"
for p in p4lang-p4c p4lang-bmv2 p4lang-pi; do
    if dpkg -s "$p" >/dev/null 2>&1; then ok "$p installed"; else ng "$p installed"; fi
done

echo "== p4c =="
run    "p4c --version"          p4c --version
run    "p4c compiles v1model"   p4c --target bmv2 --arch v1model -o /work /work/basic.p4
exists "bmv2 JSON produced"     /work/basic.json
run    "p4c emits P4Info"       p4c --target bmv2 --arch v1model -o /work \
                                    --p4runtime-files /work/basic.p4info.txt /work/basic.p4
exists "P4Info produced"        /work/basic.p4info.txt

echo "== bmv2 =="
run    "simple_switch runs"     simple_switch --help

echo "== p4testgen =="
# p4testgen and p4smith need --target/--arch even to report a version.
run    "p4testgen --version"    p4testgen --target bmv2 --arch v1model --version
mkdir -p /work/tests
run    "p4testgen generates"    p4testgen --target bmv2 --arch v1model \
                                    --test-backend STF --max-tests 5 \
                                    --out-dir /work/tests /work/basic.p4
if compgen -G "/work/tests/*.stf" >/dev/null; then
    ok "STF tests produced ($(ls /work/tests/*.stf | wc -l) files)"
else
    ng "STF tests produced (none in /work/tests)"
fi

echo "== p4smith =="
run    "p4smith --version"      p4smith --target bmv2 --arch v1model --version
run    "p4smith generates"      p4smith --target bmv2 --arch v1model --seed 1000 /work/smith.p4
exists "generated program"      /work/smith.p4
run    "p4c compiles it back"   p4c --target bmv2 --arch v1model -o /work /work/smith.p4

echo
echo "passed: $pass  failed: $fail"
[[ $fail -eq 0 ]]
CONTAINER
