ff() {
    local dir="${1:-/home/wupin/mylib}"
    
    # 检查目录是否存在
    if [[ ! -d "$dir" ]]; then
        echo "❌ Error: Directory does not exist: $dir" >&2
        return 1
    fi
    
    echo "🔍 Scanning .sh files in: $dir"
    echo "=================================="
    
    # 查找所有 .sh 文件并提取函数名
    find "$dir" -type f -name "*.sh" -print0 | while IFS= read -r -d '' file; do
        # 获取相对路径
        rel_path="${file#$dir/}"
        
        # 提取函数名（匹配 function name() 或 name() 格式）
        functions=$(grep -E '^\s*(function\s+)?[a-zA-Z_][a-zA-Z0-9_]*\s*\(\s*\)\s*\{?' "$file" | \
                   sed -E 's/^\s*(function\s+)?([a-zA-Z_][a-zA-Z0-9_]*)\s*\(\s*\)\s*\{?.*$/\2/')
        
        # 如果有函数，输出
        if [[ -n "$functions" ]]; then
            echo "📁 $rel_path"
            echo "$functions" | while IFS= read -r func; do
                echo "  └─ $func"
            done
            echo ""
        fi
    done
}

# ============================================
# Path Management Functions
# ============================================

# 确保目录和文件存在
ensure_paths_file() {
    local paths_file="$HOME/mylib/paths.sh"
    local paths_dir="$HOME/mylib"
    
    # 创建目录（如果不存在）
    if [[ ! -d "$paths_dir" ]]; then
        mkdir -p "$paths_dir"
    fi
    
    # 创建文件（如果不存在）
    if [[ ! -f "$paths_file" ]]; then
        cat > "$paths_file" << 'EOF'
#!/bin/bash
# ============================================
# Auto-generated path shortcuts
# Created: $(date)
# ============================================

EOF
    fi
}

