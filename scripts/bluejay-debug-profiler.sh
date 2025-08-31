#!/bin/bash

# BluejayLinux - System Debugging & Profiling Tools
# Advanced debugging, profiling, and system analysis capabilities

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/bluejay"
DEBUG_CONFIG_DIR="$CONFIG_DIR/debugger"
PROFILES_DIR="$DEBUG_CONFIG_DIR/profiles"
LOGS_DIR="$DEBUG_CONFIG_DIR/logs"
CORE_DUMPS_DIR="$DEBUG_CONFIG_DIR/core_dumps"

# Color scheme
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'

# Debugging tools and profilers
DEBUG_TOOLS="gdb lldb strace ltrace valgrind"
PROFILERS="perf gprof callgrind cachegrind massif helgrind"
ANALYSIS_TOOLS="objdump nm readelf ldd file hexdump"

# Initialize directories
create_directories() {
    mkdir -p "$CONFIG_DIR" "$DEBUG_CONFIG_DIR" "$PROFILES_DIR" "$LOGS_DIR" "$CORE_DUMPS_DIR"
    chmod 700 "$CORE_DUMPS_DIR"
    
    # Create default debug configuration
    if [ ! -f "$DEBUG_CONFIG_DIR/settings.conf" ]; then
        cat > "$DEBUG_CONFIG_DIR/settings.conf" << 'EOF'
# BluejayLinux Debug & Profiler Settings
DEFAULT_DEBUGGER=gdb
ENABLE_CORE_DUMPS=true
CORE_DUMP_PATTERN=/tmp/core.%e.%p
MAX_CORE_DUMPS=10
AUTO_STRIP_SYMBOLS=false
DEBUG_INFO_LEVEL=g3
PROFILER_OUTPUT_FORMAT=text
ENABLE_PERFORMANCE_COUNTERS=true
SAMPLING_FREQUENCY=1000
CALL_GRAPH_DEPTH=16
MEMORY_PROFILING=true
THREAD_ANALYSIS=true
SECURITY_ANALYSIS=true
STATIC_ANALYSIS=false
DYNAMIC_ANALYSIS=true
ENABLE_LOGGING=true
LOG_LEVEL=info
AUTO_SYMBOLICATION=true
REMOTE_DEBUGGING=false
GDB_HISTORY_SIZE=1000
BREAKPOINT_AUTO_SAVE=true
EOF
    fi
    
    # Initialize debugging tools database
    touch "$DEBUG_CONFIG_DIR/debug_tools.db"
}

# Load settings
load_settings() {
    if [ -f "$DEBUG_CONFIG_DIR/settings.conf" ]; then
        source "$DEBUG_CONFIG_DIR/settings.conf"
    fi
}

