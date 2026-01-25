"""
VIBEE BitNet Report Generator Tests

Unit тесты для модуля генерации отчётов.

Священная Формула: V = n × 3^k × π^m × φ^p × e^q
Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999

Copyright (c) 2024 VIBEE Project
"""

import pytest
import json
import csv
import io
import tempfile
import os
from unittest.mock import Mock, patch, MagicMock
from dataclasses import dataclass, field, asdict
from typing import Dict, Any, List, Optional


# ═══════════════════════════════════════════════════════════════════════════════
# Mock Data Classes (для тестов без зависимостей)
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class MockBenchmarkResult:
    """Mock результат бенчмарка"""
    name: str
    timestamp: str
    duration_seconds: float
    metrics: Dict[str, Any]
    parameters: Dict[str, Any]
    raw_data: List[float] = field(default_factory=list)
    error: Optional[str] = None
    
    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)
    
    def to_json(self) -> str:
        return json.dumps(self.to_dict(), indent=2)


@dataclass
class MockBenchmarkSuite:
    """Mock набор результатов"""
    name: str
    version: str
    timestamp: str
    device: str
    model_path: str
    results: List[MockBenchmarkResult] = field(default_factory=list)
    system_info: Dict[str, Any] = field(default_factory=dict)
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "name": self.name,
            "version": self.version,
            "timestamp": self.timestamp,
            "device": self.device,
            "model_path": self.model_path,
            "system_info": self.system_info,
            "results": [r.to_dict() for r in self.results],
        }


# ═══════════════════════════════════════════════════════════════════════════════
# Fixtures
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture
def sample_result():
    """Пример результата бенчмарка"""
    return MockBenchmarkResult(
        name="latency",
        timestamp="2025-01-25T12:00:00",
        duration_seconds=5.5,
        metrics={
            "mean": 10.5,
            "p50": 10.2,
            "p95": 12.1,
            "p99": 15.3,
            "min": 9.1,
            "max": 16.2
        },
        parameters={
            "input_length": 32,
            "warmup_runs": 5,
            "measurement_runs": 100
        },
        raw_data=[10.1, 10.3, 10.5, 10.8, 11.2]
    )


@pytest.fixture
def sample_suite(sample_result):
    """Пример набора результатов"""
    throughput_result = MockBenchmarkResult(
        name="throughput",
        timestamp="2025-01-25T12:01:00",
        duration_seconds=10.2,
        metrics={
            "tokens_per_second": 1250.5,
            "total_tokens": 12505
        },
        parameters={
            "input_length": 32,
            "output_length": 64
        }
    )
    
    memory_result = MockBenchmarkResult(
        name="memory",
        timestamp="2025-01-25T12:02:00",
        duration_seconds=3.1,
        metrics={
            "bandwidth_gbps": 48.5,
            "total_bytes": 1000000
        },
        parameters={
            "transfer_size": 65536,
            "iterations": 100
        }
    )
    
    suite = MockBenchmarkSuite(
        name="BitNet Benchmark Suite",
        version="1.0.0",
        timestamp="2025-01-25T12:00:00",
        device="/dev/bitnet0",
        model_path="model.bin",
        system_info={
            "platform": "Linux",
            "python_version": "3.11.0"
        }
    )
    suite.results = [sample_result, throughput_result, memory_result]
    return suite


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты JSON генерации
# ═══════════════════════════════════════════════════════════════════════════════

class TestJSONGeneration:
    """Тесты генерации JSON"""
    
    def test_result_to_json(self, sample_result):
        """Проверка сериализации результата в JSON"""
        json_str = sample_result.to_json()
        parsed = json.loads(json_str)
        
        assert parsed["name"] == "latency"
        assert parsed["metrics"]["mean"] == 10.5
        assert parsed["parameters"]["input_length"] == 32
    
    def test_suite_to_json(self, sample_suite):
        """Проверка сериализации suite в JSON"""
        data = sample_suite.to_dict()
        json_str = json.dumps(data, indent=2)
        parsed = json.loads(json_str)
        
        assert parsed["name"] == "BitNet Benchmark Suite"
        assert len(parsed["results"]) == 3
        assert parsed["results"][0]["name"] == "latency"
    
    def test_json_valid_format(self, sample_suite):
        """Проверка валидности JSON"""
        data = sample_suite.to_dict()
        json_str = json.dumps(data)
        
        # Должен парситься без ошибок
        parsed = json.loads(json_str)
        assert isinstance(parsed, dict)
    
    def test_json_contains_all_fields(self, sample_suite):
        """Проверка наличия всех полей"""
        data = sample_suite.to_dict()
        
        required_fields = ["name", "version", "timestamp", "device", "model_path", "results"]
        for field in required_fields:
            assert field in data


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты CSV генерации
# ═══════════════════════════════════════════════════════════════════════════════

