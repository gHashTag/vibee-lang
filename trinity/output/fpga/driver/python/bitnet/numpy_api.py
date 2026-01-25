"""
VIBEE BitNet NumPy API

Функциональный API для работы с numpy arrays

Священная Формула: V = n × 3^k × π^m × φ^p × e^q
Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999

Copyright (c) 2024 VIBEE Project
"""

from typing import Optional, Union
import numpy as np

from .core import BitNet, BitNetError

# ═══════════════════════════════════════════════════════════════════════════════
# Functional API
# ═══════════════════════════════════════════════════════════════════════════════

def bitnet_inference(
    input_tokens: np.ndarray,
    model_path: str,
    device: str = "/dev/bitnet0",
    max_output: int = 1024
) -> np.ndarray:
    """
    Выполнить inference с автоматическим управлением ресурсами.
    
    Удобная функция для одноразового inference без явного создания контекста.
    
    Args:
        input_tokens: numpy array с входными токенами (dtype=int32)
        model_path: Путь к файлу с весами модели
        device: Путь к устройству BitNet
        max_output: Максимальное количество выходных токенов
    
    Returns:
        numpy array с выходными токенами
    
    Example:
        >>> import numpy as np
        >>> from bitnet import bitnet_inference
        >>> 
        >>> input_ids = np.array([1, 2, 3, 4, 5], dtype=np.int32)
        >>> output = bitnet_inference(input_ids, "model.bin")
        >>> print(output)
    """
    with BitNet(device) as bn:
        bn.load_weights(model_path)
        return bn.inference(input_tokens, max_output)


def bitnet_batch_inference(
    input_batch: np.ndarray,
    model_path: str,
    device: str = "/dev/bitnet0",
    max_output: int = 1024,
    pad_token_id: int = 0
) -> np.ndarray:
    """
    Выполнить batch inference.
    
    Обрабатывает несколько последовательностей последовательно.
    
    Args:
        input_batch: 2D numpy array [batch_size, seq_len] с входными токенами
        model_path: Путь к файлу с весами модели
        device: Путь к устройству BitNet
        max_output: Максимальное количество выходных токенов на последовательность
        pad_token_id: ID токена для padding
    
    Returns:
        2D numpy array [batch_size, max_output] с выходными токенами
    
    Example:
        >>> import numpy as np
        >>> from bitnet import bitnet_batch_inference
        >>> 
        >>> batch = np.array([
        ...     [1, 2, 3, 0, 0],
        ...     [4, 5, 6, 7, 8],
        ... ], dtype=np.int32)
        >>> outputs = bitnet_batch_inference(batch, "model.bin")
        >>> print(outputs.shape)
    """
    if input_batch.ndim != 2:
        raise ValueError(f"Expected 2D array, got {input_batch.ndim}D")
    
    batch_size = input_batch.shape[0]
    outputs = np.full((batch_size, max_output), pad_token_id, dtype=np.int32)
    
    with BitNet(device) as bn:
        bn.load_weights(model_path)
        
        for i in range(batch_size):
            # Убираем padding из входа
            seq = input_batch[i]
            seq = seq[seq != pad_token_id]
            
            if len(seq) == 0:
                continue
            
            output = bn.inference(seq, max_output)
            outputs[i, :len(output)] = output
    
    return outputs


# ═══════════════════════════════════════════════════════════════════════════════
# Utility Functions
# ═══════════════════════════════════════════════════════════════════════════════

def tokens_to_numpy(tokens: Union[list, np.ndarray]) -> np.ndarray:
    """
    Конвертировать токены в numpy array.
    
    Args:
        tokens: list или numpy array
    
    Returns:
        numpy array с dtype=int32
    """
    if isinstance(tokens, np.ndarray):
        return np.ascontiguousarray(tokens, dtype=np.int32)
    return np.array(tokens, dtype=np.int32)


def pad_sequences(
    sequences: list,
    max_len: Optional[int] = None,
    pad_token_id: int = 0,
    padding: str = "right"
) -> np.ndarray:
    """
    Выровнять последовательности до одинаковой длины.
    
    Args:
        sequences: Список последовательностей (list of lists или arrays)
        max_len: Максимальная длина (None = максимум из входных)
        pad_token_id: ID токена для padding
        padding: "right" или "left"
    
    Returns:
        2D numpy array [num_sequences, max_len]
    
    Example:
        >>> seqs = [[1, 2, 3], [4, 5]]
        >>> padded = pad_sequences(seqs, max_len=5)
        >>> print(padded)
        [[1 2 3 0 0]
         [4 5 0 0 0]]
    """
    if max_len is None:
        max_len = max(len(seq) for seq in sequences)
    
    result = np.full((len(sequences), max_len), pad_token_id, dtype=np.int32)
    
    for i, seq in enumerate(sequences):
        seq = np.array(seq, dtype=np.int32)
        length = min(len(seq), max_len)
        
        if padding == "right":
            result[i, :length] = seq[:length]
        else:  # left padding
            result[i, -length:] = seq[:length]
    
    return result


def unpad_sequence(
    sequence: np.ndarray,
    pad_token_id: int = 0
) -> np.ndarray:
    """
    Удалить padding из последовательности.
    
    Args:
        sequence: 1D numpy array
        pad_token_id: ID токена padding
    
    Returns:
        numpy array без padding
    """
    # Находим последний не-pad токен
    non_pad = np.where(sequence != pad_token_id)[0]
    if len(non_pad) == 0:
        return np.array([], dtype=np.int32)
    return sequence[:non_pad[-1] + 1]


# ═══════════════════════════════════════════════════════════════════════════════
# Streaming API
# ═══════════════════════════════════════════════════════════════════════════════

class BitNetStream:
    """
    Streaming inference для генерации токенов по одному.
    
    Example:
        >>> from bitnet import BitNetStream
        >>> 
        >>> stream = BitNetStream("model.bin")
        >>> for token in stream.generate([1, 2, 3], max_tokens=100):
        ...     print(token, end=" ")
    """
    
    def __init__(self, model_path: str, device: str = "/dev/bitnet0"):
        """
        Args:
            model_path: Путь к файлу с весами
            device: Путь к устройству
        """
        self._bn = BitNet(device)
        self._bn.load_weights(model_path)
        self._model_path = model_path
    
    def generate(
        self,
        input_tokens: Union[list, np.ndarray],
        max_tokens: int = 100,
        stop_token_id: Optional[int] = None
    ):
        """
        Генератор токенов.
        
        Args:
            input_tokens: Начальные токены
            max_tokens: Максимальное количество токенов
            stop_token_id: ID токена остановки (None = не останавливаться)
        
        Yields:
            int: Сгенерированные токены по одному
        """
        input_tokens = tokens_to_numpy(input_tokens)
        
        for _ in range(max_tokens):
            # Генерируем один токен
            output = self._bn.inference(input_tokens, max_output=1)
            
            if len(output) == 0:
                break
            
            token = int(output[0])
            yield token
            
            if stop_token_id is not None and token == stop_token_id:
                break
            
            # Добавляем токен к входу для следующей итерации
            input_tokens = np.append(input_tokens, token)
    
    def close(self):
        """Закрыть контекст"""
        self._bn.close()
    
    def __enter__(self):
        return self
    
    def __exit__(self, *args):
        self.close()
