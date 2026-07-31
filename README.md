# llmini

Windows上でローカルLLMを最小構成・低オーバーヘッドで動かすための、`llama.cpp`専用ランナーです。

含まれるものは次だけです。

- CUDA版`llama-server.exe`
- GGUFモデル1個
- 起動・停止・状態確認・更新用のPowerShellスクリプト
- OpenAI互換APIの接続手順

OpenClaw、Hermes Agent、Ollama、LM Studio、Node.js、Python、WSL、NixOSは使用しません。推論時の主要プロセスは`llama-server.exe`だけです。

## セットアップ

```powershell
cd D:\6_llm
.\bootstrap.cmd
```

初回のみ、最新のWindows CUDA 12.4版`llama.cpp`と既定GGUFを取得します。完了後はAPIテストまで実行します。

## 日常操作

```powershell
.\start.cmd
.\stop.cmd
.\status.cmd
.\test.cmd
.\benchmark.cmd
```

- `start.cmd`: バックグラウンド起動
- `stop.cmd`: 停止
- `status.cmd`: PID、API、GPU使用状況を表示
- `test.cmd`: Chat Completions APIへ1回送信
- `benchmark.cmd`: 短いコード生成テストとtoken/s表示

## 更新

```powershell
.\update.cmd
```

`llama.cpp`だけを最新版へ更新します。モデルは自動更新しません。

## 自動起動

```powershell
.\register-startup.cmd
```

解除:

```powershell
.\unregister-startup.cmd
```

ログオン時に`llama-server`だけを起動します。

## 旧構成の削除

旧版から移行する場合は、更新後に旧プロセスと生成物を削除してから新構成を作ります。

完全版ZIPを`D:\6_llm`へ上書き展開してから実行します。

```powershell
.\cleanup-legacy.cmd
.\bootstrap.cmd
git add -A
git commit -m "refactor: reduce llmini to llama.cpp only"
git push origin master
```

`cleanup-legacy.cmd`はOpenClaw、Hermes Agent、Portable Node.js、旧llama.cpp、関連ログ・状態・ワークスペース、旧自動起動タスクを削除します。GGUFが入っている`models`は残します。旧エージェントの履歴やワークスペースも削除対象です。

## 設定

`config/settings.psd1`だけを編集します。既定値はRTX 4050 Laptop 6GBで速度と余裕を両立する構成です。

```text
Model:           Qwen3.5-4B Q6_K
Context:         8192
GPU layers:      all
Parallel:        1
KV cache:        Q8_0
Flash Attention: on
Process priority: Normal
```

長いcontextが必要なときだけ`ContextLength`を増やしてください。contextを大きくすると起動時と実行時のメモリ消費が増えます。

API利用方法は[API.md](API.md)を参照してください。
