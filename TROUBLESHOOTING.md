# Troubleshooting

## OpenClaw: gateway token missing

通常の`http://127.0.0.1:18789/`だけを開くと、Control UIのWebSocket認証にtokenが渡らない場合があります。

```powershell
.\open-openclaw.cmd
```

修正版はtokenをURL fragmentへ入れてControl UIを開きます。fragmentはHTTPサーバーへ送信されません。tokenは念のためクリップボードにもコピーされます。

## Hermes: context window below 64,000

Hermes Agentはツール利用時に最低64,000 tokenのコンテキストを要求します。Qwen3.5-4B自体は262,144 tokenに対応していますが、llama-serverが16,384で起動しているとHermesから拒否されます。

次を実行してください。

```powershell
.\repair-integrations.cmd -OpenDashboard
```

このコマンドは次を行います。

1. `ContextLength`を65,536へ更新
2. llama-server、OpenClaw、Hermesを停止
3. Agent設定を再生成
4. llama-serverを65,536で再起動
5. OpenClawを認証済みURLで開く
6. Hermesへ実際のChat Completionsリクエストを送る

## Individual verification

```powershell
.\test-openclaw.cmd
.\test-hermes.cmd
.\verify.cmd
```

Hermesには標準のブラウザUIはありません。`test-hermes.cmd`は`http://127.0.0.1:8642/v1/chat/completions`へ実リクエストを送って確認します。
