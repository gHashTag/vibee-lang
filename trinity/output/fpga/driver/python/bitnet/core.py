"""
VIBEE BitNet Core Python Bindings

ctypes обёртка для libbitnet.so

Священная Формула: V = n × 3^k × π^m × φ^p × e^q
Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999

Copyright (c) 2024 VIBEE Project
"""

import ctypes
from ctypes import c_int, c_int32, c_int64, c_uint32, c_uint64, c_char_p, c_void_p, c_size_t
from ctypes import Structure, POINTER, byref
from dataclasses import dataclass
from typing import Optional, Union, List
from pathlib import Path
import os

import numpy as np

# ═══════════════════════════════════════════════════════════════════════════════
# Constants
# ═══════════════════════════════════════════════════════════════════════════════

BITNET_SUCCESS = 0
BITNET_ERR_OPEN = -1
BITNET_ERR_MMAP = -2
BITNET_ERR_IOCTL = -3
BITNET_ERR_TIMEOUT = -4
BITNET_ERR_BUSY = -5
BITNET_ERR_INVALID = -6
BITNET_ERR_NO_MEMORY = -7
BITNET_ERR_HW_ERROR = -8
BITNET_ERR_FILE = -9

STATE_NAMES = {
    0: "IDLE",
    1: "LOADING_WEIGHTS",
    2: "RUNNING",
    3: "DMA_TRANSFER",
    4: "ERROR",
}

ERROR_MESSAGES = {
    BITNET_SUCCESS: "Success",
    BITNET_ERR_OPEN: "Failed to open device",
    BITNET_ERR_MMAP: "Failed to map memory",
    BITNET_ERR_IOCTL: "IOCTL failed",
    BITNET_ERR_TIMEOUT: "Operation timed out",
    BITNET_ERR_BUSY: "Device busy",
    BITNET_ERR_INVALID: "Invalid parameter",
    BITNET_ERR_NO_MEMORY: "Out of memory",
    BITNET_ERR_HW_ERROR: "Hardware error",
    BITNET_ERR_FILE: "File operation failed",
}

# ═══════════════════════════════════════════════════════════════════════════════
# C Structures
# ═══════════════════════════════════════════════════════════════════════════════

class CStatus(Structure):
    _fields_ = [
        ("state", c_uint32),
        ("current_layer", c_uint32),
        ("tokens_processed", c_uint32),
        ("error_code", c_uint32),
    ]

class CPerformance(Structure):
    _fields_ = [
        ("total_cycles", c_uint64),
        ("dma_cycles", c_uint64),
        ("compute_cycles", c_uint64),
        ("tokens_per_second", c_uint32),
        ("inference_count", c_uint32),
    ]

class CModelInfo(Structure):
    _fields_ = [
        ("num_layers", c_uint32),
        ("hidden_size", c_uint32),
        ("vocab_size", c_uint32),
        ("max_seq_len", c_uint32),
        ("weight_size", c_uint64),
    ]

# ═══════════════════════════════════════════════════════════════════════════════
# Python Data Classes
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class BitNetStatus:
    """Статус акселератора"""
    state: str
    current_layer: int
    tokens_processed: int
    error_code: int

@dataclass
class BitNetPerformance:
    """Метрики производительности"""
    total_cycles: int
    dma_cycles: int
    compute_cycles: int
    tokens_per_second: int
    inference_count: int

@dataclass
class BitNetModelInfo:
    """Информация о модели"""
    num_layers: int
    hidden_size: int
    vocab_size: int
    max_seq_len: int
    weight_size: int

# ═══════════════════════════════════════════════════════════════════════════════
# Exception
# ═══════════════════════════════════════════════════════════════════════════════

class BitNetError(Exception):
    """Исключение для ошибок BitNet"""
    
    def __init__(self, code: int, message: Optional[str] = None):
        self.code = code
        self.message = message or ERROR_MESSAGES.get(code, f"Unknown error: {code}")
        super().__init__(self.message)

# ═══════════════════════════════════════════════════════════════════════════════
# Library Loader
# ═══════════════════════════════════════════════════════════════════════════════