# Detect debugging and profiling tools
detect_debug_tools() {
    echo -e "${BLUE}Detecting debugging and profiling tools...${NC}"
    
    local available_tools=()
    local missing_tools=()
    
    # Core debugging tools
    echo -e "${CYAN}Debuggers:${NC}"
    
    if command -v gdb >/dev/null; then
        local gdb_version=$(gdb --version | head -1 | grep -o '[0-9]\+\.[0-9]\+')
        available_tools+=("gdb:$gdb_version")
        echo -e "${GREEN}✓${NC} GDB: $gdb_version"
    else
        missing_tools+=("gdb")
    fi
    
    if command -v lldb >/dev/null; then
        local lldb_version=$(lldb --version | head -1 | cut -d' ' -f3)
        available_tools+=("lldb:$lldb_version")
        echo -e "${GREEN}✓${NC} LLDB: $lldb_version"
    fi
    
    # System call tracers
    echo -e "\n${CYAN}System Call Tracers:${NC}"
    
    if command -v strace >/dev/null; then
        local strace_version=$(strace -V 2>&1 | head -1 | grep -o '[0-9]\+\.[0-9]\+')
        available_tools+=("strace:$strace_version")
        echo -e "${GREEN}✓${NC} strace: $strace_version"
    else
        missing_tools+=("strace")
    fi
    
    if command -v ltrace >/dev/null; then
        available_tools+=("ltrace:available")
        echo -e "${GREEN}✓${NC} ltrace available"
    else
        missing_tools+=("ltrace")
    fi
    
    # Memory analysis tools
    echo -e "\n${CYAN}Memory Analysis:${NC}"
    
    if command -v valgrind >/dev/null; then
        local valgrind_version=$(valgrind --version | cut -d'-' -f2)
        available_tools+=("valgrind:$valgrind_version")
        echo -e "${GREEN}✓${NC} Valgrind: $valgrind_version"
    else
        missing_tools+=("valgrind")
    fi
    
    # Performance profilers
    echo -e "\n${CYAN}Performance Profilers:${NC}"
    
    if command -v perf >/dev/null; then
        available_tools+=("perf:available")
        echo -e "${GREEN}✓${NC} perf available"
    else
        missing_tools+=("linux-tools-generic")
    fi
    
    if command -v gprof >/dev/null; then
        available_tools+=("gprof:available")
        echo -e "${GREEN}✓${NC} gprof available"
    fi
    
    # Binary analysis tools
    echo -e "\n${CYAN}Binary Analysis:${NC}"
    
    if command -v objdump >/dev/null; then
        available_tools+=("objdump:available")
        echo -e "${GREEN}✓${NC} objdump available"
    fi
    
    if command -v nm >/dev/null; then
        available_tools+=("nm:available")
        echo -e "${GREEN}✓${NC} nm available"
    fi
    
    if command -v readelf >/dev/null; then
        available_tools+=("readelf:available")
        echo -e "${GREEN}✓${NC} readelf available"
    fi
    
    if command -v ldd >/dev/null; then
        available_tools+=("ldd:available")
        echo -e "${GREEN}✓${NC} ldd available"
    fi
    
    # Show missing tools
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}Missing recommended tools:${NC}"
        for tool in "${missing_tools[@]}"; do
            echo -e "${RED}✗${NC} $tool"
        done
        echo -e "${CYAN}Install with: sudo apt install ${missing_tools[*]}${NC}"
    fi
    
    echo "${available_tools[@]}"
}

# Start debugging session
start_debug_session() {
    local target="$1"
    local debugger="${2:-$DEFAULT_DEBUGGER}"
    local args="$3"
    
    if [ -z "$target" ]; then
        echo -ne "${CYAN}Enter target executable:${NC} "
        read -r target
    fi
    
    if [ ! -f "$target" ]; then
        echo -e "${RED}✗${NC} Target file not found: $target"
        return 1
    fi
    
    # Check if binary has debug symbols
    if file "$target" | grep -q "not stripped"; then
        echo -e "${GREEN}✓${NC} Debug symbols present"
    else
        echo -e "${YELLOW}!${NC} Binary appears to be stripped (no debug symbols)"
    fi
    
    echo -e "${BLUE}Starting debug session with $debugger${NC}"
    echo -e "${CYAN}Target: $target${NC}"
    
    # Create debug session log
    local session_log="$LOGS_DIR/debug_$(basename "$target")_$(date +%Y%m%d_%H%M%S).log"
    echo "Debug session started: $(date)" > "$session_log"
    echo "Target: $target" >> "$session_log"
    echo "Debugger: $debugger" >> "$session_log"
    
    case "$debugger" in
        gdb)
            # Create GDB init file for this session
            local gdb_init="/tmp/bluejay_gdb_init"
            cat > "$gdb_init" << EOF
