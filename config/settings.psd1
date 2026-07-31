@{
    Model = @{
        Id            = "qwen3.5-4b-local"
        FileName      = "Qwen3.5-4B-Q6_K.gguf"
        Url           = "https://huggingface.co/lmstudio-community/Qwen3.5-4B-GGUF/resolve/main/Qwen3.5-4B-Q6_K.gguf?download=true"
        Sha256        = "12a6d0136484ecbd85f91860924b1bf571da66e2cebfa507522efc01f9b7d1d9"
        ContextLength = 8192
        MaxTokens     = 2048
    }

    Server = @{
        Host            = "127.0.0.1"
        Port            = 8080
        GpuLayers       = 999
        Threads         = 6
        BatchThreads    = 8
        HttpThreads     = 2
        Parallel        = 1
        BatchSize       = 256
        MicroBatchSize  = 128
        CacheTypeK      = "q8_0"
        CacheTypeV      = "q8_0"
        FlashAttention  = $true
        ProcessPriority = "Normal"
        Poll            = 0
    }
}
