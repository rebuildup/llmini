$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\Common.ps1"

Initialize-StackDirectories
$settings = Get-StackSettings
$secrets = Get-StackSecrets
$root = Get-StackRoot
$baseUrl = "$(Get-LlamaBaseUrl)/v1"
$hermesMinimumContext = 64000

if ($settings.Hermes.Enabled -and
    [int]$settings.Model.ContextLength -lt $hermesMinimumContext) {
    throw (
        "Hermes requires at least {0} context tokens. Current setting: {1}." -f
        $hermesMinimumContext,
        $settings.Model.ContextLength
    )
}

if ($settings.OpenClaw.Enabled) {
    $stateDir = Join-Path $root "state\openclaw"
    Ensure-Directory $stateDir
    Ensure-Directory (Join-Path $root "workspace\openclaw")

    $config = [ordered]@{
        gateway = [ordered]@{
            mode = "local"
            bind = "loopback"
            port = [int]$settings.OpenClaw.GatewayPort
            auth = [ordered]@{
                mode = "token"
                token = $secrets.OpenClawGatewayToken
            }
        }
        agents = [ordered]@{
            defaults = [ordered]@{
                experimental = [ordered]@{
                    localModelLean = $true
                }
                model = [ordered]@{
                    primary = "llamacpp/$($settings.Model.Id)"
                }
                models = [ordered]@{
                    "llamacpp/$($settings.Model.Id)" = [ordered]@{
                        alias = $settings.Model.DisplayName
                    }
                }
            }
        }
        models = [ordered]@{
            mode = "merge"
            providers = [ordered]@{
                llamacpp = [ordered]@{
                    baseUrl = $baseUrl
                    apiKey = $secrets.LlamaApiKey
                    api = $settings.OpenClaw.ApiMode
                    timeoutSeconds = 300
                    models = @(
                        [ordered]@{
                            id = $settings.Model.Id
                            name = $settings.Model.DisplayName
                            reasoning = $true
                            input = @("text")
                            cost = [ordered]@{
                                input = 0
                                output = 0
                                cacheRead = 0
                                cacheWrite = 0
                            }
                            contextWindow = [int]$settings.Model.ContextLength
                            maxTokens = [int]$settings.Model.MaxTokens
                            compat = [ordered]@{
                                requiresStringContent = $true
                            }
                        }
                    )
                }
            }
        }
    }

    $json = $config | ConvertTo-Json -Depth 12
    $configPath = Join-Path $stateDir "openclaw.json"
    [System.IO.File]::WriteAllText(
        $configPath,
        $json,
        (New-Object System.Text.UTF8Encoding($false))
    )

    $envText = @"
OPENCLAW_GATEWAY_TOKEN=$($secrets.OpenClawGatewayToken)
"@
    [System.IO.File]::WriteAllText(
        (Join-Path $stateDir ".env"),
        $envText,
        (New-Object System.Text.UTF8Encoding($false))
    )
    Write-Host "Generated OpenClaw config: $configPath"
}

if ($settings.Hermes.Enabled) {
    $hermesHome = Join-Path $root "state\hermes"
    Ensure-Directory $hermesHome
    Ensure-Directory (Join-Path $root "workspace\hermes")

    $yaml = @"
model:
  default: "$($settings.Model.Id)"
  provider: custom
  base_url: "$baseUrl"
  api_key: "$($secrets.LlamaApiKey)"
  context_length: $($settings.Model.ContextLength)
  max_tokens: $($settings.Model.MaxTokens)

api_server:
  enabled: true
  host: "$($settings.Hermes.ApiHost)"
  port: $($settings.Hermes.ApiPort)
  key: "$($secrets.HermesApiKey)"
  allow_model_override: false
  max_concurrent: 1
"@
    [System.IO.File]::WriteAllText(
        (Join-Path $hermesHome "config.yaml"),
        $yaml,
        (New-Object System.Text.UTF8Encoding($false))
    )

    $envText = @"
API_SERVER_ENABLED=true
API_SERVER_HOST=$($settings.Hermes.ApiHost)
API_SERVER_PORT=$($settings.Hermes.ApiPort)
API_SERVER_KEY=$($secrets.HermesApiKey)
"@
    [System.IO.File]::WriteAllText(
        (Join-Path $hermesHome ".env"),
        $envText,
        (New-Object System.Text.UTF8Encoding($false))
    )
    Write-Host "Generated Hermes config: $(Join-Path $hermesHome 'config.yaml')"
}
