# AI Software Factory

A reusable template that adds a spec-driven, evidence-based, multi-agent workflow to any project opened in VS Code with GitHub Copilot. It works for greenfield and brownfield projects, in any language or framework.

You describe a need and answer the relevant decisions. The factory specifies, plans, implements, reviews, tests and documents it. A `coordinator` agent drives the workflow and keeps its state in files, so interrupted work can be resumed.

## Repository layout

```text
devai-factory/
├── README.md                  This file. Describes the template, not an installed project.
└── template/                  Everything that is installed into a project.
    ├── AGENTS.md              Universal rules. Installed as a managed block.
    ├── .github/
    │   ├── agents/            The coordinator and nine specialists.
    │   └── skills/            /workflow-start, /workflow-resume, /workflow-status.
    └── .devai/
        ├── config.yaml        Project settings.
        └── core/              Contracts, templates and version. Factory-owned.
            ├── VERSION
            ├── contracts/     agent-protocol.md, workflow.md, state.schema.json
            └── templates/
                ├── work-item/ spec, discovery, plan, tasks, review, qa-report, failure-report, state.json
                └── docs/      Documentation page template
```

Agents and skills are not active in this repository, because VS Code only reads `.github/` at the workspace root. Open a project where the template is installed to run them.

## Ownership

| Path in the project | Owner | On upgrade |
| ------------------- | ----- | ---------- |
| `.github/agents/*.agent.md` | factory | Replaced |
| `.github/skills/workflow-*/` | factory | Replaced |
| `.devai/core/` | factory | Replaced as a whole |
| `AGENTS.md`, block between `software-factory:begin` and `software-factory:end` | factory | Block replaced. The rest of the file is yours. |
| `.devai/config.yaml` | project | Kept. Compare with the template for new settings. |
| `.devai/work-items/` | project | Kept. Commit it: it is the project's design record. |
| `.github/instructions/` | project | Kept. Put project-specific rules here. |
| `docs/`, `mkdocs.yml` | project | Kept. Written by the `documenter` agent. |

Customize behavior through `config.yaml` and `.github/instructions/`. Do not edit factory-owned files in a project, or an upgrade will overwrite your changes.

## Install

Run from the root of this repository. Set `$target` to the project folder.

```powershell
$target = "C:\path\to\project"
Copy-Item template\.github, template\.devai -Destination $target -Recurse
```

`AGENTS.md`:

- The project has none: `Copy-Item template\AGENTS.md $target`.
- The project has one: paste the block between `<!-- software-factory:begin -->` and `<!-- software-factory:end -->` from `template/AGENTS.md` at the end of it.

On macOS or Linux, use `cp -R template/.github template/.devai "$target"/`.

## Upgrade

```powershell
$target = "C:\path\to\project"
Remove-Item "$target\.devai\core" -Recurse -Force
Copy-Item template\.devai\core "$target\.devai\" -Recurse
Copy-Item template\.github\agents\*.agent.md "$target\.github\agents" -Force
Copy-Item template\.github\skills\workflow-* "$target\.github\skills" -Recurse -Force
```

Then replace the `AGENTS.md` block. Compare `core/VERSION` before and after, and check `config.yaml` against `template/.devai/config.yaml` for new settings.

## Use

In the target project, open Copilot Chat, select the `coordinator` agent and run:

| Command | Purpose |
| ------- | ------- |
| `/workflow-start <need>` | Start a work item. Bug fixes, refactors and features use the same command. |
| `/workflow-resume [WI-001]` | Continue interrupted work. Reconciles `state.json` with the real files first. |
| `/workflow-status [WI-001]` | Show progress. Read-only. |

Start with `AGENTS.md`, then `template/.devai/core/contracts/workflow.md` and `agent-protocol.md`. They define how the factory behaves.

## Status

Version 0.1.0. Foundation only: rules, contracts, templates, agents and entry skills. Not yet included: method skills per stage, hooks and permission checks, Playwright MCP, installer script. None of it has been run end to end in VS Code.
