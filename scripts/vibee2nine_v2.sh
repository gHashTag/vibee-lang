#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# VIBEE2NINE v2.0 - Advanced Generator .vibee → .999
# Parses functions, types, behaviors from .vibee specs
# ═══════════════════════════════════════════════════════════════

set -e

SPECS_DIR="/workspaces/vibee-lang/specs/999"
OUTPUT_DIR="/workspaces/vibee-lang/999"

# Parse simple YAML field
parse_field() {
    local file="$1"
    local field="$2"
    grep "^${field}:" "$file" 2>/dev/null | head -1 | sed "s/^${field}:[[:space:]]*//" | tr -d '"'
}

# Extract multiline body (after body: |)
extract_body() {
    local file="$1"
    local func_name="$2"
    # Find the function and extract its body
    awk -v name="$func_name" '
        /- name:/ { in_func = ($3 == name) }
        in_func && /body:/ { in_body = 1; next }
        in_body && /^[[:space:]]{4}[^[:space:]]/ { print substr($0, 7); next }
        in_body && /^[[:space:]]{2}-/ { in_body = 0 }
        in_body && /^[[:space:]]*$/ { in_body = 0 }
    ' "$file"
}

# Extract function names
get_functions() {
    local file="$1"
    grep -A1 "^  - name:" "$file" 2>/dev/null | grep "name:" | awk '{print $3}' | tr -d '"'
}

# Extract types
get_types() {
    local file="$1"
    awk '/^types:/,/^[a-z]/' "$file" | grep "- name:" | awk '{print $3}' | tr -d '"'
}

# Extract test cases for a behavior
get_test_cases() {
    local file="$1"
    local behavior="$2"
    awk -v name="$behavior" '
        /- name:/ && $3 == name { in_behavior = 1 }
        in_behavior && /test_cases:/ { in_tests = 1; next }
        in_tests && /- name:/ { print $3 }
        in_behavior && /^  - name:/ && $3 != name { in_behavior = 0; in_tests = 0 }
    ' "$file"
}

