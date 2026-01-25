"""
VIBEE BitNet Core Tests

Тесты для основного модуля bitnet

Copyright (c) 2024 VIBEE Project
"""

import pytest
import numpy as np
from unittest.mock import Mock, patch, MagicMock
import ctypes

# Mock libbitnet для тестирования без реального устройства
@pytest.fixture
def mock_lib():
    """Создать mock библиотеки"""
    mock = MagicMock()
    
    # Mock context
    mock.bitnet_init.return_value = ctypes.c_void_p(0x12345678)
    mock.bitnet_destroy.return_value = None
    mock.bitnet_reset.return_value = 0
    mock.bitnet_load_weights.return_value = 0
    mock.bitnet_load_layer_weights.return_value = 0
    mock.bitnet_inference.return_value = 10  # 10 output tokens
    mock.bitnet_inference_async.return_value = 0
    mock.bitnet_wait.return_value = 0
    mock.bitnet_get_output.return_value = 10
    mock.bitnet_abort.return_value = 0
    mock.bitnet_get_status.return_value = 0
    mock.bitnet_get_perf.return_value = 0
    mock.bitnet_is_busy.return_value = 0
    mock.bitnet_strerror.return_value = b"Success"
    mock.bitnet_version.return_value = b"1.0.0"
    
    return mock


class TestBitNetCore:
    """Тесты для BitNet класса"""
    
    def test_import(self):
        """Тест импорта модуля"""
        from bitnet import BitNet, BitNetError
        assert BitNet is not None
        assert BitNetError is not None
    
    def test_error_messages(self):
        """Тест сообщений об ошибках"""
        from bitnet.core import ERROR_MESSAGES, BITNET_SUCCESS, BITNET_ERR_TIMEOUT
        
        assert BITNET_SUCCESS in ERROR_MESSAGES
        assert BITNET_ERR_TIMEOUT in ERROR_MESSAGES
        assert ERROR_MESSAGES[BITNET_SUCCESS] == "Success"
    
    def test_state_names(self):
        """Тест имён состояний"""
        from bitnet.core import STATE_NAMES
        
        assert 0 in STATE_NAMES
        assert STATE_NAMES[0] == "IDLE"
        assert STATE_NAMES[2] == "RUNNING"
    
    def test_bitnet_error(self):
        """Тест исключения BitNetError"""
        from bitnet import BitNetError
        
        err = BitNetError(-4, "Test timeout")
        assert err.code == -4
        assert err.message == "Test timeout"
        assert "Test timeout" in str(err)
    
    def test_status_dataclass(self):
        """Тест BitNetStatus dataclass"""
        from bitnet import BitNetStatus
        
        status = BitNetStatus(
            state="IDLE",
            current_layer=5,
            tokens_processed=100,
            error_code=0
        )
        
        assert status.state == "IDLE"
        assert status.current_layer == 5
        assert status.tokens_processed == 100
        assert status.error_code == 0
    
    def test_performance_dataclass(self):
        """Тест BitNetPerformance dataclass"""
        from bitnet import BitNetPerformance
        
        perf = BitNetPerformance(
            total_cycles=1000000,
            dma_cycles=100000,
            compute_cycles=900000,
            tokens_per_second=5000,
            inference_count=10
        )
        
        assert perf.total_cycles == 1000000
        assert perf.tokens_per_second == 5000


class TestNumpyAPI:
    """Тесты для NumPy API"""
    
    def test_tokens_to_numpy_list(self):
        """Тест конвертации list в numpy"""
        from bitnet.numpy_api import tokens_to_numpy
        
        tokens = [1, 2, 3, 4, 5]
        arr = tokens_to_numpy(tokens)
        
        assert isinstance(arr, np.ndarray)
        assert arr.dtype == np.int32
        assert len(arr) == 5
        assert arr[0] == 1
    
    def test_tokens_to_numpy_array(self):
        """Тест конвертации numpy array"""
        from bitnet.numpy_api import tokens_to_numpy
        
        arr_in = np.array([1, 2, 3], dtype=np.int64)
        arr_out = tokens_to_numpy(arr_in)
        
        assert arr_out.dtype == np.int32
    
    def test_pad_sequences(self):
        """Тест padding последовательностей"""
        from bitnet.numpy_api import pad_sequences
        
        seqs = [[1, 2, 3], [4, 5]]
        padded = pad_sequences(seqs, max_len=5, pad_token_id=0)
        
        assert padded.shape == (2, 5)
        assert padded[0, 0] == 1
        assert padded[0, 3] == 0  # padding
        assert padded[1, 2] == 0  # padding
    
    def test_pad_sequences_left(self):
        """Тест left padding"""
        from bitnet.numpy_api import pad_sequences
        
        seqs = [[1, 2, 3]]
        padded = pad_sequences(seqs, max_len=5, padding="left")
        
        assert padded[0, 0] == 0  # padding
        assert padded[0, 2] == 1  # first token
    
    def test_unpad_sequence(self):
        """Тест удаления padding"""
        from bitnet.numpy_api import unpad_sequence
        
        seq = np.array([1, 2, 3, 0, 0], dtype=np.int32)
        unpadded = unpad_sequence(seq, pad_token_id=0)
        
        assert len(unpadded) == 3
        assert unpadded[-1] == 3


class TestMockInference:
    """Тесты с mock библиотекой"""
    
    @patch('bitnet.core._get_lib')
    def test_init_success(self, mock_get_lib, mock_lib):
        """Тест успешной инициализации"""
        mock_get_lib.return_value = mock_lib
        
        from bitnet import BitNet
        
        bn = BitNet("/dev/bitnet0")
        assert bn._ctx is not None
        mock_lib.bitnet_init.assert_called_once()
    
    @patch('bitnet.core._get_lib')
    def test_init_failure(self, mock_get_lib, mock_lib):
        """Тест неудачной инициализации"""
        mock_lib.bitnet_init.return_value = None
        mock_get_lib.return_value = mock_lib
        
        from bitnet import BitNet, BitNetError
        
        with pytest.raises(BitNetError):
            BitNet("/dev/nonexistent")
    
    @patch('bitnet.core._get_lib')
    def test_context_manager(self, mock_get_lib, mock_lib):
        """Тест context manager"""
        mock_get_lib.return_value = mock_lib
        
        from bitnet import BitNet
        
        with BitNet() as bn:
            assert bn._ctx is not None
        
        mock_lib.bitnet_destroy.assert_called_once()


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
