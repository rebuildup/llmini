@{
    Model = @{
        Id            = "qwen3.5-4b-local"
        DisplayName   = "Qwen3.5 4B Q6_K Local"
        FileName      = "Qwen3.5-4B-Q6_K.gguf"
        Url           = "https://huggingface.co/lmstudio-community/Qwen3.5-4B-GGUF/resolve/main/Qwen3.5-4B-Q6_K.gguf?download=true"
        Sha256        = ""
        ContextLength = 65536
        MaxTokens     = 2048
    }

    Llama = @{
        Host             = "127.0.0.1"
        Port             = 8080
        GpuLayers        = 999
        Threads          = 4
        BatchThreads     = 6
        HttpThreads      = 2
        Parallel         = 1
        BatchSize        = 256
        MicroBatchSize   = 128
        CacheTypeK       = "q4_0"
        CacheTypeV       = "q4_0"
        FlashAttention   = $true
        ProcessPriority  = "BelowNormal"
        Poll             = 0
    }

    OpenClaw = @{
        Enabled      = $true
        GatewayHost  = "127.0.0.1"
        GatewayPort  = 18789
        ApiMode      = "openai-completions"
    }

    Hermes = @{
        Enabled     = $true
        ApiHost     = "127.0.0.1"
        ApiPort     = 8642
    }

    Node = @{
        Major = 24
    }

    StartupComponents = @("llama")
}
