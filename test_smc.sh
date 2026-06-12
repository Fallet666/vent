#!/bin/bash
# Run: sudo bash test_smc.sh 2>&1 | tee /tmp/smc_test.log
set -euo pipefail

log() {
    echo "[$(date '+%H:%M:%S.%3N')] $*"
}

header() {
    echo ""
    echo "==== $* ===="
    echo ""
}

# ---- 0. Rebuild ----
header "0. Rebuild"
cmake --build build 2>&1

# ---- 1. Read initial values ----
header "1. Read initial values"
./build/fanctl read Ftst 2>&1
./build/fanctl read F0Md 2>&1
./build/fanctl read F0Tg 2>&1
./build/fanctl read F0Ac 2>&1
./build/fanctl read 'FS! ' 2>&1 || true

# ---- 2. Direct write tests (root) ----
header "2. Direct write tests (root)"

log "=== write Ftst 1 ==="
sudo ./build/fanctl write Ftst 1 2>&1 || true
sudo ./build/fanctl read Ftst 2>&1

log "=== write F0Md 1 ==="
sudo ./build/fanctl write F0Md 1 2>&1 || true
sudo ./build/fanctl read F0Md 2>&1

log "=== write F0Tg 5000 ==="
sudo ./build/fanctl write F0Tg 2000 2>&1 || true
sudo ./build/fanctl read F0Tg 2>&1
sudo ./build/fanctl read F0Ac 2>&1

# ---- 3. Daemon reconcile test ----
header "3. Daemon reconcile test (5 seconds)"

log "=== clean up old daemon ==="
killall fanctld 2>/dev/null || true
sleep 0.5
rm -f /tmp/fanctl.sock 2>/dev/null || true

log "=== start daemon in background ==="
sudo ./build/fanctld -f 2>&1 &
DAEMON_PID=$!
sleep 1

log "=== send persist 0 2000 ==="
./build/fanctl persist 0 2000 2>&1 &
PERSIST_PID=$!
sleep 4
kill $PERSIST_PID 2>/dev/null || true
wait $PERSIST_PID 2>/dev/null || true
sleep 3

log "=== check values ==="
sudo ./build/fanctl read F0Md 2>&1
sudo ./build/fanctl read F0Tg 2>&1
sudo ./build/fanctl read F0Ac 2>&1

log "=== stop daemon ==="
kill $DAEMON_PID 2>/dev/null || true
wait $DAEMON_PID 2>/dev/null || true
rm -f /tmp/fanctl.sock 2>/dev/null || true

echo ""
echo "==== DONE ===="