set logging file $session_log
set logging on
set confirm off
set pagination off
set print pretty on
set print array on
set print array-indexes on
set history save on
set history size $GDB_HISTORY_SIZE
set history filename ~/.gdb_history
EOF
            
            if [ "$AUTO_SYMBOLICATION" = "true" ]; then
                echo "set auto-load safe-path /" >> "$gdb_init"
            fi
            
            echo -e "${CYAN}GDB commands available:${NC}"
            echo -e "  ${WHITE}run [args]${NC} - Start program"
            echo -e "  ${WHITE}break <location>${NC} - Set breakpoint"
            echo -e "  ${WHITE}continue${NC} - Continue execution"
            echo -e "  ${WHITE}step${NC} - Step into"
            echo -e "  ${WHITE}next${NC} - Step over"
            echo -e "  ${WHITE}bt${NC} - Show backtrace"
            echo -e "  ${WHITE}info registers${NC} - Show CPU registers"
            echo -e "  ${WHITE}quit${NC} - Exit debugger"
            echo
            
            # Start GDB
            if [ -n "$args" ]; then
                gdb -x "$gdb_init" --args "$target" $args
            else
                gdb -x "$gdb_init" "$target"
            fi
            ;;
            
        lldb)
            echo -e "${CYAN}LLDB commands available:${NC}"
            echo -e "  ${WHITE}run [args]${NC} - Start program"
            echo -e "  ${WHITE}b <location>${NC} - Set breakpoint"
            echo -e "  ${WHITE}c${NC} - Continue execution"
            echo -e "  ${WHITE}s${NC} - Step into"
            echo -e "  ${WHITE}n${NC} - Step over"
            echo -e "  ${WHITE}bt${NC} - Show backtrace"
            echo
            
            # Start LLDB
            if [ -n "$args" ]; then
                lldb -- "$target" $args
            else
                lldb "$target"
            fi
            ;;
            
        *)
            echo -e "${RED}✗${NC} Unsupported debugger: $debugger"
            return 1
            ;;
    esac
    
    echo "Debug session ended: $(date)" >> "$session_log"
    echo -e "${GREEN}Debug session log saved: $session_log${NC}"
}

# System call tracing
trace_syscalls() {
    local target="$1"
    local trace_type="${2:-strace}"
    local output_file="$3"
    local args="$4"
    
    if [ -z "$target" ]; then
        echo -ne "${CYAN}Enter target executable or PID:${NC} "
        read -r target
    fi
    
    if [ -z "$output_file" ]; then
        output_file="$LOGS_DIR/trace_$(basename "$target")_$(date +%Y%m%d_%H%M%S).log"
    fi
    
    echo -e "${BLUE}Tracing system calls: $target${NC}"
    echo -e "${CYAN}Tracer: $trace_type${NC}"
    echo -e "${CYAN}Output: $output_file${NC}"
    
    case "$trace_type" in
        strace)
            if ! command -v strace >/dev/null; then
                echo -e "${RED}✗${NC} strace not available"
                return 1
            fi
            
            local strace_opts="-f -tt -T -o $output_file"
            
            # Check if target is a PID or executable
            if [[ $target =~ ^[0-9]+$ ]]; then
                echo -e "${CYAN}Attaching to PID: $target${NC}"
                strace $strace_opts -p "$target"
            else
                if [ ! -f "$target" ]; then
                    echo -e "${RED}✗${NC} Target file not found: $target"
                    return 1
                fi
                echo -e "${CYAN}Executing and tracing: $target${NC}"
                if [ -n "$args" ]; then
                    strace $strace_opts "$target" $args
                else
                    strace $strace_opts "$target"
                fi
            fi
            ;;
            
        ltrace)
            if ! command -v ltrace >/dev/null; then
                echo -e "${RED}✗${NC} ltrace not available"
                return 1
            fi
            
            local ltrace_opts="-f -tt -T -o $output_file"
            
            if [[ $target =~ ^[0-9]+$ ]]; then
                ltrace $ltrace_opts -p "$target"
            else
                if [ -n "$args" ]; then
                    ltrace $ltrace_opts "$target" $args
                else
                    ltrace $ltrace_opts "$target"
                fi
            fi
            ;;
            
        *)
            echo -e "${RED}✗${NC} Unsupported tracer: $trace_type"
            return 1
            ;;
    esac
    
    echo -e "${GREEN}✓${NC} Trace completed: $output_file"
}

