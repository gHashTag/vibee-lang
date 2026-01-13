#!/bin/bash
# VIBEEC Self-Evolution Runner
# Запускает генетический алгоритм для оптимизации кодогенерации

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
VIBEEC="$REPO_ROOT/src/vibeec/zig-out/bin/vibeec"
BENCHMARK_DIR="$REPO_ROOT/benchmark"

# Конфигурация по умолчанию
POPULATION_SIZE=20
GENERATIONS=50
MUTATION_RATE=0.1
CROSSOVER_RATE=0.7
ELITE_COUNT=2
TARGET="zig"
OPTIMIZE_FOR="balanced"

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║              🧬 VIBEEC SELF-EVOLUTION SYSTEM 🧬                   ║"
    echo "╠═══════════════════════════════════════════════════════════════════╣"
    echo "║  Генетический алгоритм для оптимизации кодогенерации              ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo ""
}

print_config() {
    echo "Конфигурация:"
    echo "  Population:     $POPULATION_SIZE"
    echo "  Generations:    $GENERATIONS"
    echo "  Mutation rate:  $MUTATION_RATE"
    echo "  Crossover rate: $CROSSOVER_RATE"
    echo "  Elite count:    $ELITE_COUNT"
    echo "  Target:         $TARGET"
    echo "  Optimize for:   $OPTIMIZE_FOR"
    echo ""
}

# Создать случайный геном
create_random_genome() {
    local id=$1
    cat << EOF
{
  "id": "genome_${id}",
  "generation": 0,
  "fitness": 0.0,
  "params": {
    "optimization_level": $((RANDOM % 4)),
    "inline_threshold": $((RANDOM % 101)),
    "loop_unroll_factor": $((RANDOM % 8 + 1)),
    "use_simd": $([ $((RANDOM % 2)) -eq 1 ] && echo "true" || echo "false"),
    "dead_code_elimination": $((RANDOM % 101)),
    "constant_folding_depth": $((RANDOM % 10 + 1)),
    "register_allocation": $((RANDOM % 3)),
    "code_layout": $((RANDOM % 3))
  }
}
EOF
}

# Оценить fitness генома
evaluate_fitness() {
    local genome_file=$1
    
    # Симуляция оценки (в реальности здесь был бы запуск бенчмарков)
    # Читаем параметры генома
    local opt_level=$(jq -r '.params.optimization_level' "$genome_file")
    local inline=$(jq -r '.params.inline_threshold' "$genome_file")
    local simd=$(jq -r '.params.use_simd' "$genome_file")
    
    # Простая fitness функция (симуляция)
    local base_fitness=0.5
    
    # Бонус за высокий уровень оптимизации
    base_fitness=$(echo "$base_fitness + $opt_level * 0.1" | bc)
    
    # Бонус за SIMD
    if [ "$simd" = "true" ]; then
        base_fitness=$(echo "$base_fitness + 0.05" | bc)
    fi
    
    # Бонус за оптимальный inline threshold (50-70)
    if [ "$inline" -ge 50 ] && [ "$inline" -le 70 ]; then
        base_fitness=$(echo "$base_fitness + 0.1" | bc)
    fi
    
    # Добавляем случайный шум
    local noise=$(echo "scale=4; ($RANDOM % 100) / 1000" | bc)
    base_fitness=$(echo "$base_fitness + $noise" | bc)
    
    echo "$base_fitness"
}

# Мутация генома
mutate_genome() {
    local genome_file=$1
    local output_file=$2
    
    # Читаем геном
    local genome=$(cat "$genome_file")
    
    # Мутируем с вероятностью MUTATION_RATE
    if [ $(echo "$RANDOM % 100 < $MUTATION_RATE * 100" | bc) -eq 1 ]; then
        genome=$(echo "$genome" | jq ".params.optimization_level = $((RANDOM % 4))")
    fi
    if [ $(echo "$RANDOM % 100 < $MUTATION_RATE * 100" | bc) -eq 1 ]; then
        genome=$(echo "$genome" | jq ".params.inline_threshold = $((RANDOM % 101))")
    fi
    if [ $(echo "$RANDOM % 100 < $MUTATION_RATE * 100" | bc) -eq 1 ]; then
        genome=$(echo "$genome" | jq ".params.use_simd = $([ $((RANDOM % 2)) -eq 1 ] && echo "true" || echo "false")")
    fi
    
    echo "$genome" > "$output_file"
}

