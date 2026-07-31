# llmini

[English](README.md)

`llmini`は、Windows上でGGUFモデルを`llama.cpp`から直接動かすための最小ランナーです。
エージェントフレームワーク、デスクトップアプリ、パッケージマネージャー、Python環境、Node.js、WSL、仮想マシンは使用しません。推論時の主要プロセスは`llama-server.exe`だけです。

## 含まれるもの

- 公式の最新Windows x64 / CUDA 12.4版`llama.cpp`
- 固定されたGGUFモデル1個：Qwen3.5-4B Q6_K
- PowerShell実装1ファイル：`scripts/llmini.ps1`
- セットアップと日常操作用の小さなCMD別名
- OpenAI互換APIの接続手順

ダウンロードされるバイナリとモデルはGitリポジトリへ含めません。

## 必要環境

- Windows 11
- 現行ドライバーを導入したNVIDIA GPU
- PowerShell 7以上（`pwsh.exe`）
- 現行Windowsに含まれる`curl.exe`

## セットアップ

```powershell
cd D:\6_llm
.\bootstrap.cmd
```

初回だけ`llama.cpp`、CUDAランタイム、設定されたGGUFモデルを取得します。その後、サーバーを起動してAPIテストを1回実行します。

## 日常操作

```powershell
.\start.cmd
.\stop.cmd
.\status.cmd
.\test.cmd
.\update.cmd
```

全操作は単一の入口からも実行できます。

```powershell
.\llmini.cmd benchmark
.\llmini.cmd register-startup
.\llmini.cmd unregister-startup
.\llmini.cmd validate
```

プロンプトはUTF-8で、日本語を含む任意の言語を渡せます。

```powershell
.\llmini.cmd test -Prompt "日本語でllama.cppを一文で説明してください。"
```

## 設定

編集対象は[`config/settings.psd1`](config/settings.psd1)だけです。

既定値はRTX 4050 Laptop GPU 6GB向けです。

```text
モデル:            Qwen3.5-4B Q6_K
コンテキスト:      8192
GPUレイヤー:        全部
並列リクエスト:    1
KVキャッシュ:       Q8_0
Flash Attention:    有効
待受:              127.0.0.1:8080
```

長いコンテキストが必要な場合だけ`ContextLength`を増やしてください。値を増やすとメモリ消費が増え、速度が低下する場合があります。

## API

[API.ja.md](API.ja.md)を参照してください。既定の接続先は次です。

```text
http://127.0.0.1:8080/v1
```

認証機能はありません。自分で認証・TLS・ファイアウォールを用意しない限り、`127.0.0.1`以外へ公開しないでください。

## クリーンアップ

以前のOpenClaw・Hermes構成から移行した場合は、旧生成物を一度だけ削除します。

```powershell
.\llmini.cmd cleanup-legacy
```

`models/`内のモデルは残します。

## リポジトリ構成

```text
config/settings.psd1   ランタイムとモデルの設定
scripts/llmini.ps1     実装全体
llmini.cmd              共通の操作入口
bootstrap.cmd           セットアップ用別名
start.cmd               起動用別名
stop.cmd                停止用別名
status.cmd              状態確認用別名
test.cmd                APIテスト用別名
update.cmd              llama.cpp更新用別名
API.ja.md               API接続例
```

実行時ファイルは`bin/`、`cache/`、`models/`、`logs/`、`state/`へ作られ、すべてGit対象外です。

## ライセンス

このリポジトリのスクリプトとドキュメントはMIT Licenseです。ダウンロードされる第三者バイナリとモデルには、それぞれのライセンスが適用されます。[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)を参照してください。
