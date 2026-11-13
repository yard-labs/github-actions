#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

fails=0
check() {
  local expected=$1 last=$2 msgs=$3 got
  got=$(printf '%s\n' "$msgs" | ./next-version.sh "$last")
  if [ "$got" != "$expected" ]; then
    echo "FAIL: last=$last msgs=$(printf %q "$msgs") expected=$expected got=$got"
    fails=$((fails + 1))
  fi
}

check v1.0.0 ""      "feat: first release"
check ""     "v1.2.3" "docs: tidy README"
check ""     "v1.2.3" "chore(deps): bump x"
check v1.2.4 "v1.2.3" "fix: handle empty diff"
check v1.2.4 "v1.2.3" "perf(review): fewer API calls"
check v1.3.0 "v1.2.3" $'fix: a\nfeat(overview): b'
check v2.0.0 "v1.2.3" "feat!: drop API key auth"
check v2.0.0 "v1.2.3" "refactor(skills)!: rename inputs"
check v2.0.0 "v1.2.3" $'feat: x\n\nBREAKING CHANGE: inputs renamed'
check ""     "v1.2.3" "feature: not conventional"

[ "$fails" -eq 0 ] && echo "next-version: all checks passed"
exit "$fails"
