---
name: workflow-status
description: Show the progress of software factory work items. Read-only. Reports status, gates, tasks, pending decisions and recovery problems.
argument-hint: [work item id, for example WI-001]
---

# Workflow status

This skill is read-only. Do not edit files and do not delegate to other agents.

1. Read `.devai/work-items/`. Use the ID in the user's message, otherwise report every work item that is not `COMPLETED`. If none exist, say so.
2. For each work item read `state.json`. If it is missing or does not match `.devai/core/contracts/state.schema.json`, say so and suggest `/workflow-resume`.
3. Report, briefly: ID and title, type, depth, status, the phase the status belongs to, gates, `completedTasks` against the tasks in `tasks.md`, `specRevision` and `planRevision`, and `iteration`.
4. If `WAITING_USER`, list the pending questions or the plan approval request.
5. If `RECOVERING` or `BLOCKED`, list the open problems with their attempts and the `blockedReason`.
6. If `state.json` and the artifacts visibly disagree (for example checked tasks that differ), say so and suggest `/workflow-resume`.