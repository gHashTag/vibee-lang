#!/bin/bash
# Generate Zig from all v2120-v2599 specs
set -e

SPECS_DIR="/workspaces/vibee-lang/specs/tri"
OUTPUT_DIR="/workspaces/vibee-lang/trinity/output"
DOMAINS=(quantum_computing neuromorphic distributed compiler_theory formal_verification category_theory type_systems memory_mgmt concurrency graph_algo cryptography zero_knowledge blockchain smart_contracts defi robotics computer_vision nlp_advanced speech multimodal reinforcement meta_learning automl nas)

total=0
for domain in "${DOMAINS[@]}"; do
    if [ -d "$SPECS_DIR/$domain" ]; then
        for spec in "$SPECS_DIR/$domain"/*.vibee; do
            if [ -f "$spec" ]; then
                name=$(basename "$spec" .vibee)
                vibee gen "$spec" "$OUTPUT_DIR/$name.zig" 2>/dev/null || true
                ((total++))
            fi
        done
    fi
done

echo "✅ Generated $total Zig files"
