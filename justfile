# SPDX-FileCopyrightText: 2026 Bryan Richter
#
# SPDX-License-Identifier: Apache-2.0

# OBS project to push to
obs_project := "home:p4lang"

# Check that scripts, justfile, and workflows are self-consistent.
smoke:
    ./scripts/smoke

# Add a changelog entry. The trailer identity is DEBFULLNAME/DEBEMAIL if set,
# else git's.
changelog-add package:
    DEBFULLNAME="${DEBFULLNAME:-$(git config user.name)}" \
    DEBEMAIL="${DEBEMAIL:-$(git config user.email)}" \
        dch --changelog p4lang-{{package}}/changelog --distribution unstable

# Start a changelog entry for new upstream <tag> at Debian revision 1.
changelog-upstream-add package tag:
    DEBFULLNAME="${DEBFULLNAME:-$(git config user.name)}" \
    DEBEMAIL="${DEBEMAIL:-$(git config user.email)}" \
        dch --changelog p4lang-{{package}}/changelog \
        --newversion {{trim_start_match(tag, "v")}}-1 \
        --distribution unstable \
        Upstream release

# Generate build/<package> source package at the version in its changelog.
generate-src-pkg package:
    ./scripts/generate-src-pkg {{package}}

# Build .dsc locally via osc-in-Docker: [--clean|--dry-run] <srcdir> [repo] [arch]
build-pkg +args:
    ./scripts/build-pkg {{args}}

# Build <package> at its changelog version and upload it to the latest channel's OBS project.
upload-src-pkg package: (generate-src-pkg package)
    ./scripts/upload-src-pkg {{obs_project}} p4lang-{{package}} build/{{package}}

# Upload every level of the pi/bmv2/p4c stack that can move without skipping a level.
upload-stack:
    ./scripts/upload-stack {{obs_project}}

# Drop the cached build image so the next build-pkg re-provisions it.
clean-image:
    docker rmi obs-build-image

# Wipe build-package's cached buildroot + package cache.
clean-buildroot:
    docker run --rm --mount type=bind,source=$PWD/build,target=/x obs-build-image \
        sh -c 'rm -rf /x/.osc-buildroot /x/.osc-cache /x/.osc-work'
