
#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

PYTHON="$PROJECT_DIR/.venv/bin/python"
PID_FILE="$PROJECT_DIR/data/listen.pid"
LOG_FILE="$PROJECT_DIR/data/listen.log"

mkdir -p "$PROJECT_DIR/data"

# --------------------------------------------------
# Stop receiver
# --------------------------------------------------

stop_receiver() {
    if [[ ! -f "$PID_FILE" ]]; then
        echo "No receiver PID file found. Receiver may not be running."
        exit 0
    fi

    PID="$(cat "$PID_FILE")"

    if [[ ! "$PID" =~ ^[0-9]+$ ]]; then
        echo "ERROR: Invalid PID file."
        rm -f "$PID_FILE"
        exit 1
    fi

    if kill -0 "$PID" 2>/dev/null; then
        echo "Stopping receiver (PID $PID)..."
        kill -TERM "$PID"

        for _ in {1..10}; do
            if ! kill -0 "$PID" 2>/dev/null; then
                break
            fi
            sleep 1
        done

        if kill -0 "$PID" 2>/dev/null; then
            echo "Receiver did not stop; sending SIGKILL..."
            kill -KILL "$PID" 2>/dev/null || true
        fi

        echo "Receiver stopped."
    else
        echo "Receiver is not running."
    fi

    rm -f "$PID_FILE"
}

# --------------------------------------------------
# Status
# --------------------------------------------------

show_status() {
    if [[ -f "$PID_FILE" ]]; then
        PID="$(cat "$PID_FILE")"

        if [[ "$PID" =~ ^[0-9]+$ ]] && kill -0 "$PID" 2>/dev/null; then
            echo "Receiver is running (PID $PID)."
            echo "Log: $LOG_FILE"
            exit 0
        fi

        echo "Stale PID file found. Receiver is not running."
        rm -f "$PID_FILE"
    else
        echo "Receiver is not running."
    fi
}

# --------------------------------------------------
# Commands
# --------------------------------------------------

case "${1:-start}" in
    stop)
        stop_receiver
        exit 0
        ;;
    status)
        show_status
        exit 0
        ;;
    logs)
        touch "$LOG_FILE"
        tail -n 50 -f "$LOG_FILE"
        exit 0
        ;;
    start)
        ;;
    *)
        echo "Usage: $0 {start|stop|status|logs}"
        exit 1
        ;;
esac

# --------------------------------------------------
# Environment checks
# --------------------------------------------------

if [[ ! -x "$PYTHON" ]]; then
    echo "ERROR: Virtual environment not found: $PYTHON"
    exit 1
fi

if [[ -f "$PID_FILE" ]]; then
    PID="$(cat "$PID_FILE")"

    if [[ "$PID" =~ ^[0-9]+$ ]] && kill -0 "$PID" 2>/dev/null; then
        echo "Receiver is already running (PID $PID)."
        exit 0
    fi

    rm -f "$PID_FILE"
fi

# --------------------------------------------------
# Configuration
# --------------------------------------------------

echo
echo "======================================"
echo "       WWV Time Signal Receiver"
echo "======================================"
echo

read -rp "Enter frequency/frequencies in MHz (e.g. 5 10 15): " FREQUENCIES

if [[ -z "${FREQUENCIES//[[:space:]]/}" ]]; then
    echo "ERROR: At least one frequency is required."
    exit 1
fi

read -r -a FREQUENCY_ARRAY <<< "$FREQUENCIES"

for FREQ in "${FREQUENCY_ARRAY[@]}"; do
    if ! [[ "$FREQ" =~ ^([0-9]+([.][0-9]*)?|[.][0-9]+)$ ]]; then
        echo "ERROR: Invalid frequency: $FREQ"
        exit 1
    fi

    if ! awk -v f="$FREQ" 'BEGIN { exit !(f >= 0.5 && f <= 30) }'; then
        echo "ERROR: Frequency out of range: $FREQ MHz"
        exit 1
    fi
done

echo
echo "Selected frequencies:"
printf '  %s MHz\n' "${FREQUENCY_ARRAY[@]}"
echo

read -rp "Start receiver? [y/N]: " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# --------------------------------------------------
# Start receiver in background
# --------------------------------------------------

echo
echo "Starting receiver..."

nohup "$PYTHON" -u -m src.listen \
    --frequency "${FREQUENCY_ARRAY[@]}" \
    >> "$LOG_FILE" 2>&1 < /dev/null &

PID=$!
echo "$PID" > "$PID_FILE"

sleep 1

if kill -0 "$PID" 2>/dev/null; then
    echo "Receiver started (PID $PID)."
    echo "Log file: $LOG_FILE"
else
    echo "ERROR: Receiver failed to start. Check:"
    echo "  $LOG_FILE"
    rm -f "$PID_FILE"
    exit 1
fi