addpath() {
    # 检查参数
    if [[ $# -lt 2 ]]; then
        echo "❌ Error: Missing arguments" >&2
        echo "Usage: addpath <name> <path>" >&2
        echo "Example: addpath project ~/myproject" >&2
        return 1
    fi
    
    local name="$1"
    local path="$2"
    local paths_file="$HOME/mylib/paths.sh"
    
    # 验证函数名（只允许字母、数字、下划线）
    if [[ ! "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo "❌ Error: Invalid function name. Use only letters, numbers, and underscore." >&2
        echo "   Name must start with letter or underscore" >&2
        return 1
    fi
    
    # 展开路径
    if [[ "$path" == "~"* ]]; then
        path="${path/#\~/$HOME}"
    fi
    path="$(realpath -s "$path" 2>/dev/null || echo "$path")"
    
    # 检查路径是否存在
    if [[ ! -d "$path" ]]; then
        echo "❌ Error: Directory does not exist: $path" >&2
        return 1
    fi
    
    # 确保文件存在
    ensure_paths_file
    
    # 检查是否已存在同名函数（适配无function关键字的格式）
    if grep -q "^$name()" "$paths_file" 2>/dev/null; then
        echo "⚠️  Warning: Function '$name' already exists" >&2
        read -p "Overwrite? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "❌ Cancelled" >&2
            return 1
        fi
        # 删除旧函数
        delpath "$name" >/dev/null 2>&1
    fi
    
    # 转换 Windows 路径（如果在 WSL 中）
    local win_path=""
    if command -v wslpath >/dev/null 2>&1; then
        win_path="$(wslpath -w "$path" 2>/dev/null || echo "")"
    fi
    
    # 添加新函数 - 移除 function 关键字
    {
        echo ""
        echo "# Added by addpath on $(date '+%Y-%m-%d %H:%M:%S')"
        echo "$name() {"
        echo "    echo \"🪟 Opening: $path\""
        echo "    echo \"   Path: $path\""
        if [[ -n "$win_path" ]]; then
            echo "    echo \"   Win:  $win_path\""
        fi
        echo "    echo \"📋 Path copied to clipboard\""
        echo "    echo -n \"$path\" | clip.exe 2>/dev/null || true"
        echo "    cd \"$path\" && echo \"📍 Now in: \$(pwd)\""
        echo "}"
        echo ""
    } >> "$paths_file"
    
    # 重新加载 paths.sh
    if [[ -f "$paths_file" ]]; then
        # 移除旧的 source 如果存在
        if grep -q "source.*mylib/paths.sh" "$HOME/.bashrc" 2>/dev/null || \
           grep -q "source.*mylib/paths.sh" "$HOME/.zshrc" 2>/dev/null; then
            : # 已存在，不做操作
        else
            # 添加到 shell 配置
            local shell_rc="$HOME/.bashrc"
            [[ -n "$ZSH_VERSION" ]] && shell_rc="$HOME/.zshrc"
            echo "" >> "$shell_rc"
            echo "# Load path shortcuts" >> "$shell_rc"
            echo "[[ -f \"$paths_file\" ]] && source \"$paths_file\"" >> "$shell_rc"
        fi
        
        # 立即加载
        source "$paths_file" 2>/dev/null || true
    fi
    
    echo "✅ Added path shortcut: $name"
    echo "   Path: $path"
    echo "   File: $paths_file"
    echo ""
    echo "💡 Use: $name     # to cd to this path"
    
    return 0
}
# 删除路径快捷方式
delpath() {
    # 检查参数
    if [[ $# -lt 1 ]]; then
        echo "❌ Error: Missing function name" >&2
        echo "Usage: delpath <name>" >&2
        echo "Example: delpath project" >&2
        echo ""
        echo "Available shortcuts:"
        listpath
        return 1
    fi
    
    local name="$1"
    local paths_file="$HOME/mylib/paths.sh"
    
    # 检查文件是否存在
    if [[ ! -f "$paths_file" ]]; then
        echo "❌ Error: No shortcuts file found" >&2
        return 1
    fi
    
    # 检查函数是否存在 - 只检查无function关键字的格式
    if ! grep -q "^$name()" "$paths_file" 2>/dev/null; then
        echo "❌ Error: Function '$name' not found" >&2
        echo ""
        echo "Available shortcuts:"
        listpath
        return 1
    fi
    
    # 创建备份
    local backup_file="$paths_file.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$paths_file" "$backup_file"
    
    # 删除函数及其注释
    # 匹配模式：
    # 1. 函数定义行
    # 2. 前面的注释行（以 # Added by addpath 开头）
    # 3. 后面的空行
    awk -v name="$name" '
    BEGIN { skip=0 }
    {
        if ($0 ~ "^# Added by addpath") {
            # 标记要跳过的注释行
            skip_comment=1
            comment=$0
            next
        }
        if (skip_comment) {
            if ($0 ~ "^" name "\\(\\)") {
                # 找到匹配的函数，跳过整块
                skip=1
                skip_comment=0
                next
            } else {
                # 不匹配，输出之前跳过的注释
                print comment
                skip_comment=0
            }
        }
        if (skip) {
            # 跳过函数体
            if ($0 ~ /^}$/ || $0 ~ /^[[:space:]]*}$/) {
                skip=0
                next
            }
            next
        }
        print $0
    }' "$paths_file" > "$paths_file.tmp"
    
    # 替换原文件
    mv "$paths_file.tmp" "$paths_file"
    
    # 重新加载
    if [[ -f "$paths_file" ]]; then
        source "$paths_file" 2>/dev/null || true
    fi
    
    echo "✅ Deleted path shortcut: $name"
    echo "   Backup saved: $(basename "$backup_file")"
    
    return 0
}

# 列出所有路径快捷方式 - 简化版
listpath() {
    local paths_file="$HOME/mylib/paths.sh"
    
    if [[ ! -f "$paths_file" ]]; then
        echo "📭 No path shortcuts found" >&2
        return 0
    fi
    
    echo "📌 Available path shortcuts:"
    echo "================================"
    
    local count=0
    
    # 使用 grep 和 sed 直接提取函数名和路径
    while IFS= read -r func_line; do
        # 提取函数名
        local func_name=$(echo "$func_line" | sed -E 's/^([a-zA-Z_][a-zA-Z0-9_]*)\(\).*$/\1/')
        
        # 提取对应的路径
        local path=$(sed -n "/^$func_name()/,/^}/p" "$paths_file" | grep -m1 'cd "' | sed -E 's/.*cd "([^"]+)".*/\1/')
        
        printf "  %-20s -> %s\n" "$func_name" "$path"
        ((count++))
    done < <(grep -E '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' "$paths_file")
    
    if [[ $count -eq 0 ]]; then
        echo "  (no shortcuts found)"
    else
        echo "================================"
        echo "  Total: $count shortcuts"
    fi
}