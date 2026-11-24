# Workflow Contract

Rules the `coordinator` follows. The state machine is logical. Its state lives in `.devai/work-items/WI-NNN/state.json` and is validated by `state.schema.json`.

This is checkpoint-based resumption. VS Code does not provide durable execution, so the coordinator must be able to rebuild its position from files.

## 1. Work item types and depth

One workflow serves every type of work. The coordinator sets `type` and `depth` at creation and records them in `state.json`.

| Type | Examples |
| ---- | -------- |
| `feature` | New capability |
| `bugfix` | Defect correction |
| `maintenance` | Dependency, configuration, operational change |
| `refactor` | Structure change with the same behavior |
| `modernization` | Framework, language or platform upgrade |

| Depth | When | Adjustments |
| ----- | ---- | ----------- |
| `light` | Small, local change in a known area | Short spec. Targeted discovery. A single task phase. |
| `standard` | Default | Full artifacts. |
| `deep` | Cross-cutting, risky or poorly understood change | Full artifacts, wider discovery scope, `failure-discovery` allowed from the first failure. |

`mode` is `greenfield` when the repository has no relevant production code, otherwise `brownfield`. In greenfield, `codebase-discovery` and `feature-discovery` record that nothing exists and examine only the chosen template, toolchain and conventions. A skipped stage is recorded in `history` with the reason. A stage is never skipped silently.

Depth changes how much work each stage does. It never removes review, testing or the Definition of Done.

## 2. States

| State | Meaning | Active agents |
| ----- | ------- | ------------- |
| `CREATED` | Request registered, work item directory created. | coordinator |
| `SPECIFYING` | Specification and targeted discovery. | requirements, feature-discovery, codebase-discovery |
| `PLANNING` | Technical plan and tasks. | architect, discovery agents on request |
| `WAITING_USER` | Needs a user decision or approval. | none |
| `IMPLEMENTING` | Executing tasks. | developer |
| `REVIEWING` | Code review. | code-reviewer |
| `TESTING` | Functional validation against acceptance criteria. | qa-tester |
| `DOCUMENTING` | Documentation update and build. | documenter |
| `RECOVERING` | Handling a failure. | failure-discovery, or the agent chosen by the recovery policy |
| `BLOCKED` | Needs intervention that the workflow cannot provide. | none |
| `COMPLETED` | Delivery verified. | none |

## 3. Transitions

| From | Event | To |
| ---- | ----- | -- |
| `CREATED` | Objective, type and depth set | `SPECIFYING` |
| `SPECIFYING` | `spec.md` complete, required discovery done | `PLANNING` |
| `SPECIFYING` | Question blocks acceptance criteria | `WAITING_USER` (resume `SPECIFYING`) |
| `PLANNING` | Open questions remain, or `require_plan_approval` is true | `WAITING_USER` (resume `PLANNING` or `IMPLEMENTING`) |
| `PLANNING` | Plan and tasks complete, no open blocking question, approval not required or already given | `IMPLEMENTING` |
| `WAITING_USER` | User answers or approves | The state stored in `waitingFor.resumeStatus`. `decisions` is updated first. |
| `IMPLEMENTING` | All required tasks done, build and unit tests pass | `REVIEWING` |
| `IMPLEMENTING` | Developer returns `NEEDS_REQUIREMENTS` or `NEEDS_REPLAN` | `RECOVERING` |
| `REVIEWING` | Verdict `APPROVED` (no blocking findings) | `TESTING` |
| `REVIEWING` | Verdict `CHANGES_REQUIRED` | `RECOVERING`. QA is not run. |
| `TESTING` | Every acceptance criterion `PASSED` | `DOCUMENTING` |
| `TESTING` | Any required case `FAILED` | `RECOVERING` |
| `TESTING` | Required case `NOT_RUN` or `BLOCKED` | `RECOVERING` if the coordinator can fix the cause, otherwise `BLOCKED` |
| `DOCUMENTING` | Documentation updated and `mkdocs build --strict` passes (or documentation disabled in config) | Delivery check, then `COMPLETED` |
| `DOCUMENTING` | Documentation build fails | `RECOVERING` |
| `RECOVERING` | Fix routed and finished | The first state of the invalidation chain (section 6) |
| any | Attempt limit reached, no verifiable progress, missing credential or environment | `BLOCKED` |
| `BLOCKED` | User resolves the cause and resumes | The state stored in `recovery.returnTo`, or a state chosen by the user |

`COMPLETED` is final. New work on the same feature opens a new work item.

## 4. Phase gates

| Phase | Advance when |
| ----- | ------------ |
| 1. Specification | `spec.md` has objective, scope, requirements, business rules and acceptance criteria. Every `AC` is observable and testable. Required discovery is `DONE`. |
| 2. Planning | `plan.md` and `tasks.md` exist. Every `FR`, `NFR`, `BR` and `AC` is covered by at least one task. Every evidence entry the plan depends on is `verified`, or is `inferred` with a recorded risk. No open question is blocking. Plan approved when `require_plan_approval` is true. |
| 3. Implementation | Every required task is checked. Build and unit tests ran and passed, or the reason they could not run is recorded. |
| 4. Review | `review.md` has no `blocking` finding. |
| 5. Validation | `qa-report.md` shows every `AC` `PASSED` with evidence. Regression suite ran when `quality.regression_testing` is true. |
| 6. Documentation | Feature documentation matches the delivered behavior. `mkdocs build --strict` passes. |
| 7. Delivery | Section 9 checklist verified by the coordinator. |

Plan approval is requested with a short summary of the spec, the acceptance criteria, the plan approach, the task count and the decisions taken. The user can approve, request changes or answer questions.

## 5. Recovery policy

