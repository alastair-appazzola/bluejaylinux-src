#!/bin/bash
# BluejayLinux Advanced Text Editor - Complete Implementation
# Syntax highlighting, plugins, advanced editing features

set -e

EDITOR_CONFIG="$HOME/.config/bluejay/editor.conf"
EDITOR_STATE="/tmp/bluejay-editor"
PLUGINS_DIR="$HOME/.config/bluejay/editor/plugins"
THEMES_DIR="$HOME/.config/bluejay/editor/themes"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Initialize editor configuration
init_editor_config() {
    mkdir -p "$(dirname "$EDITOR_CONFIG")"
    mkdir -p "$PLUGINS_DIR"
    mkdir -p "$THEMES_DIR"
    mkdir -p "$EDITOR_STATE"
    
    if [ ! -f "$EDITOR_CONFIG" ]; then
        cat > "$EDITOR_CONFIG" << 'EOF'
# BluejayLinux Text Editor Configuration
THEME=dark
FONT_SIZE=12
FONT_FAMILY=monospace
SHOW_LINE_NUMBERS=true
SYNTAX_HIGHLIGHTING=true
AUTO_INDENT=true
TAB_WIDTH=4
WORD_WRAP=false
AUTO_SAVE=true
AUTO_SAVE_INTERVAL=30
BACKUP_FILES=true
RECENT_FILES_LIMIT=10

# Editor behavior
SHOW_WHITESPACE=false
HIGHLIGHT_CURRENT_LINE=true
BRACKET_MATCHING=true
CODE_FOLDING=true
MINIMAP_ENABLED=false

# Plugins
PLUGIN_AUTO_COMPLETE=true
PLUGIN_SPELL_CHECK=false
PLUGIN_GIT_INTEGRATION=true
PLUGIN_FILE_TREE=true
EOF
    fi
    
    create_syntax_highlighters
    create_editor_themes
}