# Кроссовер двух геномов
crossover_genomes() {
    local parent_a=$1
    local parent_b=$2
    local output_file=$3
    
    # Читаем родителей
    local a=$(cat "$parent_a")
    local b=$(cat "$parent_b")
    
    # Uniform crossover
    local child="{"
    child+="\"id\": \"genome_$(date +%s%N)\","
    child+="\"generation\": $(jq -r '.generation' "$parent_a"),"
    child+="\"fitness\": 0.0,"
    child+="\"params\": {"
    
    # Случайно выбираем гены от родителей
    if [ $((RANDOM % 2)) -eq 0 ]; then
        child+="\"optimization_level\": $(jq -r '.params.optimization_level' "$parent_a"),"
    else
        child+="\"optimization_level\": $(jq -r '.params.optimization_level' "$parent_b"),"
    fi
    
    if [ $((RANDOM % 2)) -eq 0 ]; then
        child+="\"inline_threshold\": $(jq -r '.params.inline_threshold' "$parent_a"),"
    else
        child+="\"inline_threshold\": $(jq -r '.params.inline_threshold' "$parent_b"),"
    fi
    
    if [ $((RANDOM % 2)) -eq 0 ]; then
        child+="\"loop_unroll_factor\": $(jq -r '.params.loop_unroll_factor' "$parent_a"),"
    else
        child+="\"loop_unroll_factor\": $(jq -r '.params.loop_unroll_factor' "$parent_b"),"
    fi
    
    if [ $((RANDOM % 2)) -eq 0 ]; then
        child+="\"use_simd\": $(jq -r '.params.use_simd' "$parent_a"),"
    else
        child+="\"use_simd\": $(jq -r '.params.use_simd' "$parent_b"),"
    fi
    
    if [ $((RANDOM % 2)) -eq 0 ]; then
        child+="\"dead_code_elimination\": $(jq -r '.params.dead_code_elimination' "$parent_a"),"
    else
        child+="\"dead_code_elimination\": $(jq -r '.params.dead_code_elimination' "$parent_b"),"
    fi
    
    if [ $((RANDOM % 2)) -eq 0 ]; then
        child+="\"constant_folding_depth\": $(jq -r '.params.constant_folding_depth' "$parent_a"),"
    else
        child+="\"constant_folding_depth\": $(jq -r '.params.constant_folding_depth' "$parent_b"),"
    fi
    
    if [ $((RANDOM % 2)) -eq 0 ]; then
        child+="\"register_allocation\": $(jq -r '.params.register_allocation' "$parent_a"),"
    else
        child+="\"register_allocation\": $(jq -r '.params.register_allocation' "$parent_b"),"
    fi
    
    if [ $((RANDOM % 2)) -eq 0 ]; then
        child+="\"code_layout\": $(jq -r '.params.code_layout' "$parent_a")"
    else
        child+="\"code_layout\": $(jq -r '.params.code_layout' "$parent_b")"
    fi
    
    child+="}}"
    
    echo "$child" > "$output_file"
}