### Routing

| Failure | Route to |
| ------- | -------- |
| Simple compile or lint error | `developer` |
| Incorrect implementation | `developer` |
| Review finding with route `developer` | `developer` |
| Review finding with route `architect`, technical component not considered, inadequate architecture | `architect` |
| Incorrect or missing business rule, missing or ambiguous requirement | `requirements` |
| Insufficient technical evidence | `codebase-discovery` |
| Unknown existing behavior | `feature-discovery` |
| Complex, unclear or recurring failure | `failure-discovery`, then the route in its report |
| Missing credential, environment or access | `BLOCKED` or user |

Return to the earliest stage that actually caused the problem. Do not go back to specification for a failure that belongs to implementation.

### Problems and attempts

- The coordinator records each distinct failure as a problem `P-NNN` in `state.json`, keyed by `signature`.
- A new failure with an existing signature increments that problem's `attempts`. A new signature creates a new problem.
- The limit is `workflow.max_recovery_attempts` (default 3) attempts per problem.
- Run `failure-discovery` when the cause is unclear, when a problem reaches its second attempt, or when a fix causes a regression. In `deep` depth it is allowed from the first failure.
- Enter `BLOCKED` when a problem exceeds the limit, when two consecutive attempts produce no verifiable progress (same failure, same evidence), or when a business decision is needed and the user has not given it.
- `BLOCKED` records `blockedReason` with the problem, the attempts made, what was learned and what is needed from the user.
- `iteration` increases by one every time the workflow enters `RECOVERING`.

### Fix integrity

During recovery nobody may weaken tests, remove acceptance criteria or loosen requirements to make a failure disappear. A requirement changes only through `requirements`, with a recorded reason.

## 6. Invalidation after recovery

Each gate in `state.json` is `PENDING`, `PASSED`, `FAILED` or `STALE`. When an upstream artifact changes, every dependent gate becomes `STALE` and its stage is run again.

| Change in | Re-run, in order |
| --------- | ---------------- |
| `spec.md` (`specRevision` increases) | architect (`update`), affected tasks, review, QA, documentation |
| `plan.md` or `tasks.md` (`planRevision` increases) | affected tasks, review, QA, documentation |
| Source code | review, QA. Documentation when behavior or interfaces changed. |
| Discovery artifacts | The agent that requested them, then the chain above for whatever it changes. |
| Documentation only | Documentation build. |

The coordinator runs only the stale stages. QA re-runs the cases tied to affected acceptance criteria plus the regression suite.

## 7. Delegation rules

1. Write-ahead: update `state.json` (status, `currentTask`, `history`) before delegating. Update it again after the result arrives.
2. One objective per call. Use the task request in `agent-protocol.md`.
3. Discovery agents may run in parallel when the environment allows. Everything else is sequential.
4. Implementation proceeds task by task. After each task the developer ticks the checkbox and the coordinator mirrors it into `completedTasks`.
5. Verify, do not trust. After a specialist returns `DONE`, check that its artifacts exist, follow the template and contain the required sections. Check that `notRun` is empty or acceptable.
6. A specialist result that violates the protocol (no result block, claims without evidence, missing sections) is sent back once with the specific defect. A second violation counts as a failed attempt.
7. Never perform a specialist's work yourself, except writing `state.json` and the work item directory scaffolding.

## 8. Resume and reconcile

On `/workflow-resume` the coordinator does not trust `state.json` alone.

1. Locate the work item. If several are not `COMPLETED`, ask the user which one.
2. Validate `state.json` against the schema. If it is missing or invalid, rebuild it from the artifacts and mark `history` with `reconstructed`.
3. Check that the artifacts required for the recorded status exist and are complete.
4. Compare `tasks.md` checkboxes with `completedTasks`. Files win. Correct the state.
5. Compare the workspace against `baseline` (`git status`, `git diff --name-only <vcsRef>`). Identify changes made outside the workflow. Preserve them. Mark affected evidence for revalidation.
6. Compare artifact revisions with `Based on` headers and mark stale gates.
7. Check whether the last `history` entry has a matching result. If a delegation started and no result exists, inspect the artifacts it should have produced, then repeat the call with mode `update` or `revalidate`. Do not assume the earlier call succeeded or failed.
8. Record the reconciliation in `history`, report to the user what was found and continue from the reconciled status.

If reconciliation cannot determine a consistent position, ask the user. Do not guess.

## 9. Definition of Done

The coordinator marks `COMPLETED` only after verifying each item against files and results, not against what an agent said.

- [ ] Requirements and acceptance criteria defined.
- [ ] Discovery done with verifiable evidence.
- [ ] Blocking questions resolved and recorded in `decisions`.
- [ ] Plan approved according to policy.
- [ ] All required tasks completed.
- [ ] Build and technical validations passed, when applicable.
- [ ] Code review has no blocking findings.
- [ ] Required tests executed and passed.
- [ ] Acceptance criteria validated by QA.
- [ ] Functional documentation updated and validated.
- [ ] No blocking failure pending.
- [ ] State and evidence recorded in the work item.

The delivery message to the user lists, for each item, the artifact or command output that proves it. It also lists non-blocking review findings, `NOT_RUN` items accepted by the user and follow-up suggestions. Delivery never commits, pushes or deploys unless `config.yaml` and the user allow it.

## 10. User interaction

- Present decisions together, once per planning round, in this form:

  ```text
  Decision needed: <short title>
  Context: <why it matters, one or two sentences>
  Options: <A, B>
  Recommendation: <option and reason>
  ```
- Answer-ready: the user can reply "accept recommendations".
- Do not interrupt the user between phases when no decision or approval is needed. Report progress briefly at phase changes.
