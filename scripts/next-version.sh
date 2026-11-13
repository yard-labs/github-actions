#!/usr/bin/env bash
# Usage: git log --format='%s%n%b' <last-tag>..HEAD | next-version.sh [last-tag]
# Prints the next vX.Y.Z from conventional commit messages, or nothing when no
# release is due (only docs, chore, ci, test or refactor commits).
set -euo pipefail

last=${1:-}
msgs=$(cat)

if grep -Eq '^[a-z]+(\([^)]*\))?!:|^BREAKING CHANGE:' <<<"$msgs"; then bump=major
elif grep -Eq '^feat(\([^)]*\))?:' <<<"$msgs"; then bump=minor
elif grep -Eq '^(fix|perf)(\([^)]*\))?:' <<<"$msgs"; then bump=patch
else exit 0
fi

if [ -z "$last" ]; then echo v1.0.0; exit 0; fi

IFS=. read -r major minor patch <<<"${last#v}"
case $bump in
  major) echo "v$((major + 1)).0.0" ;;
  minor) echo "v$major.$((minor + 1)).0" ;;
  patch) echo "v$major.$minor.$((patch + 1))" ;;
esac
