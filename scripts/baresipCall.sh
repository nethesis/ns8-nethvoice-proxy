#!/bin/bash
set -e

# ══════════════════════════════════════════════════════════════════════════════
# Colors
# ══════════════════════════════════════════════════════════════════════════════
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# ══════════════════════════════════════════════════════════════════════════════
# Host definitions
# ══════════════════════════════════════════════════════════════════════════════
HOST_102_LAN="gns3-nethvoice-pc-with-softphone"
HOST_102_WAN="gns3-nethvoice-pc-with-softphone-lan2.netbird.selfhosted"
HOST_103_LAN="gns3-nethvoice-pc-with-softphone2"

# ══════════════════════════════════════════════════════════════════════════════
# Functions
# ══════════════════════════════════════════════════════════════════════════════
print_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
    ╔══════════════════════════════════════════════════════════════════╗
    ║                                                                  ║
    ║   ██████╗  █████╗ ██████╗ ███████╗███████╗██╗██████╗            ║
    ║   ██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔════╝██║██╔══██╗           ║
    ║   ██████╔╝███████║██████╔╝█████╗  ███████╗██║██████╔╝           ║
    ║   ██╔══██╗██╔══██║██╔══██╗██╔══╝  ╚════██║██║██╔═══╝            ║
    ║   ██████╔╝██║  ██║██║  ██║███████╗███████║██║██║                ║
    ║   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝╚═╝                ║
    ║                                                                  ║
    ║              📞  SIP Call Test Suite  📞                        ║
    ║                                                                  ║
    ╚══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

print_scenario_lan() {
    echo -e "${GREEN}"
    cat << 'EOF'
    ┌─────────────────────────────────────────────────────────────────┐
    │                      🏠 LAN -> LAN Test                         │
    ├─────────────────────────────────────────────────────────────────┤
    │                                                                 │
    │    ┌─────────┐          ┌─────────┐          ┌─────────┐       │
    │    │   102   │  ═════>  │ KAMAILIO│  ═════>  │   103   │       │
    │    │  (LAN)  │   SIP    │  PROXY  │   SIP    │  (LAN)  │       │
    │    └─────────┘          └─────────┘          └─────────┘       │
    │         📱                  🔀                    📱            │
    │                                                                 │
    └─────────────────────────────────────────────────────────────────┘
EOF
    echo -e "${NC}"
}

print_scenario_wan() {
    echo -e "${YELLOW}"
    cat << 'EOF'
    ┌─────────────────────────────────────────────────────────────────┐
    │                      🌍 WAN -> LAN Test                         │
    ├─────────────────────────────────────────────────────────────────┤
    │                                                                 │
    │    ┌─────────┐          ┌─────────┐          ┌─────────┐       │
    │    │   102   │  ═════>  │ KAMAILIO│  ═════>  │   103   │       │
    │    │  (WAN)  │   SIP    │  PROXY  │   SIP    │  (LAN)  │       │
    │    └─────────┘    🌐    └─────────┘          └─────────┘       │
    │         📱                  🔀                    📱            │
    │       INTERNET              ↑                  LOCAL           │
    │                        NAT TRAVERSAL                           │
    └─────────────────────────────────────────────────────────────────┘
EOF
    echo -e "${NC}"
}

print_scenario_reverse() {
    echo -e "${MAGENTA}"
    cat << 'EOF'
    ┌─────────────────────────────────────────────────────────────────┐
    │                      🔄 LAN -> WAN Test                         │
    ├─────────────────────────────────────────────────────────────────┤
    │                                                                 │
    │    ┌─────────┐          ┌─────────┐          ┌─────────┐       │
    │    │   103   │  ═════>  │ KAMAILIO│  ═════>  │   102   │       │
    │    │  (LAN)  │   SIP    │  PROXY  │   SIP    │  (WAN)  │       │
    │    └─────────┘          └─────────┘    🌐    └─────────┘       │
    │         📱                  🔀                    📱            │
    │       LOCAL                 ↑                 INTERNET         │
    │                        NAT TRAVERSAL                           │
    └─────────────────────────────────────────────────────────────────┘
EOF
    echo -e "${NC}"
}