# Memory analysis with Valgrind
analyze_memory() {
    local target="$1"
    local tool="${2:-memcheck}"
    local args="$3"
    
    if [ -z "$target" ]; then
        echo -ne "${CYAN}Enter target executable:${NC} "
        read -r target
    fi
    
    if [ ! -f "$target" ]; then
        echo -e "${RED}✗${NC} Target file not found: $target"
        return 1
    fi
    
    if ! command -v valgrind >/dev/null; then
        echo -e "${RED}✗${NC} Valgrind not available"
        return 1
    fi
    
    local output_file="$LOGS_DIR/valgrind_${tool}_$(basename "$target")_$(date +%Y%m%d_%H%M%S).log"
    
    echo -e "${BLUE}Memory analysis with Valgrind${NC}"
    echo -e "${CYAN}Target: $target${NC}"
    echo -e "${CYAN}Tool: $tool${NC}"
    echo -e "${CYAN}Output: $output_file${NC}"
    
    local valgrind_opts="--log-file=$output_file --track-origins=yes --show-leak-kinds=all"
    
    case "$tool" in
        memcheck)
            valgrind_opts="$valgrind_opts --tool=memcheck --leak-check=full"
            ;;
        cachegrind)
            valgrind_opts="$valgrind_opts --tool=cachegrind"
            ;;
        callgrind)
            valgrind_opts="$valgrind_opts --tool=callgrind"
            ;;
        massif)
            valgrind_opts="$valgrind_opts --tool=massif"
            ;;
        helgrind)
            valgrind_opts="$valgrind_opts --tool=helgrind"
            ;;
        drd)
            valgrind_opts="$valgrind_opts --tool=drd"
            ;;
        *)
            echo -e "${RED}✗${NC} Unsupported Valgrind tool: $tool"
            return 1
            ;;
    esac
    
    echo -e "${YELLOW}Running Valgrind analysis (this may take a while)...${NC}"
    
    if [ -n "$args" ]; then
        valgrind $valgrind_opts "$target" $args
    else
        valgrind $valgrind_opts "$target"
    fi
    
    echo -e "${GREEN}✓${NC} Analysis completed: $output_file"
    
    # Show summary for memcheck
    if [ "$tool" = "memcheck" ] && [ -f "$output_file" ]; then
        echo -e "\n${BLUE}Memory Analysis Summary:${NC}"
        grep -E "ERROR SUMMARY|LEAK SUMMARY|definitely lost|indirectly lost|possibly lost" "$output_file" | head -10
    fi
}

# Performance profiling
profile_performance() {
    local target="$1"
    local profiler="${2:-perf}"
    local duration="${3:-30}"
    local args="$4"
    
    if [ -z "$target" ]; then
        echo -ne "${CYAN}Enter target executable or PID:${NC} "
        read -r target
    fi
    
    local output_file="$PROFILES_DIR/profile_${profiler}_$(basename "$target")_$(date +%Y%m%d_%H%M%S)"
    
    echo -e "${BLUE}Performance profiling${NC}"
    echo -e "${CYAN}Target: $target${NC}"
    echo -e "${CYAN}Profiler: $profiler${NC}"
    echo -e "${CYAN}Duration: ${duration}s${NC}"
    
    case "$profiler" in
        perf)
            if ! command -v perf >/dev/null; then
                echo -e "${RED}✗${NC} perf not available"
                echo -e "${YELLOW}Install with: sudo apt install linux-tools-generic${NC}"
                return 1
            fi
            
            local perf_opts="-g --call-graph dwarf -F $SAMPLING_FREQUENCY"
            
            if [[ $target =~ ^[0-9]+$ ]]; then
                echo -e "${CYAN}Profiling PID: $target${NC}"
                perf record $perf_opts -p "$target" -o "$output_file.data" -- sleep "$duration"
            else
                if [ ! -f "$target" ]; then
                    echo -e "${RED}✗${NC} Target file not found: $target"
                    return 1
                fi
                echo -e "${CYAN}Profiling execution: $target${NC}"
                if [ -n "$args" ]; then
                    perf record $perf_opts -o "$output_file.data" -- "$target" $args
                else
                    perf record $perf_opts -o "$output_file.data" -- "$target"
                fi
            fi
            
            # Generate report
            perf report -i "$output_file.data" > "$output_file.txt"
            echo -e "${GREEN}✓${NC} Profile data: $output_file.data"
            echo -e "${GREEN}✓${NC} Profile report: $output_file.txt"
            
            # Show top functions
            echo -e "\n${BLUE}Top Functions by CPU Usage:${NC}"
            perf report -i "$output_file.data" --stdio | head -20
            ;;
            
        gprof)
            if [ ! -f "$target" ]; then
                echo -e "${RED}✗${NC} Target file not found: $target"
                return 1
            fi
            
            # Check if binary was compiled with -pg
            if ! nm "$target" | grep -q "mcount"; then
                echo -e "${YELLOW}!${NC} Binary not compiled with -pg flag for gprof"
                echo -e "${YELLOW}Recompile with: gcc -pg -g -o program source.c${NC}"
            fi
            
            echo -e "${CYAN}Running target to generate gmon.out...${NC}"
            if [ -n "$args" ]; then
                "$target" $args
            else
                "$target"
            fi
            
            if [ -f "gmon.out" ]; then
                gprof "$target" gmon.out > "$output_file.txt"
                echo -e "${GREEN}✓${NC} gprof report: $output_file.txt"
                
                # Show flat profile summary
                echo -e "\n${BLUE}Function Call Summary:${NC}"
                gprof "$target" gmon.out | head -20
            else
                echo -e "${RED}✗${NC} No gmon.out generated"
            fi
            ;;
            
        *)
            echo -e "${RED}✗${NC} Unsupported profiler: $profiler"
            return 1
            ;;
    esac
}

