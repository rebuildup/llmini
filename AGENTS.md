# AGENTS.md — llmini

## Governance
- Constitution: [`constitution/CONSTITUTION.md`](constitution/CONSTITUTION.md)
- Operating Model: [`organization/profiles/release-driven-solo.md`](organization/profiles/release-driven-solo.md)
- Runtime/config facts: `README.md`, `config/settings.psd1`, PowerShell scripts, third-party notices.

## Runtime boundaries
- The product runtime remains package-manager-free; normal inference runs only the downloaded llama.cpp server process.
- Bun/mise are repository-maintenance tools for Agent Skills, not runtime dependencies.
- Treat model URL + SHA-256 + filename as the expected GGUF identity.
- Downloaded binaries/models/cache/logs/state are not source and must remain out of Git.
- Do not expose the unauthenticated API beyond loopback without an explicit security design.

## Evidence
- setup/download success does not prove inference quality.
- running-process status does not prove the expected model/binary is loaded unless identity is checked.
- benchmark/test evidence must name the candidate config/model/runtime version where material.

## Delivery
- durable work: GitHub Issue.
- ticket branch: Issue number.
- ticket PR: current release branch.
- normal main integration: release PR only.
- landing: merge commit only.
