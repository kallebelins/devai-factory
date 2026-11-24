# AI Software Factory

A reusable template that adds a spec-driven, evidence-based, multi-agent workflow to any project opened in VS Code with GitHub Copilot. It works for greenfield and brownfield projects, in any language or framework.

You describe a need and answer the relevant decisions. The factory specifies, plans, implements, reviews, tests and documents it. A `coordinator` agent drives the workflow and keeps its state in files, so interrupted work can be resumed.

## Repository layout

```text
devai-factory/
├── README.md                  This file. Describes the template, not an installed project.
├── scripts/                   Install and uninstall scripts (PowerShell 7+).
│   ├── install-project.ps1
│   ├── uninstall-project.ps1
│   ├── install-global.ps1
│   ├── uninstall-global.ps1
│   └── lib/factory.ps1        Shared code.
└── template/                  Everything that is installed.
    ├── AGENTS.md              Universal rules. Installed as a managed block.
    ├── .github/
    │   ├── agents/            The coordinator and nine specialists.
    │   └── skills/            /workflow-start, /workflow-resume, /workflow-status.
    └── .devai/
        └── core/              Contracts, templates and version. Factory-owned.
            ├── VERSION
            ├── contracts/     agent-protocol.md, workflow.md, state.schema.json
            └── templates/
                ├── config.yaml  Default project settings.
                ├── work-item/   spec, discovery, plan, tasks, review, qa-report, failure-report, state.json
                └── docs/        Documentation page template
```

Agents and skills are not active in this repository, because VS Code only reads `.github/` at the workspace root. Open a project where the factory is installed to run them.

## Install

Requires PowerShell 7+ (`pwsh`), on Windows, macOS or Linux.

Pick one scope per project. Installing both makes every agent appear twice.

| Scope | Use when | Command |
| ----- | -------- | ------- |
| Project | The team shares the factory through the repository. | `./scripts/install-project.ps1 -Target <project dir>` |
| Global | You want it in every project on your machine, without committing anything. | `./scripts/install-global.ps1` |

Add `-WhatIf` to any script to see what it would do without changing anything. Re-running an install upgrades it.

### Project install

```powershell
./scripts/install-project.ps1 -Target C:\src\my-app
```

- Copies the agents, skills and `.devai/core/` into the project.
- Creates `.devai/config.yaml` from the default if it does not exist.
- Adds the rules block to `AGENTS.md`. A new file is created if there is none. Otherwise the block is appended, or replaced if already there, and the rest of the file is kept.
- Stops before changing anything if a factory file was edited in the project, or if a file with the same name exists and the factory did not install it. `-Force` overwrites them.

### Global install

```powershell
./scripts/install-global.ps1
```

Installs for the Copilot harness under `~/.copilot/`:

| Path | Content |
| ---- | ------- |
| `agents/` | The ten agents |
| `skills/workflow-*/` | The entry commands |
| `software-factory/` | Core, the universal rules, the install manifest |

- The paths inside agents and skills are rewritten to the absolute location of `~/.copilot/software-factory/`.
- Nothing is written to any project. `/workflow-start` creates `.devai/config.yaml` and `.devai/work-items/` in the project the first time it runs there.
- `-ProfileRoot <dir>` installs under another home directory.
- The Local harness keeps user agents in VS Code profile storage, so it is not covered.
- The agents read the core files outside the workspace. VS Code may ask you to approve the first reads. This has not been verified.

After installing, reload the VS Code window.

## Uninstall

```powershell
./scripts/uninstall-project.ps1 -Target C:\src\my-app
./scripts/uninstall-global.ps1
```

- Removes only the files recorded in the install manifest. Your other agents, skills and settings are not touched.
- Factory files that were edited are kept and listed. `-Force` removes them.
- In a project, the block is removed from `AGENTS.md`. The file is deleted only if nothing else is left in it.
- `.devai/config.yaml` is removed only if you never edited it. `.devai/work-items/` is always kept.
- `uninstall-project.ps1 -Purge` also deletes the whole `.devai/` directory, including every work item. It asks for confirmation first and refuses to run non-interactively unless `-Yes` is given.

## Ownership

| Path in the project | Owner | On upgrade | On uninstall |
| ------------------- | ----- | ---------- | ------------ |
| `.github/agents/*.agent.md` | factory | Replaced | Removed |
| `.github/skills/workflow-*/` | factory | Replaced | Removed |
| `.devai/core/` | factory | Replaced as a whole | Removed |
| `AGENTS.md`, block between `software-factory:begin` and `software-factory:end` | factory | Block replaced, the rest is yours | Block removed |
| `.devai/config.yaml` | project | Kept | Removed only if unedited |
| `.devai/work-items/` | project | Kept | Kept |
| `.github/instructions/` | project | Kept | Kept |
| `docs/`, `mkdocs.yml` | project | Kept | Kept |

Commit `.devai/work-items/`: it is the project's design record.

Customize behavior through `config.yaml` and `.github/instructions/`. Do not edit factory-owned files in a project. The installer detects the edit and refuses to overwrite it.

## Use

In the project, open Copilot Chat, select the `coordinator` agent and run:

| Command | Purpose |
| ------- | ------- |
| `/workflow-start <need>` | Start a work item. Bug fixes, refactors and features use the same command. |
| `/workflow-resume [WI-001]` | Continue interrupted work. Reconciles `state.json` with the real files first. |
| `/workflow-status [WI-001]` | Show progress. Read-only. |

To understand how the factory behaves, read `template/AGENTS.md`, then `template/.devai/core/contracts/workflow.md` and `agent-protocol.md`.

## Status

Version 0.1.0. Foundation only: rules, contracts, templates, agents, entry skills and install scripts. Not yet included: method skills per stage, hooks and permission checks, Playwright MCP. The install scripts were tested in temporary directories. Nothing has been run end to end in VS Code.
