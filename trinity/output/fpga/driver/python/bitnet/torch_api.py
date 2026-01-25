"""
VIBEE BitNet PyTorch Integration

nn.Module обёртка для интеграции с PyTorch

Священная Формула: V = n × 3^k × π^m × φ^p × e^q
Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999

Copyright (c) 2024 VIBEE Project
"""

from typing import Optional, Union
import numpy as np

try:
    import torch
    import torch.nn as nn
    TORCH_AVAILABLE = True
except ImportError:
    TORCH_AVAILABLE = False
    
from .core import BitNet, BitNetError

if not TORCH_AVAILABLE:
    raise ImportError("PyTorch is required for torch_api. Install with: pip install torch")

# ═══════════════════════════════════════════════════════════════════════════════
# PyTorch Module
# ═══════════════════════════════════════════════════════════════════════════════

class BitNetModule(nn.Module):
    """
    PyTorch nn.Module обёртка для BitNet акселератора.
    
    Позволяет использовать BitNet как часть PyTorch pipeline.
    
    Example:
        >>> import torch
        >>> from bitnet import BitNetModule
        >>> 
        >>> model = BitNetModule(model_path="model.bin")
        >>> input_ids = torch.tensor([[1, 2, 3, 4, 5]])
        >>> output = model(input_ids)
        >>> print(output.shape)
    
    Note:
        - Веса хранятся на FPGA, не в PyTorch
        - Градиенты не поддерживаются (inference only)
        - Batch processing выполняется последовательно
    """
    
    def __init__(
        self,
        device: str = "/dev/bitnet0",
        model_path: Optional[str] = None
    ):
        """
        Args:
            device: Путь к устройству BitNet
            model_path: Путь к файлу с весами (опционально)
        """
        super().__init__()
        
        self._bitnet_device = device
        self._model_path = model_path
        self._bn: Optional[BitNet] = None
        self._initialized = False
        
        # Dummy parameter для регистрации модуля
        self.register_buffer("_dummy", torch.zeros(1))
        
        if model_path:
            self._initialize()
    
    def _initialize(self):
        """Инициализация BitNet контекста"""
        if self._initialized:
            return
        
        self._bn = BitNet(self._bitnet_device)
        
        if self._model_path:
            self._bn.load_weights(self._model_path)
        
        self._initialized = True
    
    def load_weights(self, model_path: str):
        """
        Загрузить веса модели.
        
        Args:
            model_path: Путь к файлу с весами
        """
        self._model_path = model_path
        
        if not self._initialized:
            self._initialize()
        else:
            self._bn.load_weights(model_path)
    
    def forward(
        self,
        input_ids: torch.Tensor,
        max_length: int = 1024,
        attention_mask: Optional[torch.Tensor] = None
    ) -> torch.Tensor:
        """
        Forward pass через BitNet акселератор.
        
        Args:
            input_ids: Входные токены [batch_size, seq_len]
            max_length: Максимальная длина выхода
            attention_mask: Маска внимания (опционально, для padding)
        
        Returns:
            torch.Tensor: Выходные токены [batch_size, output_len]
        """
        if not self._initialized:
            self._initialize()
        
        # Убедимся, что input на CPU
        if input_ids.device.type != "cpu":
            input_ids = input_ids.cpu()
        
        # Обработка batch
        if input_ids.dim() == 1:
            input_ids = input_ids.unsqueeze(0)
        
        batch_size = input_ids.shape[0]
        outputs = []
        
        for i in range(batch_size):
            seq = input_ids[i].numpy().astype(np.int32)
            
            # Применяем attention_mask если есть
            if attention_mask is not None:
                mask = attention_mask[i].numpy()
                seq = seq[mask == 1]
            
            # Inference
            output = self._bn.inference(seq, max_length)
            outputs.append(torch.from_numpy(output))
        
        # Padding до одинаковой длины
        max_out_len = max(len(o) for o in outputs)
        padded = torch.zeros(batch_size, max_out_len, dtype=torch.long)
        
        for i, output in enumerate(outputs):
            padded[i, :len(output)] = output
        
        return padded
    
    def generate(
        self,
        input_ids: torch.Tensor,
        max_new_tokens: int = 100,
        temperature: float = 1.0,
        top_k: int = 50,
        top_p: float = 0.9,
        do_sample: bool = False,
        pad_token_id: int = 0,
        eos_token_id: Optional[int] = None,
        attention_mask: Optional[torch.Tensor] = None
    ) -> torch.Tensor:
        """
        Генерация текста в стиле HuggingFace.
        
        Args:
            input_ids: Входные токены [batch_size, seq_len]
            max_new_tokens: Максимальное количество новых токенов
            temperature: Температура сэмплирования (не используется на FPGA)
            top_k: Top-K сэмплирование (не используется на FPGA)
            top_p: Top-P (nucleus) сэмплирование (не используется на FPGA)
            do_sample: Использовать сэмплирование (не используется на FPGA)
            pad_token_id: ID токена padding
            eos_token_id: ID токена конца последовательности
            attention_mask: Маска внимания
        
        Returns:
            torch.Tensor: Сгенерированные токены [batch_size, seq_len + new_tokens]
        
        Note:
            temperature, top_k, top_p, do_sample игнорируются,
            так как генерация происходит на FPGA с фиксированной логикой.
        """
        if not self._initialized:
            self._initialize()
        
        # Убедимся, что input на CPU
        if input_ids.device.type != "cpu":
            input_ids = input_ids.cpu()
        
        if input_ids.dim() == 1:
            input_ids = input_ids.unsqueeze(0)
        
        batch_size, seq_len = input_ids.shape
        
        # Генерируем для каждого элемента batch
        all_outputs = []
        
        for i in range(batch_size):
            seq = input_ids[i].numpy().astype(np.int32)
            
            # Применяем attention_mask
            if attention_mask is not None:
                mask = attention_mask[i].numpy()
                seq = seq[mask == 1]
            
            # Inference
            output = self._bn.inference(seq, max_new_tokens)
            
            # Конкатенируем вход и выход
            full_seq = np.concatenate([seq, output])
            
            # Обрезаем по eos_token_id если есть
            if eos_token_id is not None:
                eos_positions = np.where(full_seq == eos_token_id)[0]
                if len(eos_positions) > 0:
                    full_seq = full_seq[:eos_positions[0] + 1]
            
            all_outputs.append(torch.from_numpy(full_seq))
        
        # Padding до одинаковой длины
        max_len = max(len(o) for o in all_outputs)
        result = torch.full((batch_size, max_len), pad_token_id, dtype=torch.long)
        
        for i, output in enumerate(all_outputs):
            result[i, :len(output)] = output
        
        return result
    
    @property
    def status(self):
        """Получить статус акселератора"""
        if not self._initialized:
            return None
        return self._bn.status
    
    @property
    def performance(self):
        """Получить метрики производительности"""
        if not self._initialized:
            return None
        return self._bn.performance
    
    def reset(self):
        """Сбросить акселератор"""
        if self._initialized:
            self._bn.reset()
    
    def close(self):
        """Закрыть контекст"""
        if self._bn:
            self._bn.close()
            self._bn = None
            self._initialized = False
    
    def __del__(self):
        self.close()


