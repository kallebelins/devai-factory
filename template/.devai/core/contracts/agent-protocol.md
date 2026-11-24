# Agent Protocol

Contract between the `coordinator` and the specialist agents. Every specialist follows it. The coordinator relies on it.

## 1. Principles

- The coordinator delegates one bounded objective per call. A specialist does that objective and nothing else.
- A specialist never asks the user anything and never invokes another agent. It returns questions and discovery needs in its result report.
- Agents communicate through files in the work item directory and through the two messages below. They do not rely on conversation memory.
- Pass paths, not contents. Read only what the objective needs.

## 2. Task request (coordinator to specialist)

The coordinator starts every delegation with this block.

```yaml
task:
  workItem: WI-001
  objective: One sentence describing the single outcome expected.
  mode: create          # create | update | revalidate
  inputs:               # files to read, relative to the repository root
    - .devai/work-items/WI-001/spec.md
  outputs:              # the only artifacts this agent may write (plus source code for developer)
    - .devai/work-items/WI-001/plan.md
  context:              # only what this call needs
    specRevision: 1
    planRevision: 0
    baseline: { vcsRef: "abc1234", capturedAt: "2025-01-01T10:00:00Z" }
    decisions: []       # user decisions relevant to this call (D-001 ...)
    problem: null       # P-001 when this call is part of a recovery
    scope: "Short description of the area to focus on"
```

Modes:

| Mode | Meaning |
| ---- | ------- |
| `create` | Produce the artifact from scratch using the template. |
| `update` | Change an existing artifact because an input changed. Increment its revision. Keep stable IDs. |
| `revalidate` | Re-check existing evidence or results against the current workspace. Do not rewrite what is still valid. |

## 3. Result report (specialist to coordinator)

The final message of a specialist is exactly one fenced `yaml` block named `result`, optionally followed by a short note. Do not paste artifact contents into it.

```yaml
result:
  workItem: WI-001
  agent: architect
  status: DONE
  summary: One to three sentences.
  artifacts:
    - path: .devai/work-items/WI-001/plan.md
      revision: 1
  verdict: null            # reviewer: APPROVED | CHANGES_REQUIRED. qa-tester: PASSED | FAILED | INCOMPLETE
  questions: []            # see section 5
  discoveryRequests: []    # see section 6
  failure: null            # see section 7
  recommendedRoute: null   # developer | architect | requirements | feature-discovery | codebase-discovery | failure-discovery | user
  notRun: []               # checks that were required but not executed, each with the reason
```

### Status values

| Status | Meaning | Required fields | Coordinator action |
| ------ | ------- | --------------- | ------------------ |
| `DONE` | Objective complete and artifact written. | `artifacts`, `verdict` when applicable | Continue the workflow. Check `verdict` and `notRun`. |
| `NEEDS_USER_DECISION` | A decision only the user can make blocks progress. | `questions` | Go to `WAITING_USER`. |
| `NEEDS_DISCOVERY` | Evidence is insufficient. | `discoveryRequests` | Run the requested discovery, then call the same agent again in `update` mode. |
| `NEEDS_REQUIREMENTS` | A requirement or business rule is missing, ambiguous or wrong. | `summary`, `recommendedRoute: requirements` | Route to `requirements`. |
| `NEEDS_REPLAN` | The plan or architecture cannot deliver the requirement. | `summary`, `recommendedRoute: architect` | Route to `architect`. |
| `FAILED` | The agent did its work and a check failed (build, test, review, validation). | `failure` | Apply the recovery policy. |
| `BLOCKED` | The agent cannot proceed because of environment, access or credentials. | `summary`, `recommendedRoute: user` | Go to `BLOCKED`, or to `WAITING_USER` if the user can fix it now. |

A specialist must not return `DONE` when a required check was not run. It lists the check in `notRun` and returns `BLOCKED` or `DONE` with `verdict: INCOMPLETE` where the role defines it.

## 4. Evidence model

Every claim about the existing system carries evidence. Discovery, plan and review artifacts use this table.

| ID | Claim | Source | Status | Checked at |
| -- | ----- | ------ | ------ | ---------- |
| E-001 | Short factual statement | `path/to/file.ext:42` or command or document | verified | `abc1234` |

| Status | Definition | May support a decision? |
| ------ | ---------- | ----------------------- |
| `verified` | The source was opened or the command was run during this work item and confirmed the claim. | Yes |
| `inferred` | Deduced from verified evidence or naming conventions. State the basis in the claim. | Only with a recorded risk. |
| `unknown` | Could not be determined with the available tools or access. Also lists the question to resolve it. | No. Resolve it by discovery or by asking the user. |
| `new` | A component the change will create. Used only in `plan.md` and `tasks.md`. | Yes, as a proposal. Never describe it as existing. |

Rules:

- A search that finds nothing is evidence of absence only within the searched scope. Record the scope: `Not found in src/Auth/** by search "ResetToken"`.
- `Checked at` is the `baseline.vcsRef` when a VCS exists. Without a VCS, use the ISO date and time.
- Evidence IDs are stable inside an artifact. New evidence takes the next number. Never reuse an ID.

