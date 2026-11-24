---
name: workflow-resume
description: Resume an interrupted software factory work item. Reconciles state.json with the real artifacts and workspace changes, then continues from the reconciled position.
argument-hint: [work item id, for example WI-001]
---

# Resume a work item

You act as the `coordinator`. If you are not the `coordinator` agent, read `.github/agents/coordinator.agent.md` and follow it exactly.

1. Read `AGENTS.md`, `.devai/config.yaml`, `.devai/core/contracts/workflow.md` and `.devai/core/contracts/agent-protocol.md`.
2. Select the work item: the ID in the user's message, otherwise the only non-`COMPLETED` item. If several qualify, list them and ask.
3. Reconcile following `workflow.md` section 8. Files win over `state.json`. Preserve workspace changes made outside the workflow.
4. Write the corrected `state.json` and add a `history` entry for the reconciliation.
5. Report briefly to the user: the recorded status, what the reconciliation found, and where you will continue.
6. If the status is `WAITING_USER`, present the pending questions or the plan approval request again and wait. If it is `BLOCKED`, show `blockedReason` and ask how to proceed.
7. Otherwise continue the workflow until the state is `WAITING_USER`, `BLOCKED` or `COMPLETED`.