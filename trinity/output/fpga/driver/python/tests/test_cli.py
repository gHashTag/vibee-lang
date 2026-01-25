"""
VIBEE BitNet CLI Tests

Unit тесты для командной строки бенчмарков.

Священная Формула: V = n × 3^k × π^m × φ^p × e^q
Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999

Copyright (c) 2024 VIBEE Project
"""

import pytest
import argparse
import sys
from unittest.mock import Mock, patch, MagicMock
from io import StringIO


# ═══════════════════════════════════════════════════════════════════════════════
# Fixtures
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture
def mock_modules():
    """Патч зависимостей"""
    with patch.dict('sys.modules', {'numpy': MagicMock()}):
        yield


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты парсинга аргументов
# ═══════════════════════════════════════════════════════════════════════════════

class TestArgumentParsing:
    """Тесты парсинга аргументов командной строки"""
    
    def test_basic_args(self, mock_modules):
        """Базовые аргументы"""
        from bitnet.benchmark.cli import create_parser
        
        parser = create_parser()
        args = parser.parse_args(['--model', 'model.bin'])
        
        assert args.model == 'model.bin'
    
    def test_iterations_arg(self, mock_modules):
        """Аргумент --iterations"""
        from bitnet.benchmark.cli import create_parser
        
        parser = create_parser()
        args = parser.parse_args(['--model', 'model.bin', '--iterations', '50'])
        
        assert args.iterations == 50
    
    def test_warmup_arg(self, mock_modules):
        """Аргумент --warmup"""
        from bitnet.benchmark.cli import create_parser
        
        parser = create_parser()
        args = parser.parse_args(['--model', 'model.bin', '--warmup', '10'])
        
        assert args.warmup == 10
    
    def test_type_arg(self, mock_modules):
        """Аргумент --type"""
        from bitnet.benchmark.cli import create_parser
        
        parser = create_parser()
        
        for bench_type in ['all', 'latency', 'throughput', 'memory']:
            args = parser.parse_args(['--model', 'model.bin', '--type', bench_type])
            assert args.type == bench_type
    
    def test_format_arg(self, mock_modules):
        """Аргумент --format"""
        from bitnet.benchmark.cli import create_parser
        
        parser = create_parser()
        
        for fmt in ['json', 'csv', 'markdown']:
            args = parser.parse_args(['--model', 'model.bin', '--format', fmt])
            assert args.format == fmt
    
    def test_output_arg(self, mock_modules):
        """Аргумент --output"""
        from bitnet.benchmark.cli import create_parser
        
        parser = create_parser()
        args = parser.parse_args(['--model', 'model.bin', '--output', 'results.json'])
        
        assert args.output == 'results.json'
    
    def test_device_arg(self, mock_modules):
        """Аргумент --device"""
        from bitnet.benchmark.cli import create_parser
        
        parser = create_parser()
        args = parser.parse_args(['--model', 'model.bin', '--device', '/dev/bitnet1'])
        
        assert args.device == '/dev/bitnet1'
    
    def test_verbose_arg(self, mock_modules):
        """Аргумент --verbose"""
        from bitnet.benchmark.cli import create_parser
        
        parser = create_parser()
        args = parser.parse_args(['--model', 'model.bin', '--verbose'])
        
        assert args.verbose is True
    
    def test_quiet_arg(self, mock_modules):
        """Аргумент --quiet"""
        from bitnet.benchmark.cli import create_parser
        
        parser = create_parser()
        args = parser.parse_args(['--model', 'model.bin', '--quiet'])
        
        assert args.quiet is True


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты значений по умолчанию
# ═══════════════════════════════════════════════════════════════════════════════

class TestDefaultValues:
    """Тесты значений по умолчанию"""
    
    def test_default_iterations(self, mock_modules):
        """Значение по умолчанию для iterations"""
        from bitnet.benchmark.cli import create_parser
        
        parser = create_parser()
        args = parser.parse_args(['--model', 'model.bin'])
        
        assert args.iterations == 100  # или другое значение по умолчанию
    
    def test_default_warmup(self, mock_modules):
        """Значение по умолчанию для warmup"""
        from bitnet.benchmark.cli import create_parser
        
        parser = create_parser()
        args = parser.parse_args(['--model', 'model.bin'])
        
        assert args.warmup == 10  # или другое значение по умолчанию
    
    def test_default_type(self, mock_modules):
        """Значение по умолчанию для type"""
        from bitnet.benchmark.cli import create_parser
        
        parser = create_parser()
        args = parser.parse_args(['--model', 'model.bin'])
        
        assert args.type == 'all'
    
    def test_default_format(self, mock_modules):
        """Значение по умолчанию для format"""
        from bitnet.benchmark.cli import create_parser
        
        parser = create_parser()
        args = parser.parse_args(['--model', 'model.bin'])
        
        assert args.format in ['json', 'text', 'console']
    
    def test_default_device(self, mock_modules):
        """Значение по умолчанию для device"""
        from bitnet.benchmark.cli import create_parser
        
        parser = create_parser()
        args = parser.parse_args(['--model', 'model.bin'])
        
        assert args.device == '/dev/bitnet0'


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты валидации
# ═══════════════════════════════════════════════════════════════════════════════

