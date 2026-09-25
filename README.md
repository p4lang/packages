<!--
SPDX-FileCopyrightText: 2026 Bryan Richter

SPDX-License-Identifier: Apache-2.0
-->

[![p4c](https://build.opensuse.org/projects/home:p4lang/packages/p4lang-p4c/badge.svg?type=ratio)](https://build.opensuse.org/package/show/home:p4lang/p4lang-p4c)
[![BMv2](https://build.opensuse.org/projects/home:p4lang/packages/p4lang-bmv2/badge.svg?type=ratio)](https://build.opensuse.org/package/show/home:p4lang/p4lang-bmv2)
[![PI](https://build.opensuse.org/projects/home:p4lang/packages/p4lang-pi/badge.svg?type=ratio)](https://build.opensuse.org/package/show/home:p4lang/p4lang-pi)

# P4 Packages

This repo has tooling and metadata for building OS-specific binary packages for
the P4 ecosystem: [PI](https://github.com/p4lang/PI), [BMv2](https://github.com/p4lang/behavioral-model), and [p4c](https://github.com/p4lang/p4c).

Currently the targets are a few Debian-based distributions, with plans to
support more.

Packages are availale on the [Open Build Service](https://build.opensuse.org/project/show/home:p4lang),
which builds the binaries and hosts the apt repositories.

Each `p4lang-*/` directory holds one package's `debian/` files. The upstream
source is fetched at packaging time, at the version named by the package's
changelog.

## Tooling

Everything is driven by [`just`](https://just.systems); `just --list` shows
recipes for cutting changelog entries, generating and uploading the source
packages, and building them locally in an OBS-faithful VM — with a cached
offline fast path — to develop and inspect a package without waiting on OBS.
The development environment comes from the Nix flake (`nix develop`).
