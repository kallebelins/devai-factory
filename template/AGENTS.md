<!-- software-factory:begin -->
<!-- Managed by the AI Software Factory. Replaced on upgrade. Add project rules outside this block or in .github/instructions/. -->

# AI Software Factory

This repository runs a specification-driven, evidence-based, multi-agent workflow for greenfield and brownfield work, in any language or framework.

The user states a need and takes part in the relevant decisions. The factory delivers an implemented, reviewed, tested and documented change.

## How it works

- Entry points are the skills `/workflow-start`, `/workflow-resume` and `/workflow-status`. Run them with the `coordinator` agent selected.
- The `coordinator` is the only agent that drives the workflow. Every other agent is a specialist: it receives one bounded objective, writes its artifact, returns a result report and stops.
- Specialists never talk to the user and never invoke other agents. They report questions and discovery needs to the coordinator.
- Each piece of work is a work item in `.devai/work-items/WI-NNN/`. The files there are the shared memory between agents.

## Layout

| Path | Owner | Content |
| ---- | ----- | ------- |
| `.github/agents/` | factory | The ten agents |
| `.github/skills/workflow-*/` | factory | Entry commands |
| `.devai/core/` | factory | Contracts, templates, version. Do not edit. |
| `.devai/config.yaml` | project | Factory settings |
| `.devai/work-items/` | project | Work item artifacts and state |
| `.github/instructions/` | project | Project-specific rules |

Read these before acting in the workflow:

| File | Defines |
| ---- | ------- |
| `.devai/core/contracts/agent-protocol.md` | Task request, result report, evidence model, IDs, artifact ownership |
| `.devai/core/contracts/workflow.md` | States, transitions, recovery policy, Definition of Done |
| `.devai/core/contracts/state.schema.json` | Shape of `state.json` |
| `.devai/config.yaml` | Factory settings |
| `.devai/core/templates/work-item/` | Artifact templates |

## Universal rules

1. Work from verifiable evidence. Never assume a file, API, dependency or behavior exists. Open it and confirm.
2. Respect the existing architecture, language, conventions and patterns of the project.
3. Prefer the simplest solution that satisfies the requirements.
4. Do not expand the scope without the user's authorization.
5. Do not change tests or requirements only to hide a failure.
6. Do not claim success without running the relevant validation. Record what you could not run as `NOT_RUN` or `BLOCKED`, never as passed.
7. Record relevant doubts for the user to decide. Do not decide business rules silently. Do not ask about trivial technical choices that existing patterns already answer.
8. Preserve existing changes in the workspace. Do not revert work you did not make.
9. Never expose secrets, credentials or sensitive data in files, logs or reports.
10. Do not publish, deploy, commit, push or run destructive operations without explicit authorization. `config.yaml` sets the defaults.

## Conventions

- All factory files and generated artifacts are written in English. Chat with the user follows the language the user writes in.
- Evidence is classified as `verified`, `inferred`, `unknown` or `new`. See the agent protocol.
- Pass file paths between agents, not file contents. Read only what the objective needs.
- Project-specific rules go in `.github/instructions/`, not in agent files.

<!-- software-factory:end -->
