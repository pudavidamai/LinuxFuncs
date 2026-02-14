# ================================================
# Bashrc Management Functions
# ================================================

# ------------------------------------------------
# Function: brc
# Description: Reload/Source .bashrc file
# Usage: brc [optional flags]
# Flags:
#   -v, --verbose    Show detailed output
#   -q, --quiet      Suppress output (default)
#   -c, --check      Check syntax before reloading
# ------------------------------------------------
rb() {
    local verbose=false
    local check_syntax=false
    local bashrc_path="$HOME/.bashrc"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                verbose=true
                shift
                ;;
            -q|--quiet)
                verbose=false
                shift
                ;;
            -c|--check)
                check_syntax=true
                shift
                ;;
            *)
                echo "❌ Error: Unknown option $1"
                echo "Usage: brc [-v|--verbose] [-q|--quiet] [-c|--check]"
                return 1
                ;;
        esac
    done
    
    # Check if .bashrc exists
    if [[ ! -f "$bashrc_path" ]]; then
        echo "❌ Error: .bashrc not found at $bashrc_path"
        return 1
    fi
    
    # Syntax check
    if [[ "$check_syntax" == true ]]; then
        if $verbose; then
            echo "🔍 Checking .bashrc syntax..."
        fi
        
        if bash -n "$bashrc_path"; then
            if $verbose; then
                echo "✅ Syntax check passed"
            fi
        else
            echo "❌ Syntax error in .bashrc"
            return 1
        fi
    fi
    
    # Reload .bashrc
    if source "$bashrc_path"; then
        if $verbose; then
            echo "✅ .bashrc reloaded successfully"
            echo "   File: $bashrc_path"
            echo "   Time: $(date '+%Y-%m-%d %H:%M:%S')"
        else
            echo "✅ .bashrc reloaded"
        fi
        return 0
    else
        echo "❌ Failed to reload .bashrc"
        return 1
    fi
}

# Alias
alias reload="brc"
alias refresh="brc"
alias brc-reload="brc"

# ------------------------------------------------
# Function: bre
# Description: Edit .bashrc file with preferred editor
# Usage: bre [editor] [line_number]
# Examples:
#   bre              - Edit with default editor
#   bre vim          - Edit with vim
#   bre code         - Edit with VS Code
#   bre nano 50      - Edit with nano, go to line 50
#   bre -b          - Create backup before editing
# ------------------------------------------------
eb() {
    local editor=""
    local line_number=""
    local create_backup=false
    local bashrc_path="$HOME/.bashrc"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -b|--backup)
                create_backup=true
                shift
                ;;
            -*)
                echo "❌ Error: Unknown option $1"
                echo "Usage: bre [-b|--backup] [editor] [line_number]"
                return 1
                ;;
            *)
                if [[ -z "$editor" ]]; then
                    # Check if argument is a line number
                    if [[ "$1" =~ ^[0-9]+$ ]]; then
                        line_number="$1"
                    else
                        editor="$1"
                    fi
                elif [[ -z "$line_number" ]] && [[ "$1" =~ ^[0-9]+$ ]]; then
                    line_number="$1"
                else
                    echo "❌ Error: Too many arguments"
                    return 1
                fi
                shift
                ;;
        esac
    done
    
    # Create backup if requested
    if [[ "$create_backup" == true ]]; then
        local backup_path="$HOME/.bashrc.backup.$(date +%Y%m%d_%H%M%S)"
        if cp "$bashrc_path" "$backup_path"; then
            echo "💾 Backup created: $backup_path"
        else
            echo "❌ Failed to create backup"
            return 1
        fi
    fi
    
    # Determine editor to use
    if [[ -z "$editor" ]]; then
        # Try to find available editor in order of preference
        if command -v code &> /dev/null; then
            editor="code"
        elif command -v vim &> /dev/null; then
            editor="vim"
        elif command -v nano &> /dev/null; then
            editor="nano"
        elif command -v emacs &> /dev/null; then
            editor="emacs"
        elif [[ -n "$EDITOR" ]]; then
            editor="$EDITOR"
        elif [[ -n "$VISUAL" ]]; then
            editor="$VISUAL"
        else
            editor="vi"  # Fallback
        fi
    fi
    
    # Check if editor exists
    if ! command -v "$editor" &> /dev/null; then
        echo "❌ Error: Editor '$editor' not found"
        return 1
    fi
    
    echo "✏️  Opening .bashrc with $editor"
    
    # Open with line number if specified
    case "$editor" in
        code|code-insiders)
            if [[ -n "$line_number" ]]; then
                "$editor" --goto "$bashrc_path:$line_number"
            else
                "$editor" "$bashrc_path"
            fi
            ;;
        vim|gvim|nvim)
            if [[ -n "$line_number" ]]; then
                "$editor" "+$line_number" "$bashrc_path"
            else
                "$editor" "$bashrc_path"
            fi
            ;;
        nano)
            if [[ -n "$line_number" ]]; then
                "$editor" +"$line_number" "$bashrc_path"
            else
                "$editor" "$bashrc_path"
            fi
            ;;
        emacs)
            if [[ -n "$line_number" ]]; then
                "$editor" +"$line_number" "$bashrc_path"
            else
                "$editor" "$bashrc_path"
            fi
            ;;
        *)
            if [[ -n "$line_number" ]]; then
                echo "⚠️  Warning: Line number not supported with $editor"
            fi
            "$editor" "$bashrc_path"
            ;;
    esac
    
    # Ask to reload after editing
    echo ""
    read -p "🔄 Reload .bashrc now? [Y/n] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        brc
    fi
}


