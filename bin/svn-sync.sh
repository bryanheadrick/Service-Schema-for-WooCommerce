#!/usr/bin/env bash
#
# Stages the .distignore-filtered plugin files into the local WordPress.org
# SVN working copy at svn/ (trunk/ and tags/{version}/, version read from
# readme.txt).
#
# This does NOT run `svn add`, `svn rm`, or `svn commit` — it only syncs
# files so `svn status` in the SVN checkout shows you exactly what changed.
# Review that diff, then add/commit yourself.
#
# Usage:
#   bin/svn-sync.sh

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SLUG="catmanstudios-systems-service-schema-for-woocommerce"
SVN_DIR="$PLUGIN_DIR/svn"

if [[ ! -d "$SVN_DIR/.svn" ]]; then
    echo "Error: $SVN_DIR does not look like an SVN working copy (no .svn/)." >&2
    echo "Check one out first, e.g.:" >&2
    echo "  svn checkout https://plugins.svn.wordpress.org/$SLUG $SVN_DIR" >&2
    exit 1
fi

VERSION=$(grep -m1 "^Stable tag:" "$PLUGIN_DIR/readme.txt" | sed 's/Stable tag: *//')

BUILD_ROOT="$(mktemp -d)"
trap 'rm -rf "$BUILD_ROOT"' EXIT

grep -v '^#' "$PLUGIN_DIR/.distignore" | grep -v '^$' > "$BUILD_ROOT/exclude.txt"

sync_target() {
    local dest="$1"
    mkdir -p "$dest"
    rsync -a --delete \
        --exclude-from="$BUILD_ROOT/exclude.txt" \
        --exclude ".svn" \
        "$PLUGIN_DIR/" "$dest/"
}

echo "Syncing v$VERSION into $SVN_DIR/trunk/"
sync_target "$SVN_DIR/trunk"

echo "Syncing v$VERSION into $SVN_DIR/tags/$VERSION/"
sync_target "$SVN_DIR/tags/$VERSION"

cat <<EOF

Done. This only synced plugin files (per .distignore) into:
  trunk/ and tags/$VERSION/

It did NOT touch the top-level SVN assets/ dir (screenshots/banners/icon
for your WP.org listing) — manage that separately.

Next steps, from inside $SVN_DIR:
  svn status
  svn add --force trunk tags/$VERSION
  svn status | grep '^!' | awk '{print \$2}' | xargs -r svn rm
  svn commit -m "Update to $VERSION"
EOF
