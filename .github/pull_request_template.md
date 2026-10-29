## What

<!-- What the PR changes, in a few lines. -->

## Why

<!-- The problem or the request. Link the issue. -->

## Tier

<!-- T0, T1, T2 or T3: the row of the REVIEW.md matrix that sets it, and the evidence. -->

## Integrator impact

<!-- What an integrating app sees or must do. "None" when apps see no difference. -->

## Mitigation after release

<!-- Backend flag (REVIEW.md rule 5), hotfix release or workaround. "Not needed" for T0. -->

## How to verify

<!-- The commands, the tests and the manual steps that show the change works. -->

## Notes

<!-- Anything else for the reviewers. Remove the section if empty. -->

## Checklist

- [ ] The `tier:T<n>` label of the **Tier** section.
- [ ] `yarn test && yarn lint && yarn typecheck` pass.
- [ ] CI ran on the head commit: after each push, add the `run-ci` label.
- [ ] Public API change: Jest tests, both native bridge test suites, iOS and Android at parity, update the API report (`yarn api:update`).
- [ ] Native SDK bump: all native pins at the same version, `VERSIONS.md` and the version table of `AGENTS.md`.
- [ ] Workflow change: the YAML validation of `AGENTS.md`.
