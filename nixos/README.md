# NixOSへの移行方針

現在の構成ではNixOS、WSL2、Linux VMは必要ありません。

Windowsネイティブを選ぶ理由:

- RTX 4050 LaptopへCUDAで直接アクセスできる
- OpenClawがWindowsを正式サポートする
- Hermes AgentにWindowsネイティブインストーラーがある
- `HERMES_HOME`とOpenClawのパス環境変数で単一ルートへ隔離できる
- VM/WSLのネットワークとGPU受け渡しを増やさずに済む

## 将来別マシンへ分離する場合

別のNixOSマシンへエージェントだけ移す構成は可能です。

```text
Windows RTX PC
  llama-server :8080
        ↑ LAN / TLS / API key
NixOS agent host
  OpenClaw
  Hermes Agent
```

ただし、その場合は次が必要です。

- llama-serverを`0.0.0.0`または専用LAN IPへバインド
- Windows Firewallの限定ルール
- TLSリバースプロキシまたはVPN
- 強いAPIキー
- エージェント側のbase URL変更

同一PCのNixOS VMへ移すことは推奨しません。GPUパススルーとファイル共有が、このリポジトリの目的である低オーバーヘッド性を損なうためです。