# Binary analysis
analyze_binary() {
    local binary="$1"
    local analysis_type="${2:-info}"
    
    if [ -z "$binary" ]; then
        echo -ne "${CYAN}Enter binary path:${NC} "
        read -r binary
    fi
    
    if [ ! -f "$binary" ]; then
        echo -e "${RED}✗${NC} Binary file not found: $binary"
        return 1
    fi
    
    echo -e "${BLUE}Binary Analysis: $(basename "$binary")${NC}"
    
    case "$analysis_type" in
        info)
            echo -e "\n${WHITE}File Information:${NC}"
            file "$binary"
            
            echo -e "\n${WHITE}ELF Header:${NC}"
            readelf -h "$binary" 2>/dev/null | head -20
            
            echo -e "\n${WHITE}Sections:${NC}"
            readelf -S "$binary" 2>/dev/null | grep -E "PROGBITS|NOBITS|DYNAMIC" | head -10
            
            echo -e "\n${WHITE}Dependencies:${NC}"
            ldd "$binary" 2>/dev/null | head -10
            
            echo -e "\n${WHITE}Symbols (first 10):${NC}"
            nm -D "$binary" 2>/dev/null | head -10
            ;;
            
        disasm)
            echo -e "\n${WHITE}Disassembly (first 50 instructions):${NC}"
            objdump -d "$binary" | head -50
            ;;
            
        strings)
            echo -e "\n${WHITE}String Analysis (first 20):${NC}"
            strings "$binary" | head -20
            ;;
            
        security)
            echo -e "\n${WHITE}Security Analysis:${NC}"
            
            # Check for stack protection
            if readelf -s "$binary" | grep -q "__stack_chk_fail"; then
                echo -e "${GREEN}✓${NC} Stack protection enabled"
            else
                echo -e "${RED}✗${NC} No stack protection"
            fi
            
            # Check for ASLR/PIE
            if readelf -h "$binary" | grep -q "DYN"; then
                echo -e "${GREEN}✓${NC} Position Independent Executable (PIE)"
            else
                echo -e "${YELLOW}!${NC} Not position independent"
            fi
            
            # Check for RELRO
            if readelf -l "$binary" | grep -q "GNU_RELRO"; then
                echo -e "${GREEN}✓${NC} RELRO protection"
            else
                echo -e "${RED}✗${NC} No RELRO protection"
            fi
            
            # Check for NX bit
            if readelf -l "$binary" | grep -q "GNU_STACK" && readelf -l "$binary" | grep "GNU_STACK" | grep -q "RWE"; then
                echo -e "${RED}✗${NC} Executable stack"
            else
                echo -e "${GREEN}✓${NC} Non-executable stack (NX bit)"
            fi
            ;;
            
        *)
            echo -e "${RED}✗${NC} Unknown analysis type: $analysis_type"
            echo -e "${CYAN}Available types: info disasm strings security${NC}"
            return 1
            ;;
    esac
}

