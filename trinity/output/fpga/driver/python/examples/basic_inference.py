#!/usr/bin/env python3
"""
VIBEE BitNet - Basic Inference Example

Простой пример использования BitNet для inference

Священная Формула: V = n × 3^k × π^m × φ^p × e^q
Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999

Copyright (c) 2024 VIBEE Project
"""

import numpy as np
from bitnet import BitNet, BitNetError

def main():
    print("=" * 60)
    print("VIBEE BitNet - Basic Inference Example")
    print("=" * 60)
    
    # Путь к модели и устройству
    model_path = "model.bin"
    device = "/dev/bitnet0"
    
    try:
        # Создаём контекст с context manager
        with BitNet(device) as bn:
            print(f"\n✓ Connected to {device}")
            
            # Загружаем веса
            print(f"Loading weights from {model_path}...")
            bn.load_weights(model_path)
            print("✓ Weights loaded")
            
            # Получаем информацию о модели
            info = bn.model_info
            print(f"\nModel info:")
            print(f"  Layers: {info.num_layers}")
            print(f"  Hidden size: {info.hidden_size}")
            print(f"  Vocab size: {info.vocab_size}")
            
            # Входные токены
            input_tokens = np.array([1, 2, 3, 4, 5, 6, 7, 8], dtype=np.int32)
            print(f"\nInput tokens: {input_tokens}")
            
            # Inference
            print("Running inference...")
            output_tokens = bn.inference(input_tokens, max_output=100)
            print(f"✓ Generated {len(output_tokens)} tokens")
            print(f"Output tokens: {output_tokens[:20]}...")
            
            # Статус
            status = bn.status
            print(f"\nStatus: {status.state}")
            
            # Производительность
            perf = bn.performance
            print(f"\nPerformance:")
            print(f"  Total cycles: {perf.total_cycles}")
            print(f"  Tokens/sec: {perf.tokens_per_second}")
    
    except BitNetError as e:
        print(f"\n✗ Error: {e}")
        return 1
    
    except FileNotFoundError:
        print(f"\n✗ Model file not found: {model_path}")
        print("  Please provide a valid model file")
        return 1
    
    print("\n" + "=" * 60)
    print("Done!")
    print("=" * 60)
    return 0


if __name__ == "__main__":
    exit(main())