def _load_library() -> ctypes.CDLL:
    """Загрузка libbitnet.so"""
    
    # Поиск библиотеки
    search_paths = [
        # Рядом с модулем
        Path(__file__).parent / "libbitnet.so",
        # В системных путях
        "libbitnet.so",
        # В /usr/local/lib
        "/usr/local/lib/libbitnet.so",
        # В директории драйвера
        Path(__file__).parent.parent.parent / "userspace" / "libbitnet.so",
    ]
    
    # Добавляем LD_LIBRARY_PATH
    ld_path = os.environ.get("LD_LIBRARY_PATH", "")
    for path in ld_path.split(":"):
        if path:
            search_paths.append(Path(path) / "libbitnet.so")
    
    for path in search_paths:
        try:
            lib = ctypes.CDLL(str(path))
            return lib
        except OSError:
            continue
    
    raise BitNetError(BITNET_ERR_OPEN, 
                      "Could not load libbitnet.so. "
                      "Make sure it's installed or set LD_LIBRARY_PATH")

def _setup_library(lib: ctypes.CDLL) -> ctypes.CDLL:
    """Настройка типов функций"""
    
    # bitnet_init
    lib.bitnet_init.argtypes = [c_char_p]
    lib.bitnet_init.restype = c_void_p
    
    # bitnet_destroy
    lib.bitnet_destroy.argtypes = [c_void_p]
    lib.bitnet_destroy.restype = None
    
    # bitnet_reset
    lib.bitnet_reset.argtypes = [c_void_p]
    lib.bitnet_reset.restype = c_int
    
    # bitnet_load_weights
    lib.bitnet_load_weights.argtypes = [c_void_p, c_char_p]
    lib.bitnet_load_weights.restype = c_int
    
    # bitnet_load_layer_weights
    lib.bitnet_load_layer_weights.argtypes = [c_void_p, c_int, c_void_p, c_size_t]
    lib.bitnet_load_layer_weights.restype = c_int
    
    # bitnet_get_model_info
    lib.bitnet_get_model_info.argtypes = [c_void_p, POINTER(CModelInfo)]
    lib.bitnet_get_model_info.restype = c_int
    
    # bitnet_inference
    lib.bitnet_inference.argtypes = [c_void_p, POINTER(c_int32), c_int, 
                                      POINTER(c_int32), c_int]
    lib.bitnet_inference.restype = c_int
    
    # bitnet_inference_async
    lib.bitnet_inference_async.argtypes = [c_void_p, POINTER(c_int32), c_int]
    lib.bitnet_inference_async.restype = c_int
    
    # bitnet_wait
    lib.bitnet_wait.argtypes = [c_void_p, c_int]
    lib.bitnet_wait.restype = c_int
    
    # bitnet_get_output
    lib.bitnet_get_output.argtypes = [c_void_p, POINTER(c_int32), c_int]
    lib.bitnet_get_output.restype = c_int
    
    # bitnet_abort
    lib.bitnet_abort.argtypes = [c_void_p]
    lib.bitnet_abort.restype = c_int
    
    # bitnet_get_status
    lib.bitnet_get_status.argtypes = [c_void_p, POINTER(CStatus)]
    lib.bitnet_get_status.restype = c_int
    
    # bitnet_get_perf
    lib.bitnet_get_perf.argtypes = [c_void_p, POINTER(CPerformance)]
    lib.bitnet_get_perf.restype = c_int
    
    # bitnet_is_busy
    lib.bitnet_is_busy.argtypes = [c_void_p]
    lib.bitnet_is_busy.restype = c_int
    
    # bitnet_strerror
    lib.bitnet_strerror.argtypes = [c_int]
    lib.bitnet_strerror.restype = c_char_p
    
    # bitnet_version
    lib.bitnet_version.argtypes = []
    lib.bitnet_version.restype = c_char_p
    
    return lib

# Global library instance
_lib: Optional[ctypes.CDLL] = None

def _get_lib() -> ctypes.CDLL:
    """Получить экземпляр библиотеки (lazy loading)"""
    global _lib
    if _lib is None:
        _lib = _setup_library(_load_library())
    return _lib

# ═══════════════════════════════════════════════════════════════════════════════
# Main Class
# ═══════════════════════════════════════════════════════════════════════════════