# Core dump analysis
analyze_core_dump() {
    local core_file="$1"
    local binary="$2"
    
    if [ -z "$core_file" ]; then
        echo -e "${BLUE}Available core dumps:${NC}"
        if [ -d "$CORE_DUMPS_DIR" ] && [ "$(ls -A "$CORE_DUMPS_DIR" 2>/dev/null)" ]; then
            ls -la "$CORE_DUMPS_DIR"
            echo -ne "${CYAN}Enter core dump path:${NC} "
            read -r core_file
        else
            echo -e "${YELLOW}No core dumps found in $CORE_DUMPS_DIR${NC}"
            return 1
        fi
    fi
    
    if [ ! -f "$core_file" ]; then
        echo -e "${RED}✗${NC} Core dump not found: $core_file"
        return 1
    fi
    
    if [ -z "$binary" ]; then
        echo -ne "${CYAN}Enter corresponding binary path:${NC} "
        read -r binary
    fi
    
    if [ ! -f "$binary" ]; then
        echo -e "${RED}✗${NC} Binary not found: $binary"
        return 1
    fi
    
    echo -e "${BLUE}Analyzing core dump${NC}"
    echo -e "${CYAN}Core: $core_file${NC}"
    echo -e "${CYAN}Binary: $binary${NC}"
    
    # Create GDB analysis script
    local gdb_script="/tmp/core_analysis.gdb"
    cat > "$gdb_script" << 'EOF'
set pagination off
echo \n=== CORE DUMP ANALYSIS ===\n
echo \nProgram Information:\n
info program
echo \nRegister Contents:\n
info registers
echo \nBacktrace:\n
bt
echo \nThread Information:\n
info threads
echo \nMemory Map:\n
info proc mappings
echo \nSignal Information:\n
info signal
EOF
    
    # Run GDB analysis
    gdb -batch -x "$gdb_script" "$binary" "$core_file"
    
    # Clean up
    rm -f "$gdb_script"
}

# System monitoring
monitor_system() {
    local duration="${1:-60}"
    local interval="${2:-5}"
    
    echo -e "${BLUE}System Performance Monitor${NC}"
    echo -e "${CYAN}Duration: ${duration}s, Interval: ${interval}s${NC}"
    echo -e "${GRAY}Press Ctrl+C to stop monitoring${NC}"
    echo
    
    local end_time=$(($(date +%s) + duration))
    
    while [ $(date +%s) -lt $end_time ]; do
        clear
        echo -e "${PURPLE}=== System Performance Monitor ===${NC}"
        echo -e "${CYAN}Timestamp: $(date)${NC}"
        echo
        
        # CPU usage
        echo -e "${WHITE}CPU Usage:${NC}"
        if command -v mpstat >/dev/null; then
            mpstat 1 1 | tail -1
        else
            top -bn1 | grep "Cpu(s)" | head -1
        fi
        
        echo
        
        # Memory usage
        echo -e "${WHITE}Memory Usage:${NC}"
        free -h
        
        echo
        
        # Top processes by CPU
        echo -e "${WHITE}Top Processes (CPU):${NC}"
        ps aux --sort=-%cpu | head -6
        
        echo
        
        # Top processes by Memory
        echo -e "${WHITE}Top Processes (Memory):${NC}"
        ps aux --sort=-%mem | head -6
        
        echo
        
        # I/O statistics
        if command -v iostat >/dev/null; then
            echo -e "${WHITE}I/O Statistics:${NC}"
            iostat -x 1 1 | tail -n +4 | head -5
        fi
        
        sleep "$interval"
    done
}

