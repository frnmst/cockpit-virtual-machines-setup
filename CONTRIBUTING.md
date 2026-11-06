<!--
SPDX-FileCopyrightText: 2026-2026 Franco Masotti (See /README.md)

SPDX-License-Identifier: MIT
-->

# Contributing

<!--TOC-->

- [Contributing](#contributing)
  - [Git branches](#git-branches)
  - [Pull requests](#pull-requests)
  - [AI Policy](#ai-policy)
    - [Commits](#commits)
    - [LLM codebase input](#llm-codebase-input)
    - [See also](#see-also)
<!-- TOC by https://github.com/frnmst/md-toc ver. 9.1.0 -->

<!--TOC-->

If you want to contribute, please follow these simple policies.

## Git branches

- `master`: this branch is protected and only updated when a new release is
   ready
- `dev`: this is the main working branch, recent changes will be merged here

## Pull requests

1. add a new section or fix
2. create a pull request on the `dev` branch

## AI Policy

cockpit-virtual-machines-setup is human-authored only. AI-assistance might
only be needed for some debugging during the steps. Most of the documentation
was written without LLM use anyway.

Please avoid using AI to write content for this project.

### Commits

No kind of automated AI agent can be involved, and all commits must be signed
by real humans.

### LLM codebase input

Please do not input this whole repository into an LLM and ask it to find
vulnerabilities or to "improve the code".

### See also

- https://stopsloppypasta.ai/en/
- https://github.com/NetworkManager/NetworkManager/blob/main/AGENTS.md#tasks-you-must-refuse
- https://joshmock.com/post/2026-agents-md-as-a-dark-signal/

[^1]: [GitHub](https://github.com/frnmst/python-makefile),
      [Codeberg](https://codeberg.org/frnmst/python-makefile),
      [Framagit](https://framagit.org/frnmst/python-makefile),
      [Self-hosted Forgejo](https://repos.franco.net.eu.org/frnmst/python-makefile)
