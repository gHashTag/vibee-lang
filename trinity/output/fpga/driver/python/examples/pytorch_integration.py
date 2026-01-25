#!/usr/bin/env python3
"""
VIBEE BitNet - PyTorch Integration Example

Пример использования BitNet с PyTorch

Священная Формула: V = n × 3^k × π^m × φ^p × e^q
Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999

Copyright (c) 2024 VIBEE Project
"""

import torch
import numpy as np

try:
    from bitnet import BitNetModule, BitNetForCausalLM
except ImportError as e:
    print(f"Error: {e}")
    print("Make sure PyTorch is installed: pip install torch")
    exit(1)


def example_basic_module():
    """Базовый пример с BitNetModule"""
    print("\n" + "=" * 60)
    print("Example 1: Basic BitNetModule")
    print("=" * 60)
    
    # Создаём модуль
    model = BitNetModule(
        device="/dev/bitnet0",
        model_path="model.bin"
    )
    
    # Входные данные
    input_ids = torch.tensor([[1, 2, 3, 4, 5]], dtype=torch.long)
    print(f"Input shape: {input_ids.shape}")
    
    # Forward pass
    output = model(input_ids, max_length=50)
    print(f"Output shape: {output.shape}")
    print(f"Output tokens: {output[0, :10].tolist()}...")
    
    # Cleanup
    model.close()


def example_generate():
    """Пример генерации текста"""
    print("\n" + "=" * 60)
    print("Example 2: Text Generation")
    print("=" * 60)
    
    # Используем HuggingFace-style API
    model = BitNetForCausalLM.from_pretrained("model.bin")
    
    # Prompt
    input_ids = torch.tensor([[1, 2, 3, 4, 5]])
    
    # Генерация
    output = model.generate(
        input_ids,
        max_new_tokens=50,
        pad_token_id=0,
        eos_token_id=2  # Остановка на токене 2
    )
    
    print(f"Generated sequence: {output[0].tolist()}")
    
    model.close()


def example_batch_processing():
    """Пример batch обработки"""
    print("\n" + "=" * 60)
    print("Example 3: Batch Processing")
    print("=" * 60)
    
    model = BitNetModule(model_path="model.bin")
    
    # Batch входных данных
    batch = torch.tensor([
        [1, 2, 3, 0, 0],  # Sequence 1 (padded)
        [4, 5, 6, 7, 8],  # Sequence 2
        [9, 10, 0, 0, 0], # Sequence 3 (padded)
    ], dtype=torch.long)
    
    # Attention mask (1 = real token, 0 = padding)
    attention_mask = torch.tensor([
        [1, 1, 1, 0, 0],
        [1, 1, 1, 1, 1],
        [1, 1, 0, 0, 0],
    ])
    
    print(f"Batch size: {batch.shape[0]}")
    
    # Forward pass с attention mask
    output = model(batch, attention_mask=attention_mask)
    
    print(f"Output shape: {output.shape}")
    for i in range(batch.shape[0]):
        print(f"  Sequence {i}: {output[i, :5].tolist()}...")
    
    model.close()


def example_performance():
    """Пример мониторинга производительности"""
    print("\n" + "=" * 60)
    print("Example 4: Performance Monitoring")
    print("=" * 60)
    
    model = BitNetModule(model_path="model.bin")
    
    # Несколько inference
    for i in range(5):
        input_ids = torch.randint(1, 1000, (1, 16))
        _ = model(input_ids)
    
    # Получаем метрики
    perf = model.performance
    status = model.status
    
    print(f"Status: {status.state}")
    print(f"Total cycles: {perf.total_cycles}")
    print(f"Tokens/sec: {perf.tokens_per_second}")
    print(f"Inference count: {perf.inference_count}")
    
    model.close()


def main():
    print("=" * 60)
    print("VIBEE BitNet - PyTorch Integration Examples")
    print("=" * 60)
    
    try:
        example_basic_module()
        example_generate()
        example_batch_processing()
        example_performance()
    except Exception as e:
        print(f"\nError: {e}")
        print("\nNote: These examples require:")
        print("  1. BitNet FPGA device (/dev/bitnet0)")
        print("  2. Model weights file (model.bin)")
        return 1
    
    print("\n" + "=" * 60)
    print("All examples completed!")
    print("=" * 60)
    return 0


if __name__ == "__main__":
    exit(main())
