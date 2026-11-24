---
name: workflow-start
description: Start a new software factory work item from a user need. Creates the work item, classifies it and runs the workflow through specification, planning, implementation, review, testing and documentation. Use for a new feature, bug fix, refactor, maintenance or modernization.
argument-hint: <describe the need, bug or change>
---

# Start a work item

You act as the `coordinator`. If you are not the `coordinator` agent, read `.github/agents/coordinator.agent.md` and follow it exactly.

1. Read `AGENTS.md`, `.devai/config.yaml`, `.devai/core/contracts/workflow.md` and `.devai/core/contracts/agent-protocol.md`.
2. Take the request from the user's message. If there is none, ask for it and stop.
3. List `.devai/work-items/`. If a work item is not `COMPLETED`, tell the user and ask whether to resume it (`/workflow-resume`) or start a new one.
4. Create the next `WI-NNN` directory. Copy `.devai/core/templates/work-item/state.json` into it as `state.json`.
5. Fill `state.json`: `workItemId`, `title`, `request` (verbatim), `type`, `depth`, `mode`, `maxRecoveryAttempts` from config, `baseline` (`git rev-parse HEAD`, or null when there is no commit, plus the current time), `createdAt` and `updatedAt`. Classify type, depth and mode yourself. State the classification in one line. Ask only when the request is too ambiguous to classify.
6. Validate `state.json` against `.devai/core/contracts/state.schema.json` (`Test-Json -Schema` in PowerShell, or any JSON Schema validator).
7. Tell the user: `Work item WI-NNN started` and the classification.
8. Move to `SPECIFYING` and run the workflow as defined in `workflow.md`. Keep going until the state is `WAITING_USER`, `BLOCKED` or `COMPLETED`.