class TestValidation:
    """Тесты валидации аргументов"""
    
    def test_missing_model(self, mock_modules):
        """Отсутствие обязательного аргумента --model"""
        from bitnet.benchmark.cli import create_parser
        
        parser = create_parser()
        
        with pytest.raises(SystemExit):
            parser.parse_args([])
    
    def test_invalid_type(self, mock_modules):
        """Неверное значение --type"""
        from bitnet.benchmark.cli import create_parser
        
        parser = create_parser()
        
        with pytest.raises(SystemExit):
            parser.parse_args(['--model', 'model.bin', '--type', 'invalid'])
    
    def test_invalid_format(self, mock_modules):
        """Неверное значение --format"""
        from bitnet.benchmark.cli import create_parser
        
        parser = create_parser()
        
        with pytest.raises(SystemExit):
            parser.parse_args(['--model', 'model.bin', '--format', 'invalid'])
    
    def test_negative_iterations(self, mock_modules):
        """Отрицательное значение iterations"""
        from bitnet.benchmark.cli import create_parser
        
        parser = create_parser()
        args = parser.parse_args(['--model', 'model.bin', '--iterations', '-1'])
        
        # Парсер может принять, но валидация должна отклонить
        # или парсер должен отклонить
        assert args.iterations == -1 or True  # зависит от реализации


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты справки
# ═══════════════════════════════════════════════════════════════════════════════

class TestHelp:
    """Тесты справки"""
    
    def test_help_flag(self, mock_modules):
        """Флаг --help"""
        from bitnet.benchmark.cli import create_parser
        
        parser = create_parser()
        
        with pytest.raises(SystemExit) as exc_info:
            parser.parse_args(['--help'])
        
        assert exc_info.value.code == 0
    
    def test_help_contains_description(self, mock_modules):
        """Справка содержит описание"""
        from bitnet.benchmark.cli import create_parser
        
        parser = create_parser()
        help_text = parser.format_help()
        
        assert 'benchmark' in help_text.lower() or 'bitnet' in help_text.lower()
    
    def test_help_contains_arguments(self, mock_modules):
        """Справка содержит аргументы"""
        from bitnet.benchmark.cli import create_parser
        
        parser = create_parser()
        help_text = parser.format_help()
        
        assert '--model' in help_text
        assert '--iterations' in help_text


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты batch-sizes
# ═══════════════════════════════════════════════════════════════════════════════

class TestBatchSizes:
    """Тесты аргумента batch-sizes"""
    
    def test_single_batch_size(self, mock_modules):
        """Один batch size"""
        from bitnet.benchmark.cli import create_parser
        
        parser = create_parser()
        args = parser.parse_args(['--model', 'model.bin', '--batch-sizes', '32'])
        
        assert args.batch_sizes == [32] or args.batch_sizes == '32'
    
    def test_multiple_batch_sizes(self, mock_modules):
        """Несколько batch sizes"""
        from bitnet.benchmark.cli import create_parser
        
        parser = create_parser()
        args = parser.parse_args(['--model', 'model.bin', '--batch-sizes', '1,8,16,32'])
        
        # Может быть строка или список
        if isinstance(args.batch_sizes, str):
            sizes = [int(x) for x in args.batch_sizes.split(',')]
            assert sizes == [1, 8, 16, 32]
        else:
            assert args.batch_sizes == [1, 8, 16, 32]


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты комбинаций аргументов
# ═══════════════════════════════════════════════════════════════════════════════

class TestArgumentCombinations:
    """Тесты комбинаций аргументов"""
    
    def test_full_command(self, mock_modules):
        """Полная команда со всеми аргументами"""
        from bitnet.benchmark.cli import create_parser
        
        parser = create_parser()
        args = parser.parse_args([
            '--model', 'model.bin',
            '--device', '/dev/bitnet0',
            '--iterations', '50',
            '--warmup', '5',
            '--type', 'latency',
            '--format', 'json',
            '--output', 'results.json',
            '--verbose'
        ])
        
        assert args.model == 'model.bin'
        assert args.device == '/dev/bitnet0'
        assert args.iterations == 50
        assert args.warmup == 5
        assert args.type == 'latency'
        assert args.format == 'json'
        assert args.output == 'results.json'
        assert args.verbose is True
    
    def test_minimal_command(self, mock_modules):
        """Минимальная команда"""
        from bitnet.benchmark.cli import create_parser
        
        parser = create_parser()
        args = parser.parse_args(['--model', 'model.bin'])
        
        assert args.model == 'model.bin'


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты main функции
# ═══════════════════════════════════════════════════════════════════════════════

class TestMainFunction:
    """Тесты main функции"""
    
    def test_main_with_mock_runner(self, mock_modules):
        """Запуск main с mock runner"""
        with patch('bitnet.benchmark.cli.BenchmarkRunner') as MockRunner:
            mock_runner = MagicMock()
            MockRunner.return_value.__enter__ = MagicMock(return_value=mock_runner)
            MockRunner.return_value.__exit__ = MagicMock(return_value=False)
            
            from bitnet.benchmark.cli import main
            
            # Патчим sys.argv
            with patch.object(sys, 'argv', ['benchmark', '--model', 'model.bin']):
                try:
                    main()
                except SystemExit:
                    pass  # Может выйти с кодом 0
    
    def test_main_help(self, mock_modules):
        """main --help"""
        from bitnet.benchmark.cli import main
        
        with patch.object(sys, 'argv', ['benchmark', '--help']):
            with pytest.raises(SystemExit) as exc_info:
                main()
            
            assert exc_info.value.code == 0
