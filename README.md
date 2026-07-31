# llmini

[日本語](README.ja.md)

`llmini` is a minimal Windows runner for a local GGUF model through `llama.cpp`.
It intentionally avoids agent frameworks, desktop applications, package managers,
Python environments, Node.js, WSL, and virtual machines. At inference time, the
main process is only `llama-server.exe`.

## Included

- The latest official Windows x64 CUDA 12.4 build of `llama.cpp`
- One pinned GGUF model: Qwen3.5-4B Q6_K
- A single PowerShell implementation: `scripts/llmini.ps1`
- Small command aliases for setup and daily operation
- OpenAI-compatible API documentation

Downloaded binaries and models are not committed to this repository.

## Requirements

- Windows 11
- An NVIDIA GPU with a current driver
- PowerShell 7 or newer (`pwsh.exe`)
- `curl.exe`, included with current Windows versions

## Setup

```powershell
cd D:\6_llm
.\bootstrap.cmd
```

The first run downloads `llama.cpp`, the CUDA runtime files, and the configured
GGUF model. It then starts the server and sends one test request.

## Daily commands

```powershell
.\start.cmd
.\stop.cmd
.\status.cmd
.\test.cmd
.\update.cmd
```

All operations are also available through the single entry point:

```powershell
.\llmini.cmd benchmark
.\llmini.cmd register-startup
.\llmini.cmd unregister-startup
.\llmini.cmd validate
```

Use any UTF-8 prompt language:

```powershell
.\llmini.cmd test -Prompt "日本語でllama.cppを一文で説明してください。"
```

## Configuration

Edit only [`config/settings.psd1`](config/settings.psd1).

The defaults target an RTX 4050 Laptop GPU with 6 GB VRAM:

```text
Model:            Qwen3.5-4B Q6_K
Context:          8192
GPU layers:       all
Parallel requests: 1
KV cache:         Q8_0
Flash Attention:  enabled
Bind address:     127.0.0.1:8080
```

Increase the context only when needed. A larger context consumes more memory and
can reduce throughput.

## API

See [API.md](API.md). The default endpoint is:

```text
http://127.0.0.1:8080/v1
```

The server has no authentication layer. Keep the default loopback bind unless
you add authentication, TLS, and appropriate firewall rules yourself.

## Cleanup

Update `llama.cpp` with `update.cmd`. After migrating from the former OpenClaw/Hermes-based stack, remove its local
artifacts once:

```powershell
.\llmini.cmd cleanup-legacy
```

The model under `models/` is retained.

## Repository layout

```text
config/settings.psd1   Runtime and model configuration
scripts/llmini.ps1     Complete implementation
llmini.cmd              Main command entry point
bootstrap.cmd           Setup alias
start.cmd               Start alias
stop.cmd                Stop alias
status.cmd              Status alias
test.cmd                API test alias
update.cmd              llama.cpp update alias
API.md                  API examples
```

Runtime files are created under `bin/`, `cache/`, `models/`, `logs/`, and
`state/`; all are ignored by Git.

## License

The scripts and documentation in this repository are licensed under the MIT
License. Downloaded third-party binaries and models keep their own licenses.
See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
