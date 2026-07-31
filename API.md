# API接続

`llmini`は`llama-server`のOpenAI互換HTTP APIを、そのまま公開します。

```text
Base URL: http://127.0.0.1:8080/v1
Model:    qwen3.5-4b-local
API key:  不要
```

一部のクライアントはAPIキー欄を必須にするため、その場合は`local`など任意の文字列を入力してください。サーバーは既定では`127.0.0.1`だけで待ち受けます。

`llama-server`はChat Completions、Responses、EmbeddingsなどのOpenAI互換ルートを提供します。モデルやビルドによって利用可能な機能は異なります。

## curl

```powershell
curl.exe http://127.0.0.1:8080/v1/chat/completions `
  -H "Content-Type: application/json" `
  -d '{"model":"qwen3.5-4b-local","messages":[{"role":"user","content":"Hello"}],"max_tokens":128}'
```

## PowerShell

```powershell
$body = @{
    model = "qwen3.5-4b-local"
    messages = @(
        @{ role = "user"; content = "Hello" }
    )
    max_tokens = 128
} | ConvertTo-Json -Depth 5

Invoke-RestMethod `
    -Method Post `
    -Uri "http://127.0.0.1:8080/v1/chat/completions" `
    -ContentType "application/json" `
    -Body $body
```

## JavaScript / TypeScript OpenAI SDK

```ts
import OpenAI from "openai";

const client = new OpenAI({
  baseURL: "http://127.0.0.1:8080/v1",
  apiKey: "local",
});

const response = await client.chat.completions.create({
  model: "qwen3.5-4b-local",
  messages: [{ role: "user", content: "Hello" }],
  max_tokens: 128,
});

console.log(response.choices[0]?.message.content);
```

## Python OpenAI SDK

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://127.0.0.1:8080/v1",
    api_key="local",
)

response = client.chat.completions.create(
    model="qwen3.5-4b-local",
    messages=[{"role": "user", "content": "Hello"}],
    max_tokens=128,
)

print(response.choices[0].message.content)
```

## OpenAI互換クライアント共通設定

```text
Provider type: OpenAI compatible / Custom OpenAI
Base URL:      http://127.0.0.1:8080/v1
API key:       local
Model ID:      qwen3.5-4b-local
```

LANへ公開する場合は`config/settings.psd1`の`Host`を変更できますが、認証とTLSがない状態で外部公開しないでください。