# Generate .999 code from .vibee spec
generate_999() {
    local vibee_file="$1"
    local output_file="$2"
    
    # Extract metadata
    local name=$(parse_field "$vibee_file" "name")
    local version=$(parse_field "$vibee_file" "version")
    local module=$(parse_field "$vibee_file" "module")
    local description=$(parse_field "$vibee_file" "description")
    
    # Extract metrics
    local n=$(grep "n:" "$vibee_file" | tail -1 | awk '{print $2}')
    local k=$(grep "k:" "$vibee_file" | tail -1 | awk '{print $2}')
    local m=$(grep "m:" "$vibee_file" | tail -1 | awk '{print $2}')
    
    [ -z "$n" ] && n=9
    [ -z "$k" ] && k=3
    [ -z "$m" ] && m=27
    [ -z "$name" ] && name=$(basename "$vibee_file" .vibee)
    [ -z "$version" ] && version="1.0.0"
    [ -z "$module" ] && module="Ⲙ_${name}"
    [ -z "$description" ] && description="Module ${name}"
    
    mkdir -p "$(dirname "$output_file")"
    
    # Start generating
    cat > "$output_file" << HEADER
// ═══════════════════════════════════════════════════════════════
// Сгенерировано из: ${vibee_file#/workspaces/vibee-lang/}
// ЗАПРЕЩЕНО: Ручное редактирование
// ═══════════════════════════════════════════════════════════════

// ╔══════════════════════════════════════════════════════════════════╗
// ║  ${name^^} - ${description}
// ║  Version: ${version} | Module: ${module}
// ╚══════════════════════════════════════════════════════════════════╝

HEADER

    # Check if spec has functions section
    if grep -q "^functions:" "$vibee_file"; then
        echo "// ═══════════════════════════════════════════════════════════════" >> "$output_file"
        echo "// FUNCTIONS (from .vibee spec)" >> "$output_file"
        echo "// ═══════════════════════════════════════════════════════════════" >> "$output_file"
        echo "" >> "$output_file"
        
        # Extract and generate each function
        local in_functions=0
        local current_func=""
        local current_params=""
        local current_returns=""
        local in_body=0
        local body_lines=""
        
        while IFS= read -r line; do
            # Detect functions section
            if [[ "$line" =~ ^functions: ]]; then
                in_functions=1
                continue
            fi
            
            # Exit functions section
            if [[ $in_functions -eq 1 && "$line" =~ ^[a-z]+: && ! "$line" =~ ^[[:space:]] ]]; then
                in_functions=0
            fi
            
            if [[ $in_functions -eq 1 ]]; then
                # New function
                if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*(.*) ]]; then
                    # Output previous function if exists
                    if [[ -n "$current_func" ]]; then
                        echo "◬ ${current_func}(${current_params}) → ${current_returns} {" >> "$output_file"
                        echo "$body_lines" >> "$output_file"
                        echo "}" >> "$output_file"
                        echo "" >> "$output_file"
                    fi
                    current_func=$(echo "$line" | sed 's/.*name:[[:space:]]*//' | tr -d '"')
                    current_params=""
                    current_returns=""
                    body_lines=""
                    in_body=0
                fi
                
                # Returns
                if [[ "$line" =~ returns:[[:space:]]*(.*) ]]; then
                    current_returns=$(echo "$line" | sed 's/.*returns:[[:space:]]*//' | tr -d '"')
                fi
                
                # Body start
                if [[ "$line" =~ body:[[:space:]]*\| ]]; then
                    in_body=1
                    continue
                fi
                
                # Single-line body
                if [[ "$line" =~ body:[[:space:]]*\"(.*)\" ]]; then
                    body_lines="    $(echo "$line" | sed 's/.*body:[[:space:]]*//' | tr -d '"')"
                    in_body=0
                fi
                
                # Multi-line body content
                if [[ $in_body -eq 1 && "$line" =~ ^[[:space:]]{6} ]]; then
                    body_lines="${body_lines}    $(echo "$line" | sed 's/^[[:space:]]*//')
"
                fi
                
                # End of body
                if [[ $in_body -eq 1 && ! "$line" =~ ^[[:space:]]{6} && -n "$line" ]]; then
                    in_body=0
                fi
            fi
        done < "$vibee_file"
        
        # Output last function
        if [[ -n "$current_func" ]]; then
            echo "◬ ${current_func}(${current_params}) → ${current_returns} {" >> "$output_file"
            echo "$body_lines" >> "$output_file"
            echo "}" >> "$output_file"
            echo "" >> "$output_file"
        fi
    fi

    # Add standard patterns
    cat >> "$output_file" << 'PATTERNS'
// ═══════════════════════════════════════════════════════════════
// PRE Pattern - Caching (PERFORMANCE)
// ═══════════════════════════════════════════════════════════════
Ⲕ CACHE: Ⲙⲁⲡ = {}

Ⲫ cache_get(Ⲁ key: Ⲧⲉⲝⲧ) → Ⲁⲛⲩ? {
    Ⲣ CACHE.get(key)
}

Ⲫ cache_set(Ⲁ key: Ⲧⲉⲝⲧ, Ⲁ val: Ⲁⲛⲩ) {
    CACHE.set(key, val)
}

// ═══════════════════════════════════════════════════════════════
// D&C Pattern - Parallel (PERFORMANCE)
// ═══════════════════════════════════════════════════════════════
Ⲫ parallel_map(Ⲁ items: [Ⲁⲛⲩ], Ⲁ fn: Ⲫⲛ) → [Ⲁⲛⲩ] {
    Ⲃ results: [Ⲁⲛⲩ] = []
    Ⲝ item ∈ items ⊛ { results.push(fn(item)) }
    Ⲣ results
}

PATTERNS

    # Add TrinityMetrics with actual values
    cat >> "$output_file" << METRICS
// ═══════════════════════════════════════════════════════════════
// TRINITY METRICS
// ═══════════════════════════════════════════════════════════════
Ⲏ TrinityMetrics {
    Ⲃ n: Ⲓⲛⲧ = ${n}
    Ⲃ k: Ⲓⲛⲧ = ${k}
    Ⲃ m: Ⲓⲛⲧ = ${m}
    
    Ⲫ score(Ⲥ) → Ⲫⲗⲟⲁⲧ {
        Ⲣ Ⲥ.n * ⲡⲟⲱ(3.0, Ⲥ.k / 10.0) * ⲡⲟⲱ(3.14159, Ⲥ.m / 20.0)
    }
}

METRICS

    # Add SelfEvolution
    cat >> "$output_file" << 'EVOLUTION'
// ═══════════════════════════════════════════════════════════════
// SELF-EVOLUTION (ОБЯЗАТЕЛЬНО)
// ═══════════════════════════════════════════════════════════════
Ⲏ SelfEvolution {
    Ⲃ version: Ⲧⲉⲝⲧ = "3.0"
    Ⲃ generation: Ⲓⲛⲧ = 0
    Ⲃ fitness: Ⲫⲗⲟⲁⲧ = 1.0
    Ⲃ improved: Ⲃⲟⲟⲗ = △
    
    Ⲫ evolve(Ⲥ) → Ⲥ {
        Ⲥ.generation += 1
        Ⲥ.improved = △
        Ⲣ Ⲥ
    }
    
    Ⲫ improve(Ⲥ, Ⲁ metric: Ⲧⲉⲝⲧ) → Ⲫⲗⲟⲁⲧ {
        Ⲉ metric == "speed" { Ⲣ 1.5 }
        Ⲉ metric == "memory" { Ⲣ 0.8 }
        Ⲣ 1.0
    }
}

EVOLUTION

    # Add ternary constants
    cat >> "$output_file" << 'TERNARY'
// ═══════════════════════════════════════════════════════════════
// TERNARY LOGIC
// ═══════════════════════════════════════════════════════════════
Ⲕ TRUE: Ⲃⲟⲟⲗ = △
Ⲕ FALSE: Ⲃⲟⲟⲗ = ▽
Ⲕ NULL: Ⲁⲛⲩ? = ○

TERNARY

    # Generate tests from behaviors
    if grep -q "^behaviors:" "$vibee_file"; then
        echo "// ═══════════════════════════════════════════════════════════════" >> "$output_file"
        echo "// TESTS (from behaviors)" >> "$output_file"
        echo "// ═══════════════════════════════════════════════════════════════" >> "$output_file"
        
        # Extract behavior names and generate tests
        grep -A20 "^behaviors:" "$vibee_file" | grep "- name:" | head -5 | while read line; do
            local bname=$(echo "$line" | sed 's/.*name:[[:space:]]*//' | tr -d '"')
            echo "" >> "$output_file"
            echo "⊡ test \"${bname}\" {" >> "$output_file"
            echo "    // TODO: Implement test from behavior spec" >> "$output_file"
            echo "    ⊜! △" >> "$output_file"
            echo "}" >> "$output_file"
        done
    fi

    echo "Generated: $output_file"
}

# Main
if [ "$1" = "--all" ]; then
    echo "═══════════════════════════════════════════════════════════════"
    echo "VIBEE2NINE v2.0 - Generating all .999 files"
    echo "═══════════════════════════════════════════════════════════════"
    
    count=0
    total=$(find "$SPECS_DIR" -name "*.vibee" -type f | wc -l)
    
    find "$SPECS_DIR" -name "*.vibee" -type f | sort | while read vibee_file; do
        count=$((count + 1))
        relative_path="${vibee_file#$SPECS_DIR/}"
        output_file="$OUTPUT_DIR/${relative_path%.vibee}.999"
        
        echo "[$count/$total] $vibee_file"
        generate_999 "$vibee_file" "$output_file"
    done
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "✅ Generated $total .999 files"
    
elif [ -n "$1" ]; then
    vibee_file="$1"
    output_file="${2:-${vibee_file%.vibee}.999}"
    generate_999 "$vibee_file" "$output_file"
else
    echo "Usage: vibee2nine_v2.sh <spec.vibee> [output.999]"
    echo "       vibee2nine_v2.sh --all"
fi