# Main menu
main_menu() {
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║              ${WHITE}BluejayLinux Debug & Profiler Suite${PURPLE}               ║${NC}"
    echo -e "${PURPLE}║            ${CYAN}Advanced System Debugging & Analysis${PURPLE}                ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    local debug_tools=($(detect_debug_tools))
    echo -e "${WHITE}Debug tools available:${NC} ${#debug_tools[@]}"
    echo
    
    echo -e "${WHITE}Debugging:${NC}"
    echo -e "${WHITE}1.${NC} Start debug session"
    echo -e "${WHITE}2.${NC} Trace system calls"
    echo -e "${WHITE}3.${NC} Analyze core dump"
    echo
    echo -e "${WHITE}Memory Analysis:${NC}"
    echo -e "${WHITE}4.${NC} Memory analysis (Valgrind)"
    echo -e "${WHITE}5.${NC} Memory leak detection"
    echo
    echo -e "${WHITE}Performance Profiling:${NC}"
    echo -e "${WHITE}6.${NC} CPU profiling"
    echo -e "${WHITE}7.${NC} System monitoring"
    echo
    echo -e "${WHITE}Binary Analysis:${NC}"
    echo -e "${WHITE}8.${NC} Analyze binary"
    echo -e "${WHITE}9.${NC} Security analysis"
    echo
    echo -e "${WHITE}Logs & Reports:${NC}"
    echo -e "${WHITE}10.${NC} View debug logs"
    echo -e "${WHITE}11.${NC} View profile reports"
    echo -e "${WHITE}q.${NC} Quit"
    echo
}