class BitNet:
    """
    Основной класс для работы с BitNet акселератором.
    
    Пример использования:
    
        with BitNet("/dev/bitnet0") as bn:
            bn.load_weights("model.bin")
            output = bn.inference([1, 2, 3, 4])
            print(output)
    
    Или без context manager:
    
        bn = BitNet()
        bn.load_weights("model.bin")
        output = bn.inference(np.array([1, 2, 3, 4]))
        bn.close()
    """
    
    def __init__(self, device: str = "/dev/bitnet0"):
        """
        Инициализация BitNet контекста.
        
        Args:
            device: Путь к устройству (по умолчанию /dev/bitnet0)
        
        Raises:
            BitNetError: Если не удалось открыть устройство
        """
        self._lib = _get_lib()
        self._ctx = self._lib.bitnet_init(device.encode('utf-8'))
        
        if not self._ctx:
            raise BitNetError(BITNET_ERR_OPEN, f"Failed to open device: {device}")
        
        self._weights_loaded = False
    
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()
        return False
    
    def close(self):
        """Закрыть контекст и освободить ресурсы"""
        if self._ctx:
            self._lib.bitnet_destroy(self._ctx)
            self._ctx = None
    
    def __del__(self):
        self.close()
    
    def _check_ctx(self):
        """Проверить, что контекст валиден"""
        if not self._ctx:
            raise BitNetError(BITNET_ERR_INVALID, "Context is closed")
    
    def _check_error(self, ret: int, operation: str = "Operation"):
        """Проверить код возврата и выбросить исключение при ошибке"""
        if ret < 0:
            raise BitNetError(ret, f"{operation} failed: {ERROR_MESSAGES.get(ret, 'Unknown error')}")
    
    # ─────────────────────────────────────────────────────────────────────────
    # Weight Management
    # ─────────────────────────────────────────────────────────────────────────
    
    def load_weights(self, model_path: str):
        """
        Загрузить веса из файла.
        
        Args:
            model_path: Путь к файлу с весами
        
        Raises:
            BitNetError: При ошибке загрузки
        """
        self._check_ctx()
        ret = self._lib.bitnet_load_weights(self._ctx, model_path.encode('utf-8'))
        self._check_error(ret, "Load weights")
        self._weights_loaded = True
    
    def load_weights_from_array(self, weights: np.ndarray, layer_id: int = -1):
        """
        Загрузить веса из numpy array.
        
        Args:
            weights: numpy array с весами
            layer_id: ID слоя (-1 для всех слоёв)
        
        Raises:
            BitNetError: При ошибке загрузки
        """
        self._check_ctx()
        
        # Убедимся, что массив contiguous
        weights = np.ascontiguousarray(weights)
        
        ret = self._lib.bitnet_load_layer_weights(
            self._ctx,
            layer_id,
            weights.ctypes.data_as(c_void_p),
            weights.nbytes
        )
        self._check_error(ret, "Load layer weights")
        self._weights_loaded = True
    
    # ─────────────────────────────────────────────────────────────────────────
    # Inference
    # ─────────────────────────────────────────────────────────────────────────
    
    def inference(self, 
                  input_tokens: Union[List[int], np.ndarray],
                  max_output: int = 1024) -> np.ndarray:
        """
        Выполнить синхронный inference.
        
        Args:
            input_tokens: Входные токены (list или numpy array)
            max_output: Максимальное количество выходных токенов
        
        Returns:
            numpy array с выходными токенами
        
        Raises:
            BitNetError: При ошибке inference
        """
        self._check_ctx()
        
        if not self._weights_loaded:
            raise BitNetError(BITNET_ERR_INVALID, "Weights not loaded")
        
        # Конвертируем в numpy array
        if isinstance(input_tokens, list):
            input_tokens = np.array(input_tokens, dtype=np.int32)
        else:
            input_tokens = np.ascontiguousarray(input_tokens, dtype=np.int32)
        
        # Выделяем буфер для выхода
        output_tokens = np.zeros(max_output, dtype=np.int32)
        
        # Вызываем inference
        num_output = self._lib.bitnet_inference(
            self._ctx,
            input_tokens.ctypes.data_as(POINTER(c_int32)),
            len(input_tokens),
            output_tokens.ctypes.data_as(POINTER(c_int32)),
            max_output
        )
        
        self._check_error(num_output, "Inference")
        
        return output_tokens[:num_output]
    
    def inference_async(self, input_tokens: Union[List[int], np.ndarray]):
        """
        Запустить асинхронный inference.
        
        Args:
            input_tokens: Входные токены
        
        Raises:
            BitNetError: При ошибке запуска
        """
        self._check_ctx()
        
        if not self._weights_loaded:
            raise BitNetError(BITNET_ERR_INVALID, "Weights not loaded")
        
        if isinstance(input_tokens, list):
            input_tokens = np.array(input_tokens, dtype=np.int32)
        else:
            input_tokens = np.ascontiguousarray(input_tokens, dtype=np.int32)
        
        ret = self._lib.bitnet_inference_async(
            self._ctx,
            input_tokens.ctypes.data_as(POINTER(c_int32)),
            len(input_tokens)
        )
        self._check_error(ret, "Async inference")
    
    def wait(self, timeout_ms: int = -1) -> bool:
        """
        Ожидать завершения inference.
        
        Args:
            timeout_ms: Таймаут в миллисекундах (-1 для бесконечного ожидания)
        
        Returns:
            True если завершено успешно, False при таймауте
        
        Raises:
            BitNetError: При ошибке
        """
        self._check_ctx()
        
        ret = self._lib.bitnet_wait(self._ctx, timeout_ms)
        
        if ret == BITNET_ERR_TIMEOUT:
            return False
        
        self._check_error(ret, "Wait")
        return True
    
    def get_output(self, max_output: int = 1024) -> np.ndarray:
        """
        Получить результат асинхронного inference.
        
        Args:
            max_output: Максимальное количество токенов
        
        Returns:
            numpy array с выходными токенами
        
        Raises:
            BitNetError: При ошибке
        """
        self._check_ctx()
        
        output_tokens = np.zeros(max_output, dtype=np.int32)
        
        num_output = self._lib.bitnet_get_output(
            self._ctx,
            output_tokens.ctypes.data_as(POINTER(c_int32)),
            max_output
        )
        
        self._check_error(num_output, "Get output")
        
        return output_tokens[:num_output]
    
    def abort(self):
        """Прервать текущий inference"""
        self._check_ctx()
        ret = self._lib.bitnet_abort(self._ctx)
        self._check_error(ret, "Abort")
    
    def reset(self):
        """Сбросить hardware"""
        self._check_ctx()
        ret = self._lib.bitnet_reset(self._ctx)
        self._check_error(ret, "Reset")
    
    # ─────────────────────────────────────────────────────────────────────────
    # Properties
    # ─────────────────────────────────────────────────────────────────────────
    
    @property
    def status(self) -> BitNetStatus:
        """Получить текущий статус"""
        self._check_ctx()
        
        c_status = CStatus()
        ret = self._lib.bitnet_get_status(self._ctx, byref(c_status))
        self._check_error(ret, "Get status")
        
        return BitNetStatus(
            state=STATE_NAMES.get(c_status.state, f"UNKNOWN({c_status.state})"),
            current_layer=c_status.current_layer,
            tokens_processed=c_status.tokens_processed,
            error_code=c_status.error_code
        )
    
    @property
    def performance(self) -> BitNetPerformance:
        """Получить метрики производительности"""
        self._check_ctx()
        
        c_perf = CPerformance()
        ret = self._lib.bitnet_get_perf(self._ctx, byref(c_perf))
        self._check_error(ret, "Get performance")
        
        return BitNetPerformance(
            total_cycles=c_perf.total_cycles,
            dma_cycles=c_perf.dma_cycles,
            compute_cycles=c_perf.compute_cycles,
            tokens_per_second=c_perf.tokens_per_second,
            inference_count=c_perf.inference_count
        )
    
    @property
    def model_info(self) -> BitNetModelInfo:
        """Получить информацию о модели"""
        self._check_ctx()
        
        c_info = CModelInfo()
        ret = self._lib.bitnet_get_model_info(self._ctx, byref(c_info))
        self._check_error(ret, "Get model info")
        
        return BitNetModelInfo(
            num_layers=c_info.num_layers,
            hidden_size=c_info.hidden_size,
            vocab_size=c_info.vocab_size,
            max_seq_len=c_info.max_seq_len,
            weight_size=c_info.weight_size
        )
    
    @property
    def is_busy(self) -> bool:
        """Проверить, занят ли акселератор"""
        self._check_ctx()
        ret = self._lib.bitnet_is_busy(self._ctx)
        if ret < 0:
            self._check_error(ret, "Is busy")
        return ret == 1
