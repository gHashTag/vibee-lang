"""
VIBEE BitNet Python Package Setup

Священная Формула: V = n × 3^k × π^m × φ^p × e^q
Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999

Copyright (c) 2024 VIBEE Project
"""

from setuptools import setup, find_packages
from pathlib import Path

# Read README
readme_path = Path(__file__).parent / "README.md"
long_description = ""
if readme_path.exists():
    long_description = readme_path.read_text(encoding="utf-8")

setup(
    name="bitnet",
    version="1.0.0",
    author="VIBEE Project",
    author_email="vibee@example.com",
    description="Python bindings for VIBEE BitNet FPGA accelerator",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/gHashTag/vibee-lang",
    project_urls={
        "Bug Tracker": "https://github.com/gHashTag/vibee-lang/issues",
        "Documentation": "https://github.com/gHashTag/vibee-lang/tree/main/trinity/output/fpga/driver",
    },
    
    packages=find_packages(),
    python_requires=">=3.8",
    
    install_requires=[
        "numpy>=1.20",
    ],
    
    extras_require={
        "torch": ["torch>=2.0"],
        "dev": [
            "pytest>=7.0",
            "pytest-cov>=4.0",
            "black>=23.0",
            "mypy>=1.0",
        ],
        "all": [
            "torch>=2.0",
            "pytest>=7.0",
        ],
    },
    
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "Intended Audience :: Science/Research",
        "License :: OSI Approved :: MIT License",
        "Operating System :: POSIX :: Linux",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Topic :: Scientific/Engineering :: Artificial Intelligence",
        "Topic :: System :: Hardware",
    ],
    
    keywords=[
        "bitnet",
        "fpga",
        "accelerator",
        "inference",
        "llm",
        "ternary",
        "quantization",
        "zynq",
    ],
    
    package_data={
        "bitnet": ["*.so", "*.dll"],
    },
    
    entry_points={
        "console_scripts": [
            "bitnet-test=bitnet.test:main",
        ],
    },
)