print_usage() {
    echo -e "${BOLD}Usage:${NC} $0 [lan|wan|reverse]"
    echo ""
    echo -e "  ${GREEN}lan${NC}      - (102)LAN -> (103)LAN  ${DIM}(default)${NC}"
    echo -e "  ${YELLOW}wan${NC}      - (102)WAN -> (103)LAN"
    echo -e "  ${MAGENTA}reverse${NC}  - (103)LAN -> (102)WAN"
    echo ""
}

step() {
    echo -e "${BLUE}▶${NC} ${BOLD}$1${NC}"
}

success() {
    echo -e "${GREEN}✔${NC} $1"
}

info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

# ══════════════════════════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════════════════════════
print_banner

# Default: LAN mode
MODE="${1:-lan}"

# Select caller/callee based on mode
case "$MODE" in
    lan)
        # 102 (LAN) calls 103 (LAN)
        CALLER_HOST="$HOST_102_LAN"
        CALLER_EXT="102"
        CALLEE_HOST="$HOST_103_LAN"
        CALLEE_EXT="103"
        print_scenario_lan
        ;;
    wan)
        # 102 (WAN) calls 103 (LAN)
        CALLER_HOST="$HOST_102_WAN"
        CALLER_EXT="102"
        CALLEE_HOST="$HOST_103_LAN"
        CALLEE_EXT="103"
        print_scenario_wan
        ;;
    reverse)
        # 103 (LAN) calls 102 (WAN)
        CALLER_HOST="$HOST_103_LAN"
        CALLER_EXT="103"
        CALLEE_HOST="$HOST_102_WAN"
        CALLEE_EXT="102"
        print_scenario_reverse
        ;;
    *)
        print_usage
        exit 1
        ;;
esac

echo -e "${DIM}────────────────────────────────────────────────────────────────────${NC}"
info "Caller (${CALLER_EXT}): ${MAGENTA}root@$CALLER_HOST${NC}"
info "Callee (${CALLEE_EXT}): ${MAGENTA}root@$CALLEE_HOST${NC}"
echo -e "${DIM}────────────────────────────────────────────────────────────────────${NC}"
echo ""

# Cleanup all possible hosts
step "Cleanup previous sessions..."
ssh root@$HOST_103_LAN "pkill baresip || true" 2>/dev/null
ssh root@$HOST_102_LAN "pkill baresip || true" 2>/dev/null || true
ssh root@$HOST_102_WAN "pkill baresip || true" 2>/dev/null || true
success "Cleanup done"
sleep 1

# Start callee (auto-answer)
step "Starting auto-answer on ${CALLEE_EXT}..."
ssh -f root@$CALLEE_HOST "baresip" 2>/dev/null
sleep 3
success "Extension ${CALLEE_EXT} ready (auto-answer)"

# Start caller and dial
MODE_UPPER=$(echo "$MODE" | tr '[:lower:]' '[:upper:]')
step "Dialing ${CALLEE_EXT} from ${CALLER_EXT} (${MODE_UPPER})..."
ssh root@$CALLER_HOST "baresip -e '/dial ${CALLEE_EXT}' > /tmp/baresip.log 2>&1 &" 2>/dev/null &
sleep 1
success "Call initiated"

echo ""
echo -e "${BOLD}📞 Call in progress...${NC}"
echo ""

# Countdown with progress bar
for i in {10..1}; do
    bar=""
    for ((j=0; j<i; j++)); do bar+="█"; done
    for ((j=i; j<10; j++)); do bar+="░"; done
    echo -ne "\r  ${CYAN}[$bar]${NC} ${BOLD}$i${NC} seconds remaining  "
    sleep 1
done
echo -e "\r  ${GREEN}[██████████]${NC} ${GREEN}${BOLD}Call completed!${NC}      "

echo ""

# Cleanup
step "Cleanup..."
ssh root@$CALLER_HOST "pkill baresip" 2>/dev/null || true
ssh root@$CALLEE_HOST "pkill baresip" 2>/dev/null || true
success "Sessions terminated"

echo ""
echo -e "${GREEN}"
cat << 'EOF'
    ╔══════════════════════════════════════════════════════════════════╗
    ║                    ✅ TEST COMPLETED ✅                          ║
    ╚══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