class TestCSVGeneration:
    """Тесты генерации CSV"""
    
    def test_basic_csv(self, sample_suite):
        """Базовая генерация CSV"""
        output = io.StringIO()
        writer = csv.writer(output)
        
        # Заголовки
        writer.writerow(["benchmark", "metric", "value"])
        
        # Данные
        for result in sample_suite.results:
            for metric, value in result.metrics.items():
                writer.writerow([result.name, metric, value])
        
        csv_content = output.getvalue()
        assert "benchmark,metric,value" in csv_content
        assert "latency,mean,10.5" in csv_content
    
    def test_csv_all_results(self, sample_suite):
        """Проверка всех результатов в CSV"""
        output = io.StringIO()
        writer = csv.writer(output)
        
        writer.writerow(["benchmark", "metric", "value"])
        for result in sample_suite.results:
            for metric, value in result.metrics.items():
                writer.writerow([result.name, metric, value])
        
        csv_content = output.getvalue()
        
        # Проверяем наличие всех бенчмарков
        assert "latency" in csv_content
        assert "throughput" in csv_content
        assert "memory" in csv_content
    
    def test_csv_parseable(self, sample_suite):
        """Проверка парсинга CSV"""
        output = io.StringIO()
        writer = csv.writer(output)
        
        writer.writerow(["benchmark", "metric", "value"])
        for result in sample_suite.results:
            for metric, value in result.metrics.items():
                writer.writerow([result.name, metric, value])
        
        output.seek(0)
        reader = csv.DictReader(output)
        rows = list(reader)
        
        assert len(rows) > 0
        assert "benchmark" in rows[0]
        assert "metric" in rows[0]
        assert "value" in rows[0]


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты Markdown генерации
# ═══════════════════════════════════════════════════════════════════════════════

class TestMarkdownGeneration:
    """Тесты генерации Markdown"""
    
    def test_basic_markdown(self, sample_suite):
        """Базовая генерация Markdown"""
        lines = []
        lines.append(f"# {sample_suite.name}")
        lines.append("")
        lines.append(f"**Version:** {sample_suite.version}")
        lines.append(f"**Device:** {sample_suite.device}")
        lines.append("")
        
        for result in sample_suite.results:
            lines.append(f"## {result.name.title()}")
            lines.append("")
            lines.append("| Metric | Value |")
            lines.append("|--------|-------|")
            for metric, value in result.metrics.items():
                lines.append(f"| {metric} | {value} |")
            lines.append("")
        
        md_content = "\n".join(lines)
        
        assert "# BitNet Benchmark Suite" in md_content
        assert "## Latency" in md_content
        assert "| mean | 10.5 |" in md_content
    
    def test_markdown_tables(self, sample_suite):
        """Проверка таблиц в Markdown"""
        lines = []
        
        for result in sample_suite.results:
            lines.append(f"## {result.name.title()}")
            lines.append("")
            lines.append("| Metric | Value |")
            lines.append("|--------|-------|")
            for metric, value in result.metrics.items():
                lines.append(f"| {metric} | {value} |")
            lines.append("")
        
        md_content = "\n".join(lines)
        
        # Проверяем структуру таблицы
        assert "|--------|-------|" in md_content
        assert "| Metric | Value |" in md_content
    
    def test_markdown_all_sections(self, sample_suite):
        """Проверка всех секций"""
        lines = []
        
        for result in sample_suite.results:
            lines.append(f"## {result.name.title()}")
        
        md_content = "\n".join(lines)
        
        assert "## Latency" in md_content
        assert "## Throughput" in md_content
        assert "## Memory" in md_content


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты сохранения в файл
# ═══════════════════════════════════════════════════════════════════════════════