# ------------------------------------------------
# Function: brv
# Description: View .bashrc content with various formats
# Usage: brv [options]
# Options:
#   -c, --cat        Simple cat output (default)
#   -l, --less       View with less pager
#   -h, --head       Show first N lines (default: 20)
#   -t, --tail       Show last N lines (default: 20)
#   -g, --grep       Search pattern
#   -n, --number     Show line numbers
#   -f, --functions  Show only function definitions
#   -a, --aliases    Show only alias definitions
#   -e, --exports    Show only export statements
#   -s, --size       Show file size and info
#   --help           Show this help
# ------------------------------------------------
vb() {
    local bashrc_path="$HOME/.bashrc"
    local mode="cat"
    local lines=20
    local pattern=""
    local show_numbers=false
    local filter=""
    
    # Check if .bashrc exists
    if [[ ! -f "$bashrc_path" ]]; then
        echo "❌ Error: .bashrc not found at $bashrc_path"
        return 1
    fi
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--cat)
                mode="cat"
                shift
                ;;
            -l|--less)
                mode="less"
                shift
                ;;
            -h|--head)
                mode="head"
                if [[ "$2" =~ ^[0-9]+$ ]]; then
                    lines="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            -t|--tail)
                mode="tail"
                if [[ "$2" =~ ^[0-9]+$ ]]; then
                    lines="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            -g|--grep)
                mode="grep"
                pattern="$2"
                if [[ -z "$pattern" ]]; then
                    echo "❌ Error: Search pattern required"
                    return 1
                fi
                shift 2
                ;;
            -n|--number)
                show_numbers=true
                shift
                ;;
            -f|--functions)
                filter="functions"
                shift
                ;;
            -a|--aliases)
                filter="aliases"
                shift
                ;;
            -e|--exports)
                filter="exports"
                shift
                ;;
            -s|--size)
                mode="size"
                shift
                ;;
            --help)
                echo "Usage: brv [OPTIONS]"
                echo "View .bashrc content"
                echo ""
                echo "Options:"
                echo "  -c, --cat        Simple cat output (default)"
                echo "  -l, --less       View with less pager"
                echo "  -h, --head [N]   Show first N lines (default: 20)"
                echo "  -t, --tail [N]   Show last N lines (default: 20)"
                echo "  -g, --grep PAT   Search for pattern"
                echo "  -n, --number     Show line numbers"
                echo "  -f, --functions  Show only functions"
                echo "  -a, --aliases    Show only aliases"
                echo "  -e, --exports    Show only exports"
                echo "  -s, --size       Show file info"
                echo "  --help           Show this help"
                return 0
                ;;
            *)
                echo "❌ Error: Unknown option $1"
                echo "Use --help for usage information"
                return 1
                ;;
        esac
    done
    
    # Apply filter
    local filter_cmd="cat"
    case "$filter" in
        functions)
            filter_cmd="grep '^[[:space:]]*function' -A 2"
            echo "🔍 Showing function definitions:"
            echo "----------------------------------------"
            ;;
        aliases)
            filter_cmd="grep '^[[:space:]]*alias'"
            echo "🔍 Showing alias definitions:"
            echo "----------------------------------------"
            ;;
        exports)
            filter_cmd="grep '^[[:space:]]*export'"
            echo "🔍 Showing export statements:"
            echo "----------------------------------------"
            ;;
    esac
    
    # Add line numbers if requested
    local number_cmd="cat"
    if [[ "$show_numbers" == true ]] && [[ "$mode" != "less" ]]; then
        number_cmd="cat -n"
    fi
    
    # Execute based on mode
    case "$mode" in
        cat)
            eval "$filter_cmd '$bashrc_path' | $number_cmd"
            ;;
        less)
            if [[ "$show_numbers" == true ]]; then
                eval "$filter_cmd '$bashrc_path' | cat -n | less -R"
            else
                eval "$filter_cmd '$bashrc_path' | less -R"
            fi
            ;;
        head)
            echo "📋 First $lines lines of .bashrc:"
            echo "----------------------------------------"
            eval "$filter_cmd '$bashrc_path' | head -n $lines | $number_cmd"
            ;;
        tail)
            echo "📋 Last $lines lines of .bashrc:"
            echo "----------------------------------------"
            eval "$filter_cmd '$bashrc_path' | tail -n $lines | $number_cmd"
            ;;
        grep)
            echo "🔍 Searching for: \"$pattern\""
            echo "----------------------------------------"
            eval "$filter_cmd '$bashrc_path' | grep --color=always -n '$pattern'"
            ;;
        size)
            local lines_total=$(wc -l < "$bashrc_path")
            local words_total=$(wc -w < "$bashrc_path")
            local chars_total=$(wc -m < "$bashrc_path")
            local size_bytes=$(wc -c < "$bashrc_path")
            local functions_count=$(grep -c '^[[:space:]]*function' "$bashrc_path" 2>/dev/null || echo 0)
            local aliases_count=$(grep -c '^[[:space:]]*alias' "$bashrc_path" 2>/dev/null || echo 0)
            local exports_count=$(grep -c '^[[:space:]]*export' "$bashrc_path" 2>/dev/null || echo 0)
            
            echo "📊 .bashrc Statistics:"
            echo "----------------------------------------"
            echo "File:        $bashrc_path"
            echo "Size:        $size_bytes bytes"
            echo "Lines:       $lines_total"
            echo "Words:       $words_total"
            echo "Characters:  $chars_total"
            echo ""
            echo "Functions:   $functions_count"
            echo "Aliases:     $aliases_count"
            echo "Exports:     $exports_count"
            echo ""
            echo "Modified:    $(date -r "$bashrc_path" '+%Y-%m-%d %H:%M:%S')"
            ;;
    esac
}

gitlab_()
{
git config --global user.email "ping.wu@bsci.com"
git config --global user.name "Ping Wu"
git config --global user.email
git config --global user.name

}

github_()
{
   git config --global user.email "pudavidamai@gmail.com"
git config --global user.name "Pudavidamai"
git config --global user.email
git config --global user.name
 
}

devops_()
{
git config --global user.email "Ping@adminbscdv.onmicrosoft.com"
git config --global user.name "Ping Wu"
git config --global user.email
git config --global user.name

}

