#!/bin/bash
# Download SWE-bench Lite dataset
# φ² + 1/φ² = 3 | PHOENIX = 999

set -e

DATASET_DIR="data/swe_bench"
LITE_URL="https://huggingface.co/datasets/princeton-nlp/SWE-bench_Lite/resolve/main/data/test-00000-of-00001.parquet"

echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    SWE-bench Lite Dataset Downloader"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""

# Create data directory
mkdir -p "$DATASET_DIR"

echo "📥 Downloading SWE-bench Lite (300 instances)..."

# Download using curl
if command -v curl &> /dev/null; then
    curl -L -o "$DATASET_DIR/swe_bench_lite.parquet" "$LITE_URL"
elif command -v wget &> /dev/null; then
    wget -O "$DATASET_DIR/swe_bench_lite.parquet" "$LITE_URL"
else
    echo "❌ Error: curl or wget required"
    exit 1
fi

echo ""
echo "✅ Downloaded to: $DATASET_DIR/swe_bench_lite.parquet"
echo ""

# Check file size
FILE_SIZE=$(ls -lh "$DATASET_DIR/swe_bench_lite.parquet" | awk '{print $5}')
echo "📊 File size: $FILE_SIZE"

# Convert to JSON if Python available
if command -v python3 &> /dev/null; then
    echo ""
    echo "🔄 Converting to JSON..."
    
    python3 << 'EOF'
import json
import sys

try:
    import pandas as pd
    df = pd.read_parquet("data/swe_bench/swe_bench_lite.parquet")
    
    # Convert to list of dicts
    instances = df.to_dict(orient='records')
    
    # Save as JSON
    with open("data/swe_bench/swe_bench_lite.json", "w") as f:
        json.dump(instances, f, indent=2, default=str)
    
    print(f"✅ Converted {len(instances)} instances to JSON")
    print(f"📁 Output: data/swe_bench/swe_bench_lite.json")
    
    # Print sample repos
    repos = df['repo'].unique()
    print(f"\n📦 Repositories ({len(repos)}):")
    for repo in repos[:10]:
        count = len(df[df['repo'] == repo])
        print(f"   - {repo}: {count} instances")
        
except ImportError:
    print("⚠️  pandas/pyarrow not installed, skipping JSON conversion")
    print("   Install with: pip install pandas pyarrow")
except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)
EOF
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                         DOWNLOAD COMPLETE"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "  1. Run benchmark: vibee bench run --dataset lite --limit 5"
echo "  2. View results:  vibee bench report"
echo ""
echo "φ² + 1/φ² = 3 | PHOENIX = 999"
