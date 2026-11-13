---
name: pr-overview
description: Explain a pull request (or a set of related PRs) as diagrams, sized to the change (docs, pipeline, small or large code) - how the components fit together, the core logical change and where it lives, schema changes, how external connections are secured and how they fail, and whether the idea already exists elsewhere in the repo. Use to understand a change, not to review it.
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash
argument-hint: [pr-number-or-url ...]
---

# PR overview

Overview of: $ARGUMENTS

This explains a change; `/pr-review` judges it. In CI the overview posts first and the review runs after it. Do not post review comments, approve, or merge.

Lead with pictures. Prose only labels and qualifies them.

## Gather (read-only)

- `gh pr view <n> --json title,body,state,mergedAt,baseRefName,headRefName,commits` for the PR.
- `gh pr diff <n> --name-only` to see what changed, then read the files that define structure **from the checkout** (Read/Grep), not from the diff: entrypoints, routes and servers, config and env names, migrations and schema definitions, deploy workflows and the env they sync, API clients, auth and external client modules. The repo's `CLAUDE.md` says where these live. Skip tests and docs except to cite them.
- If the checkout is not the PR's head, say so and read the PR's files with `gh pr diff` / `gh api repos/{owner}/{repo}/contents/<path>?ref=<head>` instead.
- For several PRs, work out which supersede, stack on, or replace which (base branches, "supersedes", closed vs merged times). Report what actually landed on `main`, not what was proposed.

## Size the output to the change

Decide this first, from the changed files. The overview is never longer than the change needs. A PR that touches more than one type gets the sections of each type it touches, once each.

| Type | What changed | Write |
|---|---|---|
| **Docs** | Only docs: `.md` files, docs folders, comments | The one line from step 1, plus who it is for or what a reader now does differently. Nothing else; about three lines. |
| **Pipeline** | CI and delivery config: `.github/workflows`, Dockerfiles, deploy and hosting config, git hooks, build scripts | The one line, then **Pipeline flow** (below), then step 6. No component diagram, schema, external connections or duplicate search. |
| **Small code** | Runtime code, a few lines in one or two files, with no new service, migration or connection | The one line with one `path:line` pointer; before vs after in one to three lines; anything needed for it to take effect (deploy, seed load, backfill, env var). One line on what CI does not cover, only if it matters. Under 15 lines, no diagram. |
| **Medium or large code** | A new service, migration, connection or integration, or a change across several components | Everything under Output. Skip a section the change does not touch with one line ("No schema changes", "No new connections"). |

**Pipeline flow.** One mermaid `flowchart` of the pipeline as it is after this PR: triggers (events, branches, paths) → jobs → gates (required checks, approvals, environments) → what it deploys or publishes and where. Mark new steps `[NEW]` and changed ones `[CHG]`. Under it, in a few lines: what changed in permissions, secrets and variables (names only), what now blocks or allows a merge or deploy, and what cannot be tested until the change is on the default branch.

## Output, in this order

Head the whole thing with `# PR Overview`. On an automated run the invisible `<!-- pr-overview -->` marker line stays the very first line (the review's dedupe needs it there) with the `# PR Overview` heading right after it. Put the "this is an automated overview" note directly under that heading as a one-line `>` blockquote (that is the only place it goes). Then give the change its own `## <PR title>` heading, and under it write the sections its type calls for (see Size the output to the change), in this order:

1. **One line**: what it does, why, and merged / closed-unmerged / open.

   **Core logical change.** The one behavioural change in a few lines: before vs after, as a rule or decision ("a request used to X; now it Y unless Z"). Include the key decision points (if/else, fail-open vs closed, precedence) as a tiny flow or decision table. Behaviour, never which files changed.

   **Where it lives.** The one to three places the logic actually sits: the component plus the function or class that decides it, with a clickable `path:line` pointer. Only the places that hold the core decision. Mark each on the component diagram too.

2. **Component diagram (the main output).** One mermaid `flowchart` of how the pieces fit together: callers, the services this PR adds or touches, databases, and external systems, with arrows labelled by protocol or what flows. Tag new nodes `[NEW]` and changed ones `[CHG]` in their labels. Put each trust boundary in a labelled `subgraph`. For several PRs, add a second small mermaid `flowchart` of the PR stack or timeline.

3. **Schema changes.** Read the migrations.
   - None: say "No schema changes".
   - A few: a short list of `table.column type` with the grants and RLS that came with them.
   - Many (roughly 3+ new tables, or new relationships): an ER diagram of the new tables with keys and foreign keys, drawn inside the neighbouring existing tables it connects to, new ones marked `[NEW]`. One line on where it sits in the wider schema (raw / derived / app, who writes, who reads).

4. **External connections, how they are secured, how they fail.** One table per service this change talks to or exposes: what it connects to, credential type and where it is stored or injected (GitHub environment secret or variable, host variable; never values), auth method, scope and least privilege, audit. Include inbound exposure: public domains, allowed origins, token lifetime and revocation. Flag anything unsecured or noted as a known gap.

   **Resilience, per connection:** timeout and retry policy (what is retried and what deliberately is not), pool size and exhaustion, caching (TTL, are failures cached), and the failure mode when the dependency is down (degrade, block, fail open or closed, what the user sees). Then name:
   - single points of failure (one instance, one DB role, one external account or key, a manual DNS record);
   - state lost on restart (in-memory caches, denylists, sessions);
   - blast radius if each dependency is down for 1 minute and for 1 hour;
   - how an outage is noticed (health endpoint, alert threshold, logs) or that it is not;
   - recovery: automatic, redeploy, or manual (key rotation, DNS).
   Write "not stated" where the code or PR does not say; never assume retries or redundancy exist.

5. **Similar or duplicate ideas elsewhere.** Search the codebase on the base branch, and other open PRs (`gh pr list --search`), for the same idea implemented elsewhere: a parallel auth or token flow, a second SQL guard, another pool, retry or audit wrapper, a repeated config or migration pattern, copied modules. For each match: where it lives (component + `path:line`), whether it is a true duplicate, a deliberate fork, or a lift-and-diverge copy, and whether the two can drift (a security rule fixed in one but not the other). Say if the PR builds something that already existed and was not reused. If nothing is found, say what you searched. Never claim "no duplicates" without having searched.

6. **Verified how, and risks**: two or three lines. Tests and dry runs that exist, what CI does not cover (the repo's `CLAUDE.md` names known gaps), what the author left open.

## Rules

- No file lists, file tables, or diff stats in the output. Files are read to understand the logic only.
- Answer from what you read; write "not stated" instead of guessing.
- Never print secret values: names and locations only.
- Diagrams (component and pipeline flow) are mermaid, which renders in the posted PR comment (GitHub). In a terminal it shows as the fenced source instead, which is fine. Keep each diagram small enough to read at a glance.
- Read-only. Never merge, approve, push, or edit the branch.
- Default output is to the terminal. When told this is an automated run, post it as **one** PR comment with `gh pr comment <n> --body-file <file>`; the automated-overview note is the blockquote under the `# PR Overview` heading (see Output), nowhere else.