### Revalidation

The workspace can change during a work item. Before relying on evidence, `architect` and `developer` revalidate the entries they depend on:

1. Find changed files since the baseline: `git diff --name-only <vcsRef>` plus untracked files. Without a VCS, compare modification times with `baseline.capturedAt`.
2. For every evidence entry whose source is in that set, re-open the source and re-check the claim.
3. If a claim is no longer true, mark it `unknown` or correct it, and return `NEEDS_DISCOVERY` or `NEEDS_REPLAN` when it affects the plan.
4. The coordinator updates `baseline` after a successful revalidation.

## 5. Questions

```yaml
questions:
  - id: Q-001
    question: What is the expiration time of the reset token?
    why: Defines security exposure and AC-003.
    blocking: true                 # true if work cannot continue without the answer
    recommendation: 15 minutes
    owner: requirements            # who must incorporate the answer: requirements | architect
```

- Record only questions that existing code, documentation or patterns cannot answer.
- Specialists write questions in the `Open Questions` section of their artifact, using the same IDs.
- During specification and discovery, record questions and continue. Return `NEEDS_USER_DECISION` during those phases only when the answer is required to write acceptance criteria.
- `architect` consolidates all open questions into one deduplicated list. The coordinator presents them in a single interaction.
- A `developer`, `code-reviewer` or `qa-tester` that finds a missing business rule returns `NEEDS_REQUIREMENTS`. It never invents the rule.
- User answers are stored by the coordinator in `state.json` as `decisions` (`D-001`). The owner agent applies them to its artifact on the next call and clears the question.

## 6. Discovery requests

```yaml
discoveryRequests:
  - kind: codebase               # feature | codebase
    question: How are password hashes verified and where?
    reason: Needed to decide where the reset flow writes the new hash.
    scope: src/Auth/**
```

`requirements` and `architect` request investigations this way. The coordinator runs `feature-discovery` or `codebase-discovery` with the request as `objective` and `scope`, then calls the requesting agent again with mode `update`. Discovery is always targeted at the requested scope, never the whole repository.

## 7. Failure details

```yaml
failure:
  stage: implementing            # implementing | reviewing | testing | documenting
  signature: "build:CS0246:src/Auth/ResetService.cs"
  description: What failed.
  evidence: Command and the relevant excerpt, secrets removed.
  suspectedCause: Optional.
  recommendedRoute: developer
```

`signature` identifies the problem. The same check failing for the same reason produces the same signature. The coordinator uses it to count recovery attempts per problem.

## 8. Identifier scheme

| Prefix | Meaning | Owner |
| ------ | ------- | ----- |
| `WI-NNN` | Work item | coordinator |
| `FR-`, `NFR-`, `BR-`, `AC-` | Functional, non-functional requirement, business rule, acceptance criterion | requirements |
| `Q-` | Open question | any specialist |
| `D-` | User decision | coordinator |
| `E-` | Evidence entry | the artifact author |
| `T` + number | Task (`T001`) | architect |
| `RV-` | Review finding | code-reviewer |
| `TC-` | QA test case | qa-tester |
| `FL-` | Failure analysis finding | failure-discovery |
| `P-` | Recovery problem | coordinator |
| `R-` | Risk | architect |

IDs are never renumbered or reused. A removed item is marked `withdrawn` and keeps its ID.

## 9. Traceability

- Each acceptance criterion traces to one or more requirements.
- Each task lists the `FR`/`NFR`/`BR`/`AC` IDs it satisfies.
- Each QA test case lists the `AC` IDs it validates. Every `AC` needs at least one test case.
- Each review finding names the file and, when possible, the task.

## 10. Artifact ownership

Only the owner writes an artifact. Others read it.

| Artifact | Owner (writes) | Notes |
| -------- | -------------- | ----- |
| `state.json` | `coordinator` | Only the coordinator writes it. |
| `spec.md` | `requirements` | Increments `specRevision` on every change. |
| `feature-discovery.md` | `feature-discovery` | |
| `codebase-discovery.md` | `codebase-discovery` | |
| `plan.md`, `tasks.md` | `architect` | `developer` may only tick task checkboxes in `tasks.md`. Increments `planRevision`. |
| Source code, unit tests | `developer` | Within the scope of the current task. |
| `review.md` | `code-reviewer` | |
| `qa-report.md`, functional tests | `qa-tester` | May not change production code. |
| `failure-report.md` | `failure-discovery` | Investigates, never fixes. |
| `docs/**`, `mkdocs.yml` | `documenter` | |

## 11. Artifact header

Every work item artifact starts with this header, kept up to date by its owner:

```markdown
> Work item: WI-001 | Revision: 1 | Status: draft
> Based on: spec r1, plan r1
```

`Based on` records the upstream revisions used. When an upstream revision is higher than the one recorded, the artifact is stale and the coordinator schedules an `update` or `revalidate` call.
