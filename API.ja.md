# API接続

[English](API.md)

`llmini`は`llama-server`が提供するHTTP APIを、そのまま公開します。

```text
Base URL: http://127.0.0.1:8080/v1
Model ID: qwen3.5-4b-local
API key:  不要
```

OpenAI互換クライアントによってはAPIキー欄が必須です。その場合は`local`など任意の文字列を入力してください。既定設定では値を検証しません。

以下の例はUTF-8を使用するため、日本語を含む任意の言語のプロンプトを送信できます。

## ヘルスチェックとモデル一覧

```powershell
Invoke-RestMethod http://127.0.0.1:8080/health
Invoke-RestMethod http://127.0.0.1:8080/v1/models
```

## curl

```powershell
curl.exe http://127.0.0.1:8080/v1/chat/completions `
  -H "Content-Type: application/json; charset=utf-8" `
  --data-binary '{"model":"qwen3.5-4b-local","messages":[{"role":"user","content":"こんにちは"}],"max_tokens":128}'
```

## PowerShell

```powershell
$body = @{
    model = "qwen3.5-4b-local"
    messages = @(
        @{ role = "user"; content = "日本語で短く答えてください。" }
    )
    max_tokens = 128
} | ConvertTo-Json -Depth 5

$response = Invoke-RestMethod `
    -Method Post `
    -Uri "http://127.0.0.1:8080/v1/chat/completions" `
    -ContentType "application/json; charset=utf-8" `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($body))

$response.choices[0].message.content
```

## JavaScript / TypeScript

```ts
import OpenAI from "openai";

const client = new OpenAI({
  baseURL: "http://127.0.0.1:8080/v1",
  apiKey: "local",
});

const response = await client.chat.completions.create({
  model: "qwen3.5-4b-local",
  messages: [{ role: "user", content: "こんにちは" }],
  max_tokens: 128,
});

console.log(response.choices[0]?.message.content);
```

## Python

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://127.0.0.1:8080/v1",
    api_key="local",
)

response = client.chat.completions.create(
    model="qwen3.5-4b-local",
    messages=[{"role": "user", "content": "こんにちは"}],
    max_tokens=128,
)

print(response.choices[0].message.content)
```

## OpenAI互換クライアント共通設定

```text
Provider: OpenAI compatible / Custom OpenAI
Base URL: http://127.0.0.1:8080/v1
API key:  local
Model ID: qwen3.5-4b-local
```

## セキュリティ

既定のAPIには認証とTLSがなく、ループバックだけで待ち受けます。認証付きリバースプロキシとファイアウォールを自分で構成しない限り、`Server.Host`をLANや外部向けのアドレスへ変更しないでください。

利用可能な追加エンドポイントは、導入された`llama.cpp`の版とモデルによって変わります。`llmini`が実際に利用するのは`/health`、`/v1/models`、`/v1/chat/completions`です。
