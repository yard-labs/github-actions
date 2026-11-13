# github-actions

[![Latest release](https://img.shields.io/github/v/release/yard-labs/github-actions?sort=semver&label=latest)](https://github.com/yard-labs/github-actions/releases/latest)

Shared GitHub Actions from [Yard Labs](https://yardlabs.co): an automated PR
overview and a Claude code review, usable together or apart.

| Action | What it does | Rules |
|---|---|---|
| `yard-labs/github-actions/pr-overview@v1` | Posts one comment explaining the PR as diagrams: components, schema, external connections, similar code elsewhere. Never posts twice on the same PR. | `pr-overview/SKILL.md` |
| `yard-labs/github-actions/pr-review@v1` | Reviews the PR with inline comments and one summary review; approves, or asks for human review on blockers, risky or uncertain changes. | `pr-review/SKILL.md` |
| `yard-labs/github-actions/.github/workflows/claude-review.yml@v1` | Ready-made workflow running both: the overview when a PR opens, then the review, and a re-review on `@claude review`. | |

Both are advisory. Do not make either a required status check: a
non-deterministic reviewer as a merge gate blocks on its own flakiness and
teaches people to bypass it.

## Setup

- The [Claude GitHub App](https://github.com/apps/claude) installed on the repo.
- Auth, one of:
  - an `ANTHROPIC_API_KEY` secret; or
  - workload identity federation (no stored key): the
    `ANTHROPIC_FEDERATION_RULE_ID`, `ANTHROPIC_ORGANIZATION_ID`,
    `ANTHROPIC_SERVICE_ACCOUNT_ID` and `ANTHROPIC_WORKSPACE_ID` variables, on
    the repo or once for the whole organisation. The run exchanges its GitHub
    OIDC token for a short-lived Anthropic credential. The token's `sub` is the
    calling repo, so the federation rule must match on that, not on
    `job_workflow_ref`.

Repo-specific rules go in that repo's `CLAUDE.md` / `AGENTS.md`. The review
reads every one that governs a changed file.

## The ready-made workflow

Add `.github/workflows/claude-review.yml`:

```yaml
name: Claude review

on:
  pull_request:
    types: [opened, reopened, ready_for_review]
  issue_comment:
    types: [created]

concurrency:
  group: claude-review-${{ github.event.pull_request.number || github.event.issue.number }}
  cancel-in-progress: >-
    ${{ github.event_name == 'pull_request'
        || startsWith(github.event.comment.body, '@claude review')
        || startsWith(github.event.comment.body, '@claude re-review') }}

jobs:
  claude:
    uses: yard-labs/github-actions/.github/workflows/claude-review.yml@v1
    secrets: inherit # only needed for ANTHROPIC_API_KEY
    permissions:
      id-token: write
      contents: read
      pull-requests: write
```

## The actions on their own

Use them as steps in any job, on any trigger. Each needs a checkout of the PR
head with full history, and these job permissions: `contents: read`,
`pull-requests: write`, plus `id-token: write` for federation.

Review only, on every push to a PR:

```yaml
on:
  pull_request:
    types: [opened, synchronize, ready_for_review]

jobs:
  review:
    if: github.event.pull_request.draft == false
    runs-on: ubuntu-latest
    timeout-minutes: 20
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
      - uses: yard-labs/github-actions/pr-review@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
```

Overview only, when a `needs-overview` label is added:

```yaml
on:
  pull_request:
    types: [labeled]

jobs:
  overview:
    if: github.event.label.name == 'needs-overview'
    runs-on: ubuntu-latest
    timeout-minutes: 20
    permissions:
      id-token: write
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
      - uses: yard-labs/github-actions/pr-overview@v1
        with:
          anthropic_federation_rule_id: ${{ vars.ANTHROPIC_FEDERATION_RULE_ID }}
          anthropic_organization_id: ${{ vars.ANTHROPIC_ORGANIZATION_ID }}
          anthropic_service_account_id: ${{ vars.ANTHROPIC_SERVICE_ACCOUNT_ID }}
          anthropic_workspace_id: ${{ vars.ANTHROPIC_WORKSPACE_ID }}
```

Inputs, the same on both:

| Input | Default |
|---|---|
| `pr_number` | the event's PR (`pull_request` or a PR comment) |
| `github_token` | `github.token` |
| `anthropic_api_key` | empty |
| `anthropic_federation_rule_id`, `anthropic_organization_id`, `anthropic_service_account_id`, `anthropic_workspace_id` | empty |

`pr-overview` also outputs `posted`: `true` when it posted, `false` when an
overview was already there.

On an `issue_comment` trigger, check out `refs/pull/<n>/head`: the default
checkout there is the default branch, not the PR.

### Re-review a PR

Start a new top-level comment beginning with `@claude review` or
`@claude re-review`. A reply inside an inline review thread does nothing, and
the phrase must lead the comment (`startsWith`, not `contains`). Pushing
commits does not re-review.

## Versions

Releases follow [semver](https://semver.org) and are tagged automatically on
every push to `main` from [conventional commit](https://www.conventionalcommits.org)
messages:

| Commit | Release |
|---|---|
| `fix:` or `perf:` | patch, `v1.2.3` → `v1.2.4` |
| `feat:` | minor, `v1.2.3` → `v1.3.0` |
| `feat!:`, any `type!:`, or a `BREAKING CHANGE:` footer | major, `v1.2.3` → `v2.0.0` |
| anything else (`docs:`, `chore:`, `ci:`…) | no release |

Pin one of:

- **`@v1`** (recommended): moves to the newest `v1.x.y`, so you get fixes and
  features but never a breaking change.
- **`@v1.2.3`**: never moves. Upgrade by hand.
- **`@main`**: every change as it lands. Only for trying out unreleased work.

## Changing it

- A change reaches every caller on `@v1` as soon as it is released, so mark
  anything that changes inputs, permissions or behaviour callers rely on as
  breaking (`!`).
- The ready-made workflow calls the actions at `@v1`. When releasing a `v2`,
  update both `uses: yard-labs/github-actions/pr-...@v1` lines in the same commit.
- Each action copies its skill to `.review-skills/` on the runner, not
  `.claude/skills/`: `claude-code-action` replaces `.claude/` with the PR base
  branch's copy before Claude runs.
- `claude-code-action` exits without running Claude when the caller's workflow
  file differs from its default branch. A PR that edits a repo's
  `claude-review.yml` is therefore not reviewed.
- Keep the `@claude review` phrases in the callers' `concurrency` in step with
  the review job's `if`.
- `scripts/next-version.sh` decides each release; `scripts/next-version.test.sh`
  runs on every push and PR.

## Licence

MIT. The review skills adapt rules from other MIT-licensed projects; see the
attribution at the end of `pr-review/SKILL.md`.
