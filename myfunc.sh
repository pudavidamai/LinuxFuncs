pushprofile()
{
   github_
   cd ~/mylib
   git add .
   git commit -m "add more funtions"
   git push
}



wpath() {
    local path="$1"
    local format="default"
    local copy_to_clipboard=true
    local wsl_distro="Ubuntu"  # 默认发行版
    
    # 解析选项
    while [ $# -gt 0 ]; do
        case "$1" in
            -c|--c-style) 
                format="c"
                shift
                ;;
            -u|--url) 
                format="u"
                shift
                ;;
            -q|--quoted) 
                format="q"
                shift
                ;;
            -d|--drive) 
                format="d"
                shift
                ;;
            -n|--no-copy)
                copy_to_clipboard=false
                shift
                ;;
            -h|--help)
                # ... 帮助信息保持不变 ...
                return 0
                ;;
            *)
                path="$1"
                shift
                ;;
        esac
    done
    
    # 如果没有提供路径，使用当前目录
    if [ -z "$path" ]; then
        path="$(pwd)"
    fi
    
    # 处理 ~/ 路径
    if [[ "$path" == "~"* ]]; then
        path="${path/#\~/$HOME}"
    fi
    
    # 处理相对路径
    if [[ "$path" != /* ]]; then
        path="$(pwd)/$path"
    fi
    
    # 规范化路径
    path="$(realpath -s "$path" 2>/dev/null || echo "$path")"
    
    local win_path=""
    
    # 检查是否已经是 Windows 路径格式
    if [[ "$path" == /mnt/* ]]; then
        # 转换 /mnt/c/Users/... 为 C:\Users\...
        local drive_letter="${path:5:1}"
        local rest_path="${path:7}"
        # 确保只有一个反斜杠
        win_path="${drive_letter^}:\\${rest_path//\//\\}"
        
    elif [[ "$path" == /home/* ]]; then
        # 转换 WSL 主目录到网络路径
        local username="${path#/home/}"
        username="${username%%/*}"
        local home_path="${path#/home/$username}"
        
        # 构建基本路径
        win_path="\\\\wsl$\\${wsl_distro}\\home\\${username}"
        
        # 添加剩余路径，避免多余的反斜杠
        if [[ -n "$home_path" ]] && [[ "$home_path" != "/" ]]; then
            # 去掉开头的斜杠，并将剩余斜杠替换为反斜杠
            home_path="${home_path#/}"
            win_path="${win_path}\\${home_path//\//\\}"
        fi
        
    elif [[ "$path" == /usr/* ]] || [[ "$path" == /etc/* ]] || [[ "$path" == /var/* ]]; then
        # 系统路径
        local sys_path="${path#/}"
        win_path="\\\\wsl$\\${wsl_distro}\\${sys_path//\//\\}"
        
    elif [[ "$path" == \\\\* ]]; then
        # 已经是 Windows 网络路径，规范化反斜杠
        win_path="$path"
        
    elif [[ "$path" =~ ^[A-Za-z]: ]]; then
        # 已经是 Windows 驱动器路径
        win_path="${path//\//\\}"
        
    else
        # 其他 Linux 路径
        local other_path="${path#/}"
        if [[ -z "$other_path" ]]; then
            # 根目录
            win_path="\\\\wsl$\\${wsl_distro}"
        else
            win_path="\\\\wsl$\\${wsl_distro}\\${other_path//\//\\}"
        fi
    fi
    
    # 规范化：确保路径中不会有多余的连续反斜杠
    # 但保留开头的双反斜杠（网络路径）
    win_path=$(echo "$win_path" | sed -E 's/([^\\])\\+/\1\\/g')
    
    # 根据格式选项调整输出
    local output=""
    case "$format" in
        c)
            # C语言风格 - 直接输出，但确保反斜杠被正确转义
            # 使用 printf %q 来确保反斜杠被正确转义
            output="$win_path"
            ;;
        u)
            # URL风格（正斜杠）
            # 将反斜杠转换为正斜杠，同时处理开头的双反斜杠
            output="${win_path//\\\\/\/}"
            # 确保开头的双斜杠被保留
            if [[ "$output" =~ ^// ]]; then
                output="/${output}"
            fi
            ;;
        q)
            # 带引号的路径
            output="\"$win_path\""
            ;;
        d)
            # 只显示驱动器号
            if [[ "$path" == /mnt/* ]]; then
                output="${path:5:1}:"
            elif [[ "$win_path" =~ ^[A-Za-z]: ]]; then
                output="${win_path:0:2}"
            else
                output="\\\\wsl$\\${wsl_distro}"
            fi
            ;;
        *)
            # 默认格式
            output="$win_path"
            ;;
    esac
    
    # 输出路径到标准错误（用于显示）
    echo "$output" >&2
    
    # 复制到剪贴板
    if [[ "$copy_to_clipboard" == true ]]; then
        local copy_success=false
        
        # 方法 1: 使用 clip.exe (Windows)
        if echo -n "$output" | clip.exe 2>/dev/null; then
            echo "📋 已复制到 Windows 剪贴板" >&2
            copy_success=true
        
        # 方法 2: 使用 powershell.exe
        elif echo -n "$output" | powershell.exe -Command "Set-Clipboard -Value \"$output\"" 2>/dev/null; then
            echo "📋 已复制到 Windows 剪贴板 (PowerShell)" >&2
            copy_success=true
        
        # 方法 3: 使用 xclip
        elif command -v xclip >/dev/null 2>&1; then
            echo -n "$output" | xclip -selection clipboard
            echo "📋 已复制到 X11 剪贴板" >&2
            copy_success=true
        
        else
            echo "⚠️  警告: 无法复制到剪贴板" >&2
        fi
    fi
    
    # 返回路径（用于脚本）- 输出到标准输出
    echo -n "$output"
}

# ================================================
# lpath - Output current WSL Linux path and copy to clipboard
# ================================================

lpath() {
    local path=""
    local copy_to_clipboard=true
    local quiet_mode=false
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--no-copy)
                copy_to_clipboard=false
                shift
                ;;
            -q|--quiet)
                quiet_mode=true
                shift
                ;;
            -h|--help)
                echo "Usage: lpath [OPTIONS] [path]"
                echo ""
                echo "Output current WSL Linux path and copy to clipboard"
                echo ""
                echo "Options:"
                echo "  -n, --no-copy     Don't copy to clipboard"
                echo "  -q, --quiet       Quiet mode (no status messages)"
                echo "  -h, --help        Show this help"
                echo ""
                echo "Examples:"
                echo "  lpath              # Output current directory path"
                echo "  lpath ~/projects   # Output specified path"
                echo "  lpath /etc/nginx   # Output system path"
                echo "  lpath -n           # Output only, no copy"
                return 0
                ;;
            *)
                path="$1"
                shift
                ;;
        esac
    done
    
    # If no path provided, use current directory
    if [[ -z "$path" ]]; then
        path="$(pwd)"
    else
        # Expand ~ to home directory
        if [[ "$path" == "~"* ]]; then
            path="${path/#\~/$HOME}"
        fi
        # Convert relative path to absolute path
        if [[ "$path" != /* ]]; then
            path="$(pwd)/$path"
        fi
    fi
    
    # Normalize path (remove /./ and /../)
    if command -v realpath >/dev/null 2>&1; then
        path="$(realpath -s "$path" 2>/dev/null || echo "$path")"
    fi
    
    # Clean up path (remove trailing slash)
    path="$(echo "$path" | sed -e 's|/*$||')"
    
    # OUTPUT: Only the Linux path (stdout)
    echo "$path"
    
    # COPY to clipboard (stderr messages)
    if [[ "$copy_to_clipboard" == true ]]; then
        local copy_success=false
        
        # Method 1: xclip (X11 clipboard) - Best for WSL
        if command -v xclip >/dev/null 2>&1; then
            echo -n "$path" | xclip -selection clipboard
            copy_success=true
            [[ "$quiet_mode" == false ]] && echo "📋 Copied to clipboard (xclip)" >&2
        
        # Method 2: xsel (alternative for X11)
        elif command -v xsel >/dev/null 2>&1; then
            echo -n "$path" | xsel --clipboard
            copy_success=true
            [[ "$quiet_mode" == false ]] && echo "📋 Copied to clipboard (xsel)" >&2
        
        # Method 3: clip.exe (Windows clipboard) - Fallback
        elif echo -n "$path" | clip.exe 2>/dev/null; then
            copy_success=true
            [[ "$quiet_mode" == false ]] && echo "📋 Copied to Windows clipboard (clip.exe)" >&2
        
        # Method 4: PowerShell (Windows clipboard) - Last resort
        elif echo -n "$path" | powershell.exe -Command "Set-Clipboard -Value '"'"'$(cat)'"'"'" 2>/dev/null; then
            copy_success=true
            [[ "$quiet_mode" == false ]] && echo "📋 Copied to Windows clipboard (PowerShell)" >&2
        
        else
            [[ "$quiet_mode" == false ]] && echo "⚠️  Warning: No clipboard tool found. Install xclip:" >&2
            [[ "$quiet_mode" == false ]] && echo "   sudo apt install xclip" >&2
        fi
        
        # Show path preview if copy was successful
        if [[ "$copy_success" == true ]] && [[ "$quiet_mode" == false ]]; then
            echo "   $path" >&2
        fi
    fi
}

# 在 WSL 中打开 Windows 资源管理器 - 完美修复版
opath() {
    local path="$1"
    local quiet_mode=false
    local copy_to_clipboard=true
    local file_select=false
    local vscode_mode=false
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--no-copy)
                copy_to_clipboard=false
                shift
                ;;
            -q|--quiet)
                quiet_mode=true
                shift
                ;;
            -s|--select)
                file_select=true
                shift
                ;;
            -vs|--vscode)
                vscode_mode=true
                shift
                ;;
            -h|--help)
                echo "Usage: opath [OPTIONS] [WSL path]"
                echo ""
                echo "Open WSL path in Windows Explorer (default) or VSCode (-vs)"
                echo ""
                echo "Options:"
                echo "  -vs, --vscode     Open in VSCode (WSL extension)"
                echo "  -s, --select      Select the item in Explorer (highlight it)"
                echo "  -n, --no-copy     Don't copy path to clipboard"
                echo "  -q, --quiet       Quiet mode (no status messages)"
                echo "  -h, --help        Show this help"
                echo ""
                echo "Examples:"
                echo "  opath                     # Open current dir in Explorer"
                echo "  opath -vs                 # Open current dir in VSCode"
                echo "  opath -vs ~/projects      # Open ~/projects in VSCode"
                return 0
                ;;
            *)
                path="$1"
                shift
                ;;
        esac
    done
    
    # 如果没有提供路径，使用当前目录
    if [[ -z "$path" ]]; then
        path="$(pwd)"
    else
        # 处理 ~ 展开
        if [[ "$path" == "~"* ]]; then
            path="${path/#\~/$HOME}"
        fi
        # 处理相对路径
        if [[ "$path" != /* ]]; then
            path="$(pwd)/$path"
        fi
    fi
    
    # 规范化路径
    if command -v realpath >/dev/null 2>&1; then
        path="$(realpath -s "$path" 2>/dev/null || echo "$path")"
    fi
    
    # 检查路径是否存在
    if [[ ! -e "$path" ]]; then
        echo "❌ Error: Path does not exist: $path" >&2
        return 1
    fi
    
    # ============== VSCode 模式 ==============
    if [[ "$vscode_mode" == true ]]; then
        # 使用 code 命令在 WSL 中打开
        if command -v code >/dev/null 2>&1; then
            # 如果是文件，直接打开文件；如果是目录，打开目录
            if [[ -f "$path" ]]; then
                code "$path"
            else
                code "$path"
            fi
            [[ "$quiet_mode" == false ]] && echo "📝 Opened in VSCode (WSL): $path" >&2
            
            # 复制 WSL 路径到剪贴板
            if [[ "$copy_to_clipboard" == true ]]; then
                if echo -n "$path" | clip.exe 2>/dev/null; then
                    [[ "$quiet_mode" == false ]] && echo "📋 Copied WSL path to Windows clipboard" >&2
                fi
            fi
            return 0
        else
            echo "❌ Error: VSCode 'code' command not found" >&2
            echo "   Please install VSCode and add 'code' to PATH:" >&2
            echo "   In VSCode: Ctrl+Shift+P → 'Install code command in PATH'" >&2
            return 1
        fi
    fi
    
    # ============== Explorer 模式（原有逻辑）==============
    # 转换为 Windows 路径
    local win_path=""
    
    # 方法 1: wslpath
    if command -v wslpath >/dev/null 2>&1; then
        win_path="$(wslpath -w "$path" 2>/dev/null)"
    fi
    
    # 方法 2: /mnt/* 路径手动转换
    if [[ -z "$win_path" ]] && [[ "$path" == /mnt/* ]]; then
        local drive_letter="${path:5:1}"
        local rest_path="${path:7}"
        drive_letter="${drive_letter^^}"
        win_path="${drive_letter}:\\${rest_path//\//\\}"
    fi
    
    # 方法 3: WSL 网络路径
    if [[ -z "$win_path" ]]; then
        local wsl_distro="${WSL_DISTRO_NAME:-Ubuntu}"
        if [[ -f /etc/wsl.conf ]]; then
            wsl_distro="$(grep -i "^distributionname" /etc/wsl.conf 2>/dev/null | cut -d= -f2 | tr -d ' ' || echo "${WSL_DISTRO_NAME:-Ubuntu}")"
        fi
        win_path="\\\\wsl.localhost\\${wsl_distro}${path//\//\\}"
    fi
    
    # 调试输出
    if [[ "${OPATH_DEBUG:-0}" == "1" ]]; then
        echo "🔍 Debug: WSL path = $path" >&2
        echo "🔍 Debug: WIN path = $win_path" >&2
    fi
    
    # ============== Explorer 打开逻辑 ==============
    if [[ -n "$win_path" ]]; then
        local open_success=false
        
        # 如果使用了 -s/--select 参数
        if [[ "$file_select" == true ]]; then
            # 使用 explorer /select, 需要批处理文件来处理
            local temp_bat="$(mktemp --suffix=.bat)"
            cat > "$temp_bat" << EOF
@echo off
explorer /select,"$win_path"
EOF
            if cmd.exe /c "$(wslpath -w "$temp_bat" 2>/dev/null)" 2>/dev/null; then
                open_success=true
                [[ "$quiet_mode" == false ]] && echo "🔍 Selected in Windows Explorer" >&2
            fi
            rm -f "$temp_bat"
        else
            # 普通打开 - 创建临时批处理文件（最可靠的方法）
            local temp_bat="$(mktemp --suffix=.bat)"
            cat > "$temp_bat" << EOF
@echo off
start "" "$win_path"
EOF
            
            # 执行批处理文件
            if cmd.exe /c "$(wslpath -w "$temp_bat" 2>/dev/null)" 2>/dev/null; then
                open_success=true
                [[ "$quiet_mode" == false ]] && echo "🪟 Opened in Windows Explorer" >&2
            fi
            
            # 删除临时文件
            rm -f "$temp_bat"
            
            # 如果批处理文件方法失败，回退到其他方法
            if [[ "$open_success" == false ]]; then
                # 方法2: explorer.exe 直接打开
                if explorer.exe "$win_path" 2>/dev/null; then
                    open_success=true
                    [[ "$quiet_mode" == false ]] && echo "🪟 Opened in Windows Explorer" >&2
                # 方法3: cmd /c start 带转义
                else
                    local escaped_path="${win_path//\\/\\\\}"
                    if cmd.exe /c "start \"\" \"$escaped_path\"" 2>/dev/null; then
                        open_success=true
                        [[ "$quiet_mode" == false ]] && echo "🪟 Opened in Windows Explorer" >&2
                    fi
                fi
            fi
        fi
        
        # 如果都失败了，报错
        if [[ "$open_success" == false ]]; then
            echo "❌ Error: Failed to open in Explorer" >&2
            echo "   Path: $win_path" >&2
            return 1
        fi
        
        [[ "$quiet_mode" == false ]] && echo "   $win_path" >&2
    else
        echo "❌ Error: Failed to convert path" >&2
        return 1
    fi
    
    # 复制到剪贴板
    if [[ "$copy_to_clipboard" == true ]]; then
        if echo -n "$win_path" | clip.exe 2>/dev/null; then
            [[ "$quiet_mode" == false ]] && echo "📋 Copied to Windows clipboard" >&2
        elif command -v xclip >/dev/null 2>&1; then
            echo -n "$win_path" | xclip -selection clipboard
            [[ "$quiet_mode" == false ]] && echo "📋 Copied to clipboard (xclip)" >&2
        fi
    fi
}