# Main function
main() {
    create_directories
    load_settings
    
    # Enable core dumps
    if [ "$ENABLE_CORE_DUMPS" = "true" ]; then
        ulimit -c unlimited
        if [ -n "$CORE_DUMP_PATTERN" ]; then
            echo "$CORE_DUMP_PATTERN" | sudo tee /proc/sys/kernel/core_pattern >/dev/null 2>&1 || true
        fi
    fi
    
    if [ $# -gt 0 ]; then
        case "$1" in
            --debug)
                start_debug_session "$2" "$3" "$4"
                ;;
            --trace)
                trace_syscalls "$2" "$3" "$4" "$5"
                ;;
            --memory)
                analyze_memory "$2" "$3" "$4"
                ;;
            --profile)
                profile_performance "$2" "$3" "$4" "$5"
                ;;
            --analyze)
                analyze_binary "$2" "$3"
                ;;
            --core)
                analyze_core_dump "$2" "$3"
                ;;
            --monitor)
                monitor_system "$2" "$3"
                ;;
            --help|-h)
                echo "BluejayLinux Debug & Profiler Suite"
                echo "Usage: $0 [options] [parameters]"
                echo "  --debug <target> [debugger] [args]     Start debug session"
                echo "  --trace <target> [tracer] [output] [args]  Trace system calls"
                echo "  --memory <target> [tool] [args]        Memory analysis"
                echo "  --profile <target> [profiler] [duration] [args]  Performance profiling"
                echo "  --analyze <binary> [type]              Binary analysis"
                echo "  --core <core_file> <binary>            Core dump analysis"
                echo "  --monitor [duration] [interval]        System monitoring"
                ;;
        esac
        return
    fi
    
    # Interactive mode
    while true; do
        main_menu
        echo -ne "${YELLOW}Select option:${NC} "
        read -r choice
        
        case "$choice" in
            1)
                echo -ne "${CYAN}Target executable:${NC} "
                read -r target
                echo -e "${CYAN}Debugger options: gdb lldb${NC}"
                echo -ne "${CYAN}Debugger (gdb):${NC} "
                read -r debugger
                debugger="${debugger:-gdb}"
                echo -ne "${CYAN}Program arguments (optional):${NC} "
                read -r args
                start_debug_session "$target" "$debugger" "$args"
                ;;
            2)
                echo -ne "${CYAN}Target executable or PID:${NC} "
                read -r target
                echo -e "${CYAN}Tracer options: strace ltrace${NC}"
                echo -ne "${CYAN}Tracer (strace):${NC} "
                read -r tracer
                tracer="${tracer:-strace}"
                echo -ne "${CYAN}Arguments (optional):${NC} "
                read -r args
                trace_syscalls "$target" "$tracer" "" "$args"
                ;;
            3)
                analyze_core_dump
                ;;
            4)
                echo -ne "${CYAN}Target executable:${NC} "
                read -r target
                echo -e "${CYAN}Tools: memcheck cachegrind callgrind massif helgrind${NC}"
                echo -ne "${CYAN}Valgrind tool (memcheck):${NC} "
                read -r tool
                tool="${tool:-memcheck}"
                echo -ne "${CYAN}Arguments (optional):${NC} "
                read -r args
                analyze_memory "$target" "$tool" "$args"
                ;;
            5)
                echo -ne "${CYAN}Target executable:${NC} "
                read -r target
                echo -ne "${CYAN}Arguments (optional):${NC} "
                read -r args
                analyze_memory "$target" "memcheck" "$args"
                ;;
            6)
                echo -ne "${CYAN}Target executable or PID:${NC} "
                read -r target
                echo -e "${CYAN}Profilers: perf gprof${NC}"
                echo -ne "${CYAN}Profiler (perf):${NC} "
                read -r profiler
                profiler="${profiler:-perf}"
                echo -ne "${CYAN}Duration in seconds (30):${NC} "
                read -r duration
                duration="${duration:-30}"
                echo -ne "${CYAN}Arguments (optional):${NC} "
                read -r args
                profile_performance "$target" "$profiler" "$duration" "$args"
                ;;
            7)
                echo -ne "${CYAN}Monitor duration in seconds (60):${NC} "
                read -r duration
                duration="${duration:-60}"
                echo -ne "${CYAN}Update interval in seconds (5):${NC} "
                read -r interval
                interval="${interval:-5}"
                monitor_system "$duration" "$interval"
                ;;
            8)
                echo -ne "${CYAN}Binary path:${NC} "
                read -r binary
                echo -e "${CYAN}Analysis types: info disasm strings security${NC}"
                echo -ne "${CYAN}Analysis type (info):${NC} "
                read -r analysis_type
                analysis_type="${analysis_type:-info}"
                analyze_binary "$binary" "$analysis_type"
                ;;
            9)
                echo -ne "${CYAN}Binary path:${NC} "
                read -r binary
                analyze_binary "$binary" "security"
                ;;
            10)
                echo -e "\n${BLUE}Debug Logs:${NC}"
                if [ -d "$LOGS_DIR" ] && [ "$(ls -A "$LOGS_DIR" 2>/dev/null)" ]; then
                    ls -la "$LOGS_DIR"
                    echo -ne "\n${CYAN}Enter log file to view:${NC} "
                    read -r log_file
                    if [ -f "$LOGS_DIR/$log_file" ]; then
                        less "$LOGS_DIR/$log_file"
                    fi
                else
                    echo -e "${YELLOW}No debug logs found${NC}"
                fi
                ;;
            11)
                echo -e "\n${BLUE}Profile Reports:${NC}"
                if [ -d "$PROFILES_DIR" ] && [ "$(ls -A "$PROFILES_DIR" 2>/dev/null)" ]; then
                    ls -la "$PROFILES_DIR"
                    echo -ne "\n${CYAN}Enter report file to view:${NC} "
                    read -r report_file
                    if [ -f "$PROFILES_DIR/$report_file" ]; then
                        less "$PROFILES_DIR/$report_file"
                    fi
                else
                    echo -e "${YELLOW}No profile reports found${NC}"
                fi
                ;;
            q|Q)
                echo -e "${GREEN}Debug & Profiler session saved${NC}"
                break
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
        echo
        echo -ne "${GRAY}Press Enter to continue...${NC}"
        read -r
        clear
    done
}

# Run main function
main "$@"