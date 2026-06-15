#!/usr/bin/env bash
#
# Cut a release locally.
#
#   scripts/release.sh <major.minor.patch>
#
# Bumps the VERSION file, promotes the CHANGELOG "[Unreleased]" section to the
# new version, runs the smoke checks, commits, and creates an annotated tag.
# Pushing the commit and tag is left to you:
#
#   git push origin main --follow-tags
#
# Pushing the tag triggers .github/workflows/release.yml, which publishes the
# GitHub release using the matching CHANGELOG section as the release notes.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

version="${1:-}"
repo='https://github.com/cengebretson/tmux-fzf-jump'

if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "usage: scripts/release.sh <major.minor.patch>" >&2
    exit 1
fi

tag="v${version}"

if [[ -n "$(git status --porcelain)" ]]; then
    echo "working tree is not clean; commit or stash first" >&2
    exit 1
fi

if git rev-parse -q --verify "refs/tags/${tag}" >/dev/null; then
    echo "tag ${tag} already exists" >&2
    exit 1
fi

prev_tag="$(git describe --tags --abbrev=0 2>/dev/null || true)"
date_str="$(date +%Y-%m-%d)"

# Bump the version file.
printf "%s\n" "${version}" > VERSION

# Promote [Unreleased] to a dated section and refresh the comparison links.
awk -v ver="${version}" -v d="${date_str}" -v tag="${tag}" -v prev="${prev_tag}" -v repo="${repo}" '
    /^## \[Unreleased\]/ && !promoted {
        print
        print ""
        print "## [" ver "] - " d
        promoted = 1
        next
    }
    /^\[Unreleased\]:/ {
        print "[Unreleased]: " repo "/compare/" tag "...HEAD"
        if (prev != "")
            print "[" ver "]: " repo "/compare/" prev "..." tag
        else
            print "[" ver "]: " repo "/releases/tag/" tag
        next
    }
    { print }
' CHANGELOG.md > CHANGELOG.md.tmp
mv CHANGELOG.md.tmp CHANGELOG.md

echo "Running smoke checks..."
tests/check.sh

git add VERSION CHANGELOG.md
git commit -m "Release ${tag}"
git tag -a "${tag}" -m "${tag}"

cat <<EOF

Tagged ${tag}.

Review the commit and changelog, then publish with:

  git push origin main --follow-tags

EOF
