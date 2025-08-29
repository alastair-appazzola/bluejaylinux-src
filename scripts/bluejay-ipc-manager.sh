#!/bin/bash
# BluejayLinux IPC Manager - Inter-process communication and D-Bus framework
# Handles message passing between applications and system services

set -e

IPC_CONFIG="/etc/bluejay/ipc.conf"
IPC_STATE="/run/bluejay-ipc"
DBUS_CONFIG="/etc/bluejay/dbus.conf"
IPC_SOCKETS_DIR="/run/bluejay-ipc-sockets"

log_ipc() {
    echo "[$(date '+%H:%M:%S')] IPC: $1" | tee -a /var/log/bluejay-ipc.log
}

log_error() {
    echo "[$(date '+%H:%M:%S')] ERROR: $1" | tee -a /var/log/bluejay-ipc.log >&2
}

log_success() {
    echo "[$(date '+%H:%M:%S')] SUCCESS: $1" | tee -a /var/log/bluejay-ipc.log
}

# Initialize IPC manager
init_ipc_manager() {
    log_ipc "Initializing BluejayLinux IPC Manager..."
    
    # Create directories
    mkdir -p "$(dirname "$IPC_CONFIG")"
    mkdir -p "$(dirname "$IPC_STATE")"
    mkdir -p "$IPC_SOCKETS_DIR"
    mkdir -p /var/log
    mkdir -p /opt/bluejay/bin
    
    # Create IPC configuration
    create_ipc_config
    
    # Initialize IPC state
    init_ipc_state
    
    # Set up message broker
    setup_message_broker
    
    log_success "IPC Manager initialized"
}

create_ipc_config() {
    cat > "$IPC_CONFIG" << 'EOF'
# BluejayLinux IPC Configuration

# Message broker settings
BROKER_PORT=5555
BROKER_MAX_CONNECTIONS=100
BROKER_TIMEOUT=30
ENABLE_ENCRYPTION=false

# D-Bus settings
DBUS_SYSTEM_BUS=true
DBUS_SESSION_BUS=true
DBUS_SECURITY_POLICY=strict

# Socket settings
SOCKET_BUFFER_SIZE=8192
SOCKET_TIMEOUT=10
MAX_SOCKETS=1000

# Message settings
MAX_MESSAGE_SIZE=1048576
MESSAGE_QUEUE_SIZE=100
ENABLE_MESSAGE_LOGGING=true
EOF

    cat > "$DBUS_CONFIG" << 'EOF'
# BluejayLinux D-Bus Configuration
<busconfig>
  <type>system</type>
  <listen>unix:tmpdir=/tmp</listen>
  
  <policy context="default">
    <allow user="*"/>
    <allow send_destination="*" send_interface="*"/>
    <allow receive_requested_reply="true"/>
    <allow receive_sender="*"/>
  </policy>
  
  <policy user="root">
    <allow own="*"/>
    <allow send_destination="*"/>
    <allow receive_sender="*"/>
  </policy>
  
  <policy at_console="true">
    <allow own="*"/>
  </policy>
</busconfig>
EOF
    
    log_success "IPC configuration created"
}

init_ipc_state() {
    cat > "$IPC_STATE" << 'EOF'
ipc_running=false
broker_running=false
dbus_running=false
active_connections=0
messages_sent=0
messages_received=0
EOF
    
    log_success "IPC state initialized"
}