# ═══════════════════════════════════════════════════════════════════════════════
# Utility Functions
# ═══════════════════════════════════════════════════════════════════════════════

def tensor_to_tokens(tensor: torch.Tensor) -> np.ndarray:
    """
    Конвертировать PyTorch tensor в numpy array токенов.
    
    Args:
        tensor: PyTorch tensor
    
    Returns:
        numpy array с dtype=int32
    """
    if tensor.device.type != "cpu":
        tensor = tensor.cpu()
    return tensor.numpy().astype(np.int32)


def tokens_to_tensor(tokens: np.ndarray, device: str = "cpu") -> torch.Tensor:
    """
    Конвертировать numpy array в PyTorch tensor.
    
    Args:
        tokens: numpy array
        device: целевое устройство ("cpu", "cuda", etc.)
    
    Returns:
        torch.Tensor
    """
    return torch.from_numpy(tokens).long().to(device)


# ═══════════════════════════════════════════════════════════════════════════════
# HuggingFace-style Wrapper
# ═══════════════════════════════════════════════════════════════════════════════

class BitNetForCausalLM(BitNetModule):
    """
    HuggingFace-совместимая обёртка для causal language modeling.
    
    Имитирует интерфейс transformers.AutoModelForCausalLM.
    
    Example:
        >>> from bitnet import BitNetForCausalLM
        >>> 
        >>> model = BitNetForCausalLM.from_pretrained("model.bin")
        >>> output = model.generate(input_ids, max_new_tokens=50)
    """
    
    @classmethod
    def from_pretrained(
        cls,
        model_path: str,
        device: str = "/dev/bitnet0",
        **kwargs
    ) -> "BitNetForCausalLM":
        """
        Загрузить модель из файла (HuggingFace-style).
        
        Args:
            model_path: Путь к файлу с весами
            device: Путь к устройству BitNet
            **kwargs: Дополнительные аргументы (игнорируются)
        
        Returns:
            BitNetForCausalLM instance
        """
        return cls(device=device, model_path=model_path)
    
    def save_pretrained(self, save_directory: str):
        """
        Сохранить модель (заглушка для совместимости).
        
        Note:
            Веса хранятся на FPGA, сохранение не поддерживается.
        """
        raise NotImplementedError(
            "BitNet weights are stored on FPGA. "
            "Use the original model file for distribution."
        )