class TestFileSaving:
    """Тесты сохранения в файл"""
    
    def test_save_json(self, sample_suite):
        """Сохранение JSON в файл"""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump(sample_suite.to_dict(), f, indent=2)
            path = f.name
        
        try:
            with open(path, 'r') as f:
                loaded = json.load(f)
            
            assert loaded["name"] == sample_suite.name
            assert len(loaded["results"]) == 3
        finally:
            os.unlink(path)
    
    def test_save_csv(self, sample_suite):
        """Сохранение CSV в файл"""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.csv', delete=False, newline='') as f:
            writer = csv.writer(f)
            writer.writerow(["benchmark", "metric", "value"])
            for result in sample_suite.results:
                for metric, value in result.metrics.items():
                    writer.writerow([result.name, metric, value])
            path = f.name
        
        try:
            with open(path, 'r') as f:
                reader = csv.DictReader(f)
                rows = list(reader)
            
            assert len(rows) > 0
        finally:
            os.unlink(path)
    
    def test_save_markdown(self, sample_suite):
        """Сохранение Markdown в файл"""
        lines = [f"# {sample_suite.name}", ""]
        for result in sample_suite.results:
            lines.append(f"## {result.name.title()}")
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write("\n".join(lines))
            path = f.name
        
        try:
            with open(path, 'r') as f:
                content = f.read()
            
            assert "# BitNet Benchmark Suite" in content
        finally:
            os.unlink(path)


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты ReportGenerator класса
# ═══════════════════════════════════════════════════════════════════════════════

class TestReportGenerator:
    """Тесты класса ReportGenerator"""
    
    def test_init(self, sample_suite):
        """Проверка инициализации"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.report import ReportGenerator
            
            gen = ReportGenerator(sample_suite)
            assert gen._suite is sample_suite
    
    def test_to_json_method(self, sample_suite):
        """Проверка метода to_json"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.report import ReportGenerator
            
            gen = ReportGenerator(sample_suite)
            json_str = gen.to_json()
            
            parsed = json.loads(json_str)
            assert "name" in parsed
    
    def test_to_csv_method(self, sample_suite):
        """Проверка метода to_csv"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.report import ReportGenerator
            
            gen = ReportGenerator(sample_suite)
            csv_str = gen.to_csv()
            
            assert "benchmark" in csv_str or "metric" in csv_str
    
    def test_to_markdown_method(self, sample_suite):
        """Проверка метода to_markdown"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.report import ReportGenerator
            
            gen = ReportGenerator(sample_suite)
            md_str = gen.to_markdown()
            
            assert "#" in md_str  # Заголовки


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты граничных случаев
# ═══════════════════════════════════════════════════════════════════════════════

class TestReportEdgeCases:
    """Тесты граничных случаев"""
    
    def test_empty_results(self):
        """Пустой список результатов"""
        suite = MockBenchmarkSuite(
            name="Empty Suite",
            version="1.0.0",
            timestamp="2025-01-25T12:00:00",
            device="/dev/bitnet0",
            model_path="model.bin"
        )
        
        data = suite.to_dict()
        assert data["results"] == []
    
    def test_empty_metrics(self):
        """Пустые метрики"""
        result = MockBenchmarkResult(
            name="empty",
            timestamp="2025-01-25T12:00:00",
            duration_seconds=0.0,
            metrics={},
            parameters={}
        )
        
        json_str = result.to_json()
        parsed = json.loads(json_str)
        assert parsed["metrics"] == {}
    
    def test_special_characters(self):
        """Специальные символы в данных"""
        result = MockBenchmarkResult(
            name="test<>\"'&",
            timestamp="2025-01-25T12:00:00",
            duration_seconds=1.0,
            metrics={"key": "value<>\"'&"},
            parameters={}
        )
        
        json_str = result.to_json()
        parsed = json.loads(json_str)
        assert parsed["name"] == "test<>\"'&"