setup_message_broker() {
    cat > /opt/bluejay/bin/bluejay-message-broker << 'EOF'
#!/bin/bash
# BluejayLinux Message Broker

IPC_STATE="/run/bluejay-ipc"
IPC_SOCKETS_DIR="/run/bluejay-ipc-sockets"
LOG_FILE="/var/log/bluejay-ipc.log"

declare -A connections
declare -A subscriptions

log_broker() {
    echo "[$(date '+%H:%M:%S')] BROKER: $1" >> "$LOG_FILE"
}

load_ipc_state() {
    if [ -f "$IPC_STATE" ]; then
        . "$IPC_STATE"
    fi
}

save_ipc_state() {
    cat > "$IPC_STATE" << EOF
ipc_running=$ipc_running
broker_running=$broker_running  
dbus_running=$dbus_running
active_connections=$active_connections
messages_sent=$messages_sent
messages_received=$messages_received
EOF
}

start_broker() {
    log_broker "Starting message broker..."
    
    load_ipc_state
    broker_running=true
    save_ipc_state
    
    # Create broker socket
    local broker_socket="$IPC_SOCKETS_DIR/broker"
    rm -f "$broker_socket"
    
    # Simple message routing loop
    while [ "$broker_running" = "true" ]; do
        # Check for new messages
        for socket_file in "$IPC_SOCKETS_DIR"/*.msg; do
            if [ -f "$socket_file" ]; then
                process_message "$socket_file"
                rm -f "$socket_file"
            fi
        done
        
        # Process subscription updates
        process_subscriptions
        
        sleep 0.1
    done
}

process_message() {
    local msg_file="$1"
    local sender=""
    local destination=""
    local topic=""
    local payload=""
    
    # Parse message file
    while IFS='=' read -r key value; do
        case "$key" in
            SENDER) sender="$value" ;;
            DESTINATION) destination="$value" ;;
            TOPIC) topic="$value" ;;
            PAYLOAD) payload="$value" ;;
        esac
    done < "$msg_file"
    
    log_broker "Message from $sender to $destination: $topic"
    
    # Route message based on destination
    if [ "$destination" = "BROADCAST" ]; then
        # Broadcast to all subscribers
        broadcast_message "$topic" "$payload" "$sender"
    else
        # Send to specific destination
        send_to_destination "$destination" "$topic" "$payload" "$sender"
    fi
    
    # Update statistics
    load_ipc_state
    messages_received=$((messages_received + 1))
    save_ipc_state
}

broadcast_message() {
    local topic="$1"
    local payload="$2"
    local sender="$3"
    
    # Send to all processes subscribed to this topic
    for sub_file in "$IPC_SOCKETS_DIR"/*.sub; do
        if [ -f "$sub_file" ]; then
            local subscriber=$(basename "$sub_file" .sub)
            local topics=""
            
            if [ -f "$sub_file" ]; then
                topics=$(cat "$sub_file")
            fi
            
            # Check if subscriber is interested in this topic
            if echo "$topics" | grep -q "$topic"; then
                deliver_message "$subscriber" "$topic" "$payload" "$sender"
            fi
        fi
    done
}

send_to_destination() {
    local destination="$1"
    local topic="$2"
    local payload="$3"
    local sender="$4"
    
    deliver_message "$destination" "$topic" "$payload" "$sender"
}

deliver_message() {
    local recipient="$1"
    local topic="$2"
    local payload="$3"  
    local sender="$4"
    
    local inbox="$IPC_SOCKETS_DIR/$recipient.inbox"
    
    # Create message in recipient's inbox
    cat > "$inbox.tmp" << EOF
FROM=$sender
TOPIC=$topic
PAYLOAD=$payload
TIMESTAMP=$(date '+%s')
EOF
    
    mv "$inbox.tmp" "$inbox"
    
    log_broker "Delivered message to $recipient"
    
    # Update statistics
    load_ipc_state
    messages_sent=$((messages_sent + 1))
    save_ipc_state
}

process_subscriptions() {
    # Handle subscription requests
    for req_file in "$IPC_SOCKETS_DIR"/*.subscribe; do
        if [ -f "$req_file" ]; then
            local subscriber=$(basename "$req_file" .subscribe)
            local topics=$(cat "$req_file")
            
            # Update subscription file
            echo "$topics" > "$IPC_SOCKETS_DIR/$subscriber.sub"
            
            log_broker "Updated subscriptions for $subscriber: $topics"
            rm -f "$req_file"
        fi
    done
}

main() {
    start_broker
}

main "$@"
EOF
    chmod +x /opt/bluejay/bin/bluejay-message-broker

    # Create IPC client library
    cat > /opt/bluejay/bin/bluejay-ipc-client << 'EOF'
#!/bin/bash
# BluejayLinux IPC Client Library

IPC_SOCKETS_DIR="/run/bluejay-ipc-sockets"
CLIENT_ID="$$"

send_message() {
    local destination="$1"
    local topic="$2"
    local payload="$3"
    
    local msg_file="$IPC_SOCKETS_DIR/msg_$CLIENT_ID_$(date +%s).msg"
    
    cat > "$msg_file" << EOF
SENDER=$CLIENT_ID
DESTINATION=$destination
TOPIC=$topic
PAYLOAD=$payload
EOF
    
    echo "Message sent to $destination"
}

broadcast_message() {
    local topic="$1"
    local payload="$2"
    
    send_message "BROADCAST" "$topic" "$payload"
}

subscribe_to_topic() {
    local topic="$1"
    
    local sub_file="$IPC_SOCKETS_DIR/$CLIENT_ID.subscribe"
    echo "$topic" >> "$sub_file"
    
    echo "Subscribed to topic: $topic"
}

receive_messages() {
    local inbox="$IPC_SOCKETS_DIR/$CLIENT_ID.inbox"
    
    while true; do
        if [ -f "$inbox" ]; then
            echo "New message received:"
            cat "$inbox"
            echo "---"
            rm -f "$inbox"
        fi
        sleep 0.5
    done
}

case "$1" in
    send)
        send_message "$2" "$3" "$4"
        ;;
    broadcast)
        broadcast_message "$2" "$3"
        ;;
    subscribe)
        subscribe_to_topic "$2"
        ;;
    receive)
        receive_messages
        ;;
    *)
        echo "Usage: $0 {send|broadcast|subscribe|receive} [args]"
        echo ""
        echo "Commands:"
        echo "  send <dest> <topic> <payload>    Send message to specific process"
        echo "  broadcast <topic> <payload>      Broadcast message to all subscribers"
        echo "  subscribe <topic>                Subscribe to topic"
        echo "  receive                          Listen for incoming messages"
        ;;
esac
EOF
    chmod +x /opt/bluejay/bin/bluejay-ipc-client
    
    log_success "Message broker set up"
}

start_ipc_manager() {
    log_ipc "Starting IPC Manager..."
    
    # Start message broker
    /opt/bluejay/bin/bluejay-message-broker &
    local broker_pid=$!
    echo "$broker_pid" > /run/bluejay-message-broker.pid
    
    # Update state
    . "$IPC_STATE"
    ipc_running=true
    broker_running=true
    cat > "$IPC_STATE" << EOF
ipc_running=$ipc_running
broker_running=$broker_running
dbus_running=$dbus_running
active_connections=$active_connections
messages_sent=$messages_sent
messages_received=$messages_received
EOF
    
    log_success "IPC Manager started (Broker PID: $broker_pid)"
}

stop_ipc_manager() {
    log_ipc "Stopping IPC Manager..."
    
    if [ -f /run/bluejay-message-broker.pid ]; then
        local pid=$(cat /run/bluejay-message-broker.pid)
        kill "$pid" 2>/dev/null || true
        rm -f /run/bluejay-message-broker.pid
    fi
    
    # Clean up sockets
    rm -f "$IPC_SOCKETS_DIR"/*
    
    # Update state
    . "$IPC_STATE"
    ipc_running=false
    broker_running=false
    active_connections=0
    cat > "$IPC_STATE" << EOF
ipc_running=$ipc_running
broker_running=$broker_running
dbus_running=$dbus_running
active_connections=$active_connections
messages_sent=$messages_sent
messages_received=$messages_received
EOF
    
    log_success "IPC Manager stopped"
}

show_ipc_status() {
    echo "BluejayLinux IPC Manager Status"
    echo "==============================="
    echo ""
    
    if [ -f "$IPC_STATE" ]; then
        . "$IPC_STATE"
        echo "IPC Running: $ipc_running"
        echo "Broker Running: $broker_running" 
        echo "D-Bus Running: $dbus_running"
        echo "Active Connections: $active_connections"
        echo "Messages Sent: $messages_sent"
        echo "Messages Received: $messages_received"
    else
        echo "IPC not initialized"
    fi
    echo ""
    
    echo "Active Sockets:"
    if [ -d "$IPC_SOCKETS_DIR" ]; then
        ls -la "$IPC_SOCKETS_DIR" 2>/dev/null || echo "  No sockets"
    else
        echo "  Socket directory not found"
    fi
}

main() {
    case "$1" in
        init) init_ipc_manager ;;
        start) start_ipc_manager ;;
        stop) stop_ipc_manager ;;
        restart) stop_ipc_manager; sleep 2; start_ipc_manager ;;
        status) show_ipc_status ;;
        help|*) 
            echo "Usage: $0 {init|start|stop|restart|status|help}"
            echo ""
            echo "BluejayLinux IPC Manager - Inter-process communication framework"
            ;;
    esac
}

main "$@"