# Основной цикл эволюции
run_evolution() {
    local work_dir=$(mktemp -d)
    local population_dir="$work_dir/population"
    mkdir -p "$population_dir"
    
    echo "Рабочая директория: $work_dir"
    echo ""
    
    # 1. Инициализация популяции
    echo -e "${BLUE}═══ Инициализация популяции ═══${NC}"
    for i in $(seq 1 $POPULATION_SIZE); do
        create_random_genome $i > "$population_dir/genome_$i.json"
    done
    echo "Создано $POPULATION_SIZE геномов"
    echo ""
    
    local best_fitness=0
    local best_genome=""
    
    # 2. Цикл эволюции
    for gen in $(seq 1 $GENERATIONS); do
        echo -e "${BLUE}═══ Поколение $gen/$GENERATIONS ═══${NC}"
        
        # Оценка fitness
        local fitness_sum=0
        local max_fitness=0
        local min_fitness=1
        
        for genome_file in "$population_dir"/*.json; do
            local fitness=$(evaluate_fitness "$genome_file")
            
            # Обновляем fitness в файле
            local genome=$(cat "$genome_file")
            genome=$(echo "$genome" | jq ".fitness = $fitness | .generation = $gen")
            echo "$genome" > "$genome_file"
            
            fitness_sum=$(echo "$fitness_sum + $fitness" | bc)
            
            if [ $(echo "$fitness > $max_fitness" | bc) -eq 1 ]; then
                max_fitness=$fitness
                if [ $(echo "$fitness > $best_fitness" | bc) -eq 1 ]; then
                    best_fitness=$fitness
                    best_genome=$(cat "$genome_file")
                fi
            fi
            
            if [ $(echo "$fitness < $min_fitness" | bc) -eq 1 ]; then
                min_fitness=$fitness
            fi
        done
        
        local avg_fitness=$(echo "scale=4; $fitness_sum / $POPULATION_SIZE" | bc)
        
        printf "  avg=%.4f  max=%.4f  min=%.4f  best=%.4f\n" "$avg_fitness" "$max_fitness" "$min_fitness" "$best_fitness"
        
        # Отбор и размножение (кроме последнего поколения)
        if [ $gen -lt $GENERATIONS ]; then
            # Сортируем по fitness
            local sorted_genomes=$(ls "$population_dir"/*.json | while read f; do
                echo "$(jq -r '.fitness' "$f") $f"
            done | sort -rn | head -$POPULATION_SIZE)
            
            # Сохраняем элиту
            local elite_dir="$work_dir/elite"
            mkdir -p "$elite_dir"
            echo "$sorted_genomes" | head -$ELITE_COUNT | while read fitness file; do
                cp "$file" "$elite_dir/"
            done
            
            # Создаём новое поколение
            local new_pop_dir="$work_dir/new_population"
            mkdir -p "$new_pop_dir"
            
            # Копируем элиту
            cp "$elite_dir"/*.json "$new_pop_dir/" 2>/dev/null || true
            
            # Генерируем остальных через кроссовер и мутацию
            local child_count=$((POPULATION_SIZE - ELITE_COUNT))
            for i in $(seq 1 $child_count); do
                # Турнирный отбор родителей
                local parent_a=$(ls "$population_dir"/*.json | shuf | head -1)
                local parent_b=$(ls "$population_dir"/*.json | shuf | head -1)
                
                local child_file="$new_pop_dir/child_$i.json"
                
                # Кроссовер
                if [ $(echo "$RANDOM % 100 < $CROSSOVER_RATE * 100" | bc) -eq 1 ]; then
                    crossover_genomes "$parent_a" "$parent_b" "$child_file"
                else
                    cp "$parent_a" "$child_file"
                fi
                
                # Мутация
                mutate_genome "$child_file" "$child_file"
            done
            
            # Заменяем популяцию
            rm -rf "$population_dir"
            mv "$new_pop_dir" "$population_dir"
            rm -rf "$elite_dir"
        fi
    done
    
    echo ""
    echo -e "${GREEN}═══ Эволюция завершена ═══${NC}"
    echo ""
    echo "Лучший fitness: $best_fitness"
    echo ""
    echo "Лучший геном:"
    echo "$best_genome" | jq '.'
    
    # Сохраняем лучший геном
    local output_file="$SCRIPT_DIR/best_genome.json"
    echo "$best_genome" > "$output_file"
    echo ""
    echo "Сохранено в: $output_file"
    
    # Очистка
    rm -rf "$work_dir"
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --population)
            POPULATION_SIZE="$2"
            shift 2
            ;;
        --generations)
            GENERATIONS="$2"
            shift 2
            ;;
        --mutation-rate)
            MUTATION_RATE="$2"
            shift 2
            ;;
        --target)
            TARGET="$2"
            shift 2
            ;;
        --optimize-for)
            OPTIMIZE_FOR="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --population N      Population size (default: 20)"
            echo "  --generations N     Number of generations (default: 50)"
            echo "  --mutation-rate R   Mutation rate 0-1 (default: 0.1)"
            echo "  --target T          Target: zig, rust, go, python, typescript"
            echo "  --optimize-for O    Optimize for: runtime, size, balanced"
            echo "  --help              Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Проверка зависимостей
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install with: brew install jq (macOS) or apt install jq (Linux)"
    exit 1
fi

if ! command -v bc &> /dev/null; then
    echo "Error: bc is required. Install with: apt install bc (Linux)"
    exit 1
fi

# Запуск
print_header
print_config
run_evolution
