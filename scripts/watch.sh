#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# FILE WATCHER - Auto-regenerate .999 on .vibee changes
# ═══════════════════════════════════════════════════════════════

SPECS_DIR="/workspaces/vibee-lang/specs/999"
SCRIPTS_DIR="/workspaces/vibee-lang/scripts"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  999 FILE WATCHER                                                 ║"
echo "║  Watching specs/999/*.vibee for changes...                        ║"
echo "║  Press Ctrl+C to stop                                             ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Check if inotifywait is available
if command -v inotifywait &> /dev/null; then
    # Use inotifywait for efficient watching
    while true; do
        changed_file=$(inotifywait -q -e modify,create --format '%w%f' -r "$SPECS_DIR" 2>/dev/null)
        if [[ "$changed_file" == *.vibee ]]; then
            echo ""
            echo "═══════════════════════════════════════════════════════════════"
            echo "📝 Changed: $changed_file"
            echo "═══════════════════════════════════════════════════════════════"
            
            # Regenerate single file
            relative_path="${changed_file#$SPECS_DIR/}"
            output_file="/workspaces/vibee-lang/999/${relative_path%.vibee}.999"
            
            bash "$SCRIPTS_DIR/vibee2nine_v3.sh" "$changed_file" "$output_file"
            
            echo ""
            echo "✅ Regenerated: $output_file"
            echo "⏳ Waiting for changes..."
        fi
    done
else
    # Fallback: poll-based watching
    echo "⚠️  inotifywait not found, using poll-based watching (slower)"
    echo ""
    
    declare -A file_times
    
    # Initial scan
    while IFS= read -r -d '' file; do
        file_times["$file"]=$(stat -c %Y "$file" 2>/dev/null || echo 0)
    done < <(find "$SPECS_DIR" -name "*.vibee" -print0)
    
    while true; do
        sleep 2
        
        while IFS= read -r -d '' file; do
            current_time=$(stat -c %Y "$file" 2>/dev/null || echo 0)
            prev_time=${file_times["$file"]:-0}
            
            if [ "$current_time" != "$prev_time" ]; then
                echo ""
                echo "═══════════════════════════════════════════════════════════════"
                echo "📝 Changed: $file"
                echo "═══════════════════════════════════════════════════════════════"
                
                relative_path="${file#$SPECS_DIR/}"
                output_file="/workspaces/vibee-lang/999/${relative_path%.vibee}.999"
                
                bash "$SCRIPTS_DIR/vibee2nine_v3.sh" "$file" "$output_file"
                
                file_times["$file"]=$current_time
                echo "✅ Regenerated: $output_file"
            fi
        done < <(find "$SPECS_DIR" -name "*.vibee" -print0)
    done
fi