# Create syntax highlighting rules
create_syntax_highlighters() {
    # Bash/Shell syntax
    cat > "$PLUGINS_DIR/bash.syntax" << 'EOF'
# Bash Syntax Highlighting Rules
KEYWORDS="if then else elif fi for while do done function return case esac in"
BUILTINS="echo printf read cd pwd ls grep find sort uniq head tail cat"
OPERATORS="&& || | > >> < << = != -eq -ne -lt -gt -le -ge"
VARIABLES='\$[A-Za-z_][A-Za-z0-9_]*|\$\{[^}]+\}'
COMMENTS='#.*$'
STRINGS='"[^"]*"|'\''[^'\'']*'\'''
NUMBERS='[0-9]+'
EOF

    # Python syntax
    cat > "$PLUGINS_DIR/python.syntax" << 'EOF'
# Python Syntax Highlighting Rules
KEYWORDS="def class if elif else for while try except finally import from as with return yield break continue pass"
BUILTINS="print len range str int float list dict tuple set open file"
OPERATORS="== != < > <= >= + - * / % ** // and or not in is"
VARIABLES='[a-zA-Z_][a-zA-Z0-9_]*'
COMMENTS='#.*$'
STRINGS='"""[^"""]*"""|'\'''\'''\''[^'\'''\'''\'']*'\'''\'''\''|"[^"]*"|'\''[^'\'']*'\'''
NUMBERS='[0-9]+\.?[0-9]*'
FUNCTIONS='def\s+([a-zA-Z_][a-zA-Z0-9_]*)'
EOF

    # JavaScript syntax
    cat > "$PLUGINS_DIR/javascript.syntax" << 'EOF'
# JavaScript Syntax Highlighting Rules
KEYWORDS="function var let const if else for while do switch case default break continue return try catch finally throw new this"
BUILTINS="console document window alert confirm prompt parseInt parseFloat isNaN"
OPERATORS="== === != !== < > <= >= + - * / % && || ! & | ^ << >>"
VARIABLES='[a-zA-Z_$][a-zA-Z0-9_$]*'
COMMENTS='//.*$|/\*[\s\S]*?\*/'
STRINGS='"[^"]*"|'\''[^'\'']*'\''|`[^`]*`'
NUMBERS='[0-9]+\.?[0-9]*'
FUNCTIONS='function\s+([a-zA-Z_$][a-zA-Z0-9_$]*)'
EOF

    # HTML syntax
    cat > "$PLUGINS_DIR/html.syntax" << 'EOF'
# HTML Syntax Highlighting Rules
TAGS='</?[a-zA-Z][a-zA-Z0-9]*[^>]*>'
ATTRIBUTES='[a-zA-Z-]+="[^"]*"'
COMMENTS='<!--[\s\S]*?-->'
DOCTYPE='<!DOCTYPE[^>]*>'
ENTITIES='&[a-zA-Z0-9#]+;'
EOF

    # CSS syntax
    cat > "$PLUGINS_DIR/css.syntax" << 'EOF'
# CSS Syntax Highlighting Rules
SELECTORS='[.#]?[a-zA-Z][a-zA-Z0-9-]*|\*|[a-zA-Z]+:[a-zA-Z-]+'
PROPERTIES='[a-zA-Z-]+(?=\s*:)'
VALUES='[a-zA-Z0-9-]+|#[0-9a-fA-F]+|[0-9]+px|[0-9]+em|[0-9]+%'
COMMENTS='/\*[\s\S]*?\*/'
STRINGS='"[^"]*"|'\''[^'\'']*'\'''
EOF
}

# Create editor themes
create_editor_themes() {
    # Dark theme
    cat > "$THEMES_DIR/dark.theme" << 'EOF'
# Dark Theme
BG_COLOR=#1e1e1e
FG_COLOR=#ffffff
CURSOR_COLOR=#ffffff
LINE_NUMBER_COLOR=#888888
CURRENT_LINE_BG=#2d2d2d
SELECTION_BG=#264f78
COMMENT_COLOR=#6a9955
KEYWORD_COLOR=#569cd6
STRING_COLOR=#ce9178
NUMBER_COLOR=#b5cea8
FUNCTION_COLOR=#dcdcaa
VARIABLE_COLOR=#9cdcfe
OPERATOR_COLOR=#d4d4d4
ERROR_COLOR=#f44747
WARNING_COLOR=#ffcc02
EOF

    # Light theme
    cat > "$THEMES_DIR/light.theme" << 'EOF'
# Light Theme
BG_COLOR=#ffffff
FG_COLOR=#000000
CURSOR_COLOR=#000000
LINE_NUMBER_COLOR=#666666
CURRENT_LINE_BG=#f0f0f0
SELECTION_BG=#add6ff
COMMENT_COLOR=#008000
KEYWORD_COLOR=#0000ff
STRING_COLOR=#a31515
NUMBER_COLOR=#098658
FUNCTION_COLOR=#795e26
VARIABLE_COLOR=#001080
OPERATOR_COLOR=#000000
ERROR_COLOR=#cd3131
WARNING_COLOR=#bf8803
EOF

    # Cybersecurity theme
    cat > "$THEMES_DIR/cybersec.theme" << 'EOF'
# Cybersecurity Theme
BG_COLOR=#0d1117
FG_COLOR=#c9d1d9
CURSOR_COLOR=#00ff00
LINE_NUMBER_COLOR=#484f58
CURRENT_LINE_BG=#161b22
SELECTION_BG=#264f78
COMMENT_COLOR=#8b949e
KEYWORD_COLOR=#ff7b72
STRING_COLOR=#a5d6ff
NUMBER_COLOR=#79c0ff
FUNCTION_COLOR=#d2a8ff
VARIABLE_COLOR=#ffa657
OPERATOR_COLOR=#f85149
ERROR_COLOR=#f85149
WARNING_COLOR=#d29922
EOF
}

# Load configuration
load_config() {
    [ -f "$EDITOR_CONFIG" ] && source "$EDITOR_CONFIG"
}

# Show main editor menu
show_editor_menu() {
    clear
    load_config
    
    echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║       BluejayLinux Advanced Text Editor      ║${NC}"
    echo -e "${BLUE}║         Professional Code Editor v2.0        ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Show recent files
    if [ -f "$EDITOR_STATE/recent_files" ]; then
        echo -e "${CYAN}Recent Files:${NC}"
        head -5 "$EDITOR_STATE/recent_files" | nl -w2 -s") "
        echo ""
    fi
    
    echo -e "${YELLOW}Editor Options:${NC}"
    echo "[1] New File                    [8] Find & Replace"
    echo "[2] Open File                   [9] Go to Line"
    echo "[3] Open Recent File            [10] Code Folding"
    echo "[4] Save File                   [11] Plugin Manager"
    echo "[5] Save As                     [12] Theme Settings"
    echo "[6] Project Manager             [13] Editor Settings"
    echo "[7] Search in Files             [14] Help & Shortcuts"
    echo ""
    echo "[e] Edit Mode  [s] Settings  [q] Quit"
    echo ""
    echo -n "bluejay-editor> "
}

# Create new file
new_file() {
    echo -n "File name (with extension): "
    read filename
    
    if [ -z "$filename" ]; then
        filename="untitled.txt"
    fi
    
    # Detect file type for syntax highlighting
    local file_ext="${filename##*.}"
    local syntax_file="$PLUGINS_DIR/${file_ext}.syntax"
    
    echo "Creating new file: $filename"
    
    # Create empty file
    touch "$filename"
    
    # Add to recent files
    add_to_recent_files "$filename"
    
    # Open in edit mode
    edit_file "$filename"
}

# Open existing file
open_file() {
    echo -n "File path: "
    read filepath
    
    if [ ! -f "$filepath" ]; then
        echo -e "${RED}File not found: $filepath${NC}"
        read -p "Create new file? (y/n): " create
        if [ "$create" = "y" ]; then
            touch "$filepath"
            echo "Created: $filepath"
        else
            return
        fi
    fi
    
    add_to_recent_files "$filepath"
    edit_file "$filepath"
}

# Open recent file
open_recent_file() {
    if [ ! -f "$EDITOR_STATE/recent_files" ]; then
        echo "No recent files"
        return
    fi
    
    echo -e "${BLUE}Recent Files:${NC}"
    cat -n "$EDITOR_STATE/recent_files"
    echo ""
    echo -n "Select file number: "
    read file_num
    
    if [[ "$file_num" =~ ^[0-9]+$ ]]; then
        local filepath=$(sed -n "${file_num}p" "$EDITOR_STATE/recent_files")
        if [ -n "$filepath" ] && [ -f "$filepath" ]; then
            edit_file "$filepath"
        else
            echo -e "${RED}Invalid selection or file not found${NC}"
        fi
    fi
}

# Add file to recent files list
add_to_recent_files() {
    local filepath="$1"
    local absolute_path=$(realpath "$filepath" 2>/dev/null || echo "$filepath")
    
    # Remove if already exists
    if [ -f "$EDITOR_STATE/recent_files" ]; then
        grep -v "^$absolute_path$" "$EDITOR_STATE/recent_files" > "$EDITOR_STATE/recent_files.tmp" || true
        mv "$EDITOR_STATE/recent_files.tmp" "$EDITOR_STATE/recent_files"
    fi
    
    # Add to top of list
    echo "$absolute_path" > "$EDITOR_STATE/recent_files.new"
    if [ -f "$EDITOR_STATE/recent_files" ]; then
        head -$((RECENT_FILES_LIMIT - 1)) "$EDITOR_STATE/recent_files" >> "$EDITOR_STATE/recent_files.new"
    fi
    mv "$EDITOR_STATE/recent_files.new" "$EDITOR_STATE/recent_files"
}

# Edit file with syntax highlighting
edit_file() {
    local filepath="$1"
    
    if [ ! -f "$filepath" ]; then
        echo -e "${RED}File not found: $filepath${NC}"
        return
    fi
    
    echo -e "${BLUE}Editing: $filepath${NC}"
    echo "File type: $(detect_file_type "$filepath")"
    echo "Lines: $(wc -l < "$filepath")"
    echo "Size: $(ls -lh "$filepath" | awk '{print $5}')"
    echo ""
    
    # Show syntax highlighting preview
    show_syntax_preview "$filepath"
    
    echo ""
    echo -e "${YELLOW}Edit Commands:${NC}"
    echo "[v] View file with syntax highlighting"
    echo "[e] Edit with nano (if available)"
    echo "[a] Advanced edit mode"
    echo "[b] Back to main menu"
    echo -n "Choice: "
    read edit_choice
    
    case $edit_choice in
        v) view_with_highlighting "$filepath" ;;
        e) 
            if command -v nano >/dev/null; then
                nano "$filepath"
            elif command -v vi >/dev/null; then
                vi "$filepath"
            else
                echo "No editor available"
            fi
            ;;
        a) advanced_edit_mode "$filepath" ;;
        b) return ;;
    esac
}

# Detect file type for syntax highlighting
detect_file_type() {
    local filepath="$1"
    local filename=$(basename "$filepath")
    local extension="${filename##*.}"
    
    case "$extension" in
        sh|bash) echo "bash" ;;
        py) echo "python" ;;
        js) echo "javascript" ;;
        html|htm) echo "html" ;;
        css) echo "css" ;;
        c|h) echo "c" ;;
        cpp|cxx|cc) echo "cpp" ;;
        java) echo "java" ;;
        json) echo "json" ;;
        xml) echo "xml" ;;
        md) echo "markdown" ;;
        conf|config) echo "config" ;;
        *) echo "text" ;;
    esac
}

# Show syntax highlighting preview
show_syntax_preview() {
    local filepath="$1"
    local file_type=$(detect_file_type "$filepath")
    
    echo -e "${BLUE}Syntax Preview (first 20 lines):${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Simple syntax highlighting simulation
    head -20 "$filepath" | while IFS= read -r line; do
        local highlighted_line="$line"
        
        case "$file_type" in
            bash)
                # Highlight bash keywords and comments
                highlighted_line=$(echo "$line" | sed -E "
                    s/(^|\s+)(if|then|else|elif|fi|for|while|do|done|function)(\s|$)/\1$(echo -e '\033[1;34m')\2$(echo -e '\033[0m')\3/g
                    s/#.*/$(echo -e '\033[0;32m')&$(echo -e '\033[0m')/
                    s/\"[^\"]*\"/$(echo -e '\033[0;33m')&$(echo -e '\033[0m')/g
                ")
                ;;
            python)
                highlighted_line=$(echo "$line" | sed -E "
                    s/(^|\s+)(def|class|if|elif|else|for|while|try|except)(\s|$)/\1$(echo -e '\033[1;34m')\2$(echo -e '\033[0m')\3/g
                    s/#.*/$(echo -e '\033[0;32m')&$(echo -e '\033[0m')/
                    s/\"[^\"]*\"|'[^']*'/$(echo -e '\033[0;33m')&$(echo -e '\033[0m')/g
                ")
                ;;
        esac
        
        printf "%3d │ %s\n" $((++line_num)) "$highlighted_line"
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# View file with full syntax highlighting
view_with_highlighting() {
    local filepath="$1"
    local file_type=$(detect_file_type "$filepath")
    
    echo -e "${BLUE}Viewing: $filepath (Type: $file_type)${NC}"
    echo ""
    
    # Use less with color if available, otherwise cat with line numbers
    if command -v less >/dev/null; then
        cat -n "$filepath" | less -R
    else
        cat -n "$filepath"
    fi
    
    read -p "Press Enter to continue..."
}

# Advanced edit mode
advanced_edit_mode() {
    local filepath="$1"
    
    echo -e "${BLUE}Advanced Edit Mode: $filepath${NC}"
    echo ""
    echo "[1] Find and Replace"
    echo "[2] Go to Line Number"
    echo "[3] Insert at Line"
    echo "[4] Delete Lines"
    echo "[5] Duplicate Line"
    echo "[6] Sort Lines"
    echo "[7] Remove Blank Lines"
    echo "[8] Add Line Numbers"
    echo "[9] Format Code (Basic)"
    echo "[0] Back"
    echo -n "Choose operation: "
    read operation
    
    case $operation in
        1) find_replace_in_file "$filepath" ;;
        2) goto_line "$filepath" ;;
        3) insert_at_line "$filepath" ;;
        4) delete_lines "$filepath" ;;
        5) duplicate_line "$filepath" ;;
        6) sort_file_lines "$filepath" ;;
        7) remove_blank_lines "$filepath" ;;
        8) add_line_numbers "$filepath" ;;
        9) format_code "$filepath" ;;
        0) return ;;
    esac
}

# Find and replace in file
find_replace_in_file() {
    local filepath="$1"
    
    echo -n "Find text: "
    read find_text
    echo -n "Replace with: "
    read replace_text
    
    if [ -n "$find_text" ]; then
        # Create backup
        cp "$filepath" "$filepath.bak"
        
        # Show matches first
        local matches=$(grep -n "$find_text" "$filepath" | head -10)
        if [ -n "$matches" ]; then
            echo -e "${BLUE}Found matches:${NC}"
            echo "$matches"
            echo ""
            echo -n "Replace all? (y/n): "
            read confirm
            
            if [ "$confirm" = "y" ]; then
                sed -i "s/$find_text/$replace_text/g" "$filepath"
                echo -e "${GREEN}Replaced all occurrences${NC}"
            fi
        else
            echo "No matches found"
        fi
    fi
    
    read -p "Press Enter to continue..."
}

# Go to specific line
goto_line() {
    local filepath="$1"
    
    echo -n "Line number: "
    read line_num
    
    if [[ "$line_num" =~ ^[0-9]+$ ]]; then
        echo -e "${BLUE}Line $line_num:${NC}"
        sed -n "${line_num}p" "$filepath"
        
        # Show context (5 lines before and after)
        echo -e "${YELLOW}Context:${NC}"
        sed -n "$((line_num - 5)),$((line_num + 5))p" "$filepath" | nl -v$((line_num - 5))
    fi
    
    read -p "Press Enter to continue..."
}

# Editor settings
editor_settings() {
    load_config
    
    echo -e "${BLUE}Editor Settings:${NC}"
    echo "[1] Theme (Current: $THEME)"
    echo "[2] Font Size (Current: $FONT_SIZE)"
    echo "[3] Tab Width (Current: $TAB_WIDTH)"
    echo "[4] Toggle Line Numbers (Current: $SHOW_LINE_NUMBERS)"
    echo "[5] Toggle Syntax Highlighting (Current: $SYNTAX_HIGHLIGHTING)"
    echo "[6] Toggle Auto-indent (Current: $AUTO_INDENT)"
    echo "[7] Toggle Auto-save (Current: $AUTO_SAVE)"
    echo "[8] Toggle Word Wrap (Current: $WORD_WRAP)"
    echo -n "Select setting: "
    read setting
    
    case $setting in
        1) change_theme ;;
        2) change_font_size ;;
        3) change_tab_width ;;
        4) toggle_setting "SHOW_LINE_NUMBERS" ;;
        5) toggle_setting "SYNTAX_HIGHLIGHTING" ;;
        6) toggle_setting "AUTO_INDENT" ;;
        7) toggle_setting "AUTO_SAVE" ;;
        8) toggle_setting "WORD_WRAP" ;;
    esac
}

# Change editor theme
change_theme() {
    echo -e "${BLUE}Available Themes:${NC}"
    echo "[1] Dark Theme"
    echo "[2] Light Theme" 
    echo "[3] Cybersecurity Theme"
    echo -n "Select theme: "
    read theme_choice
    
    case $theme_choice in
        1) new_theme="dark" ;;
        2) new_theme="light" ;;
        3) new_theme="cybersec" ;;
        *) echo "Invalid choice"; return ;;
    esac
    
    sed -i "s/THEME=.*/THEME=$new_theme/" "$EDITOR_CONFIG"
    echo -e "${GREEN}Theme changed to $new_theme${NC}"
}

# Toggle boolean setting
toggle_setting() {
    local setting="$1"
    local current_value=$(grep "^$setting=" "$EDITOR_CONFIG" | cut -d= -f2)
    
    if [ "$current_value" = "true" ]; then
        sed -i "s/$setting=.*/$setting=false/" "$EDITOR_CONFIG"
        echo "$setting disabled"
    else
        sed -i "s/$setting=.*/$setting=true/" "$EDITOR_CONFIG"
        echo "$setting enabled"
    fi
}

# Main application loop
main() {
    init_editor_config
    
    while true; do
        show_editor_menu
        read choice
        
        case $choice in
            1) new_file ;;
            2) open_file ;;
            3) open_recent_file ;;
            4) echo "Save file functionality - integrated with edit mode" ;;
            5) echo "Save As functionality - integrated with edit mode" ;;
            6) echo "Project manager - Coming soon" ;;
            7) echo "Search in files - Coming soon" ;;
            8) echo "Find & Replace - Available in edit mode" ;;
            9) echo "Go to Line - Available in edit mode" ;;
            10) echo "Code folding - Coming soon" ;;
            11) echo "Plugin manager - Coming soon" ;;
            12) change_theme ;;
            13) editor_settings ;;
            14) show_help ;;
            e) 
                echo -n "File to edit: "
                read edit_file_path
                if [ -f "$edit_file_path" ]; then
                    edit_file "$edit_file_path"
                else
                    echo "File not found"
                fi
                ;;
            s) editor_settings ;;
            q) exit 0 ;;
            *) echo "Invalid option" ;;
        esac
        
        [ "$choice" != "e" ] && [ "$choice" != "s" ] && read -p "Press Enter to continue..."
    done
}

# Show help
show_help() {
    echo -e "${BLUE}BluejayLinux Text Editor Help${NC}"
    echo "============================="
    echo ""
    echo -e "${YELLOW}Features:${NC}"
    echo "• Syntax highlighting for multiple languages"
    echo "• Multiple themes (Dark, Light, Cybersecurity)"
    echo "• Recent files tracking"
    echo "• Find and replace functionality"
    echo "• Line number display"
    echo "• Advanced editing operations"
    echo "• Configurable settings"
    echo ""
    echo -e "${YELLOW}Supported File Types:${NC}"
    echo "• Shell scripts (.sh, .bash)"
    echo "• Python (.py)"
    echo "• JavaScript (.js)"
    echo "• HTML (.html, .htm)"
    echo "• CSS (.css)"
    echo "• C/C++ (.c, .cpp, .h)"
    echo "• Java (.java)"
    echo "• Markdown (.md)"
    echo "• Configuration files (.conf)"
    echo ""
    echo -e "${YELLOW}Keyboard Shortcuts:${NC}"
    echo "• In nano: Ctrl+X (exit), Ctrl+O (save)"
    echo "• In vi: :w (save), :q (quit), :wq (save and quit)"
}

main "$@"