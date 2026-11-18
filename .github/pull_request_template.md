<!--
Write for a reviewer who does not know the code path. Leave out a section that has nothing to say,
except Tier, Integrator impact and Mitigation after release (REVIEW.md, section 4).
Add a mermaid diagram when a flow or a race is easier to see than to read.
Example: Purchasely/Purchasely-Android-Sources#1906.
-->

## What

<!--
One table of the changes the reviewer must know: the call, class or file; when it runs; before; after.
Then "Also in this PR:" with one line for each smaller change (a test fixture, a doc, a rule).
-->

## Why

<!--
"The problem in two sentences": what goes wrong, and for whom.
Then the evidence: a client case, ANR or crash counts, or the exact code path at a SHA.
Say what the PR does not claim (for example: no measured ANR reduction).
-->

## Tier

<!-- T0, T1, T2 or T3: the row of the REVIEW.md matrix that sets it, and the evidence. -->

## Integrator impact

<!-- What an integrating app sees or must do. Copy the "Impact for the application" line of the version note. "None" when apps see no difference. -->

## Mitigation after release

<!-- Backend flag (REVIEW.md rule 5), hotfix release or workaround. "Not needed" for T0. -->

## How it works

<!--
The design in short, for a change that is more than a few lines: the key code, a sequence or flow diagram,
and why this approach and not the rejected one.
-->

## How to verify

<!--
1. The exact commands, in a bash block.
2. One table: Test | What it proves | Red proof (the failure it gives on the old code).
3. What ran locally, with counts. What did not run, and why.
4. "Checklist for the reviewer": the 2 or 3 points that a reviewer must check.
-->

```bash

```

| Test | What it proves | Red proof |
|---|---|---|
|  |  |  |

### Checklist for the reviewer

- [ ]

## Notes

<!--
"Review findings": one table for the findings of Greptile, Codex, Copilot and people.
Outcome: "Fixed in <sha>", "Pushed back: <reason>", or "Follow-up: <ticket>".
Then "Other decisions": scope limits, residual risks, the feature doc, the ticket.
-->

| # | Source | Finding | Outcome |
|---|---|---|---|
|  |  |  |  |

## Checklist

- [ ] For a new or changed public method, type, component or listener: Jest tests, both native bridge test suites, and iOS and Android at parity (REVIEW.md, section 5).
- [ ] For a native SDK bump: the native pins of each platform at one version, `VERSIONS.md` and the version table of `AGENTS.md`.
- [ ] `yarn test && yarn lint && yarn typecheck` pass.
- [ ] For a workflow change: the YAML validation of `AGENTS.md`.
- [ ] Screenshots for a UI change.
- [ ] Issue links.
- [ ] The `tier:T<n>` label of the **Tier** section.
- [ ] The `run-ci` label after each push (REVIEW.md, section 5).
