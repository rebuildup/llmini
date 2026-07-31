# Local AI Stack for Windows

RTX 4050 Laptop / RAM 32GB 前後のWindows PCを想定した、単一ディレクトリ完結型のローカルLLM構成です。

- 推論: `llama.cpp` CUDA 12.4版の `llama-server`
- 既定モデル: `Qwen3.5-4B Q6_K`（GGUF）
- API: OpenAI互換 `http://127.0.0.1:8080/v1`
- エージェント: OpenClaw / Hermes Agent
- 管理: PowerShell + 薄い `.cmd`
- 自動起動: Windowsタスクスケジューラ
- Git追跡: 設定・スクリプト・ドキュメントのみ
- Linux/WSLは不使用

## 1. 配置

ZIPを、空白を含まないDドライブ上のパスへ展開してください。

```text
D:\local-ai-stack
```

このリポジトリ内のスクリプトは展開先を自動検出するため、ドライブ文字やディレクトリ名をハードコードしていません。

## 2. 初回構築

PowerShell 5.1以上で実行できます。

```powershell
cd D:\local-ai-stack
.\bootstrap.cmd
```

初回構築では、次をこのディレクトリ配下へ取得します。

1. Portable Node.js 24
2. 最新のWindows x64 / CUDA 12.4版 llama.cpp
3. CUDAランタイムDLL
4. Qwen3.5-4B Q6_K GGUF
5. OpenClawのローカルnpmインストール
6. Hermes AgentのWindowsネイティブ環境
7. 両エージェント用のローカルモデル設定

モデルを含め、数GBをダウンロードします。再実行時は既存ファイルを再利用します。

個別に省略する場合:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\bootstrap.ps1 -SkipHermes
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\bootstrap.ps1 -SkipOpenClaw
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\bootstrap.ps1 -SkipModel
```

## 3. 日常操作

```text
start.cmd       設定されたコンポーネントを起動
stop.cmd        管理対象プロセスを停止
status.cmd      プロセス・API・GPU状態を確認
test.cmd        モデルAPIへテスト送信
benchmark.cmd   短い推論ベンチマーク
openclaw.cmd    OpenClaw CLIを正しいローカル環境で実行
hermes.cmd      Hermes CLIを正しいローカル環境で実行
```

既定の `start.cmd` は `config/settings.psd1` の `StartupComponents` に従います。初期値は `llama` のみです。

OpenClaw Gatewayを手動起動:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-openclaw.ps1
```

Hermes Gatewayを手動起動:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-hermes.ps1
```

## 4. 自動起動

現在の `StartupComponents` を、ログオン時に起動するタスクとして登録します。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\register-startup.ps1
```

解除:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\unregister-startup.ps1
```

初期状態ではモデルサーバーだけが自動起動します。OpenClawやHermesも起動する場合は、`config/settings.psd1`を次のように変更してから再登録してください。

```powershell
StartupComponents = @("llama", "openclaw", "hermes")
```

## 5. Git管理

初期化:

```powershell
git init
git add .
git commit -m "Initialize local AI stack"
```

追跡対象:

- `config/settings.psd1`
- `scripts/`
- `.cmd`
- ドキュメント

追跡しないもの:

- モデル
- llama.cpp / Node / OpenClaw / Hermes本体
- APIキー
- PID
- ログ
- セッション
- エージェントの記憶
- 作業用ワークスペース

実際のエージェント設定は、追跡中の `settings.psd1` と生成スクリプトから `state/` へ生成します。

設定を再生成:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure-agents.ps1
```

`state/`内を直接編集した内容は、再生成時に上書きされます。永続化したい変更は設定生成スクリプト側へ反映してください。

## 6. 性能設定

初期値:

```text
Context:             8192
Max output:          2048
GPU layers:          999（可能な限りGPU）
CPU threads:         4
Prompt threads:      6
Parallel requests:   1
KV cache:            Q8_0
Process priority:    BelowNormal
llama.cpp poll:      0
```

生成中のGPU使用率を厳密に50%へ固定する設定ではありません。小型モデルをGPU上で早く終わらせ、CPUスレッド数とプロセス優先度を抑える構成です。

設定変更は `config/settings.psd1` で行います。

## 7. ディレクトリ

```text
local-ai-stack/
├─ apps/                  ダウンロードされたOpenClaw
├─ config/                Git管理する唯一の主要設定
├─ models/                GGUF（Git対象外）
├─ scripts/               管理スクリプト
├─ state/                 秘密値、PID、エージェント状態（Git対象外）
├─ tools/                 Node、llama.cpp（Git対象外）
├─ workspace/             エージェント作業領域（Git対象外）
├─ logs/                  標準出力・標準エラー（Git対象外）
└─ downloads/             ダウンロードキャッシュ（Git対象外）
```

## 8. 接続先

### llama-server

```text
Base URL: http://127.0.0.1:8080/v1
Model ID: qwen3.5-4b-local
API key: state\secrets.psd1 内で自動生成
```

OpenClawとHermesは、初回構築時にこの値へ自動設定されます。

### OpenClaw

状態:

```text
state\openclaw
```

CLI:

```powershell
.\openclaw.cmd doctor
.\openclaw.cmd models list
.\openclaw.cmd gateway status
```

### Hermes Agent

状態・インストール:

```text
state\hermes
```

CLI:

```powershell
.\hermes.cmd doctor
.\hermes.cmd chat
.\hermes.cmd gateway
```

HermesのOpenAI互換Agent APIを有効化しているため、Gateway起動中は次も利用できます。

```text
http://127.0.0.1:8642/v1
```

## 9. 更新

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\update.ps1
```

更新対象:

- llama.cpp
- OpenClaw
- Hermes Agent

モデルは自動更新しません。量子化やモデルを変える場合は `config/settings.psd1` のURL・ファイル名・IDを変更し、次を実行します。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\download-model.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure-agents.ps1
```

## 10. NixOSを使わない理由

この構成では、llama.cpp、OpenClaw、Hermes AgentのすべてがWindowsネイティブで動作します。NixOS VMやWSLを挟むと、RTX Laptop GPUの受け渡し、localhost接続、ファイル権限、常駐管理が増え、今回の「低レイヤー・単一ディレクトリ・低オーバーヘッド」という目的に反します。

将来、別PCのNixOSサーバーへエージェント部分だけ移す場合の方針は `nixos/README.md` に記載しています。

## 11. セキュリティ

- すべて初期状態で `127.0.0.1` のみにバインドします。
- エージェントはコマンド実行やファイル操作が可能です。
- `workspace/`以外を操作させる場合は、各エージェントの承認・サンドボックス設定を確認してください。
- `state/`をGitへ追加しないでください。
- 外部公開する場合は、この構成をそのまま使わず、認証・TLS・ファイアウォールを再設計してください。
