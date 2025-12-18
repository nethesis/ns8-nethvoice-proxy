#!/bin/bash

# Script di test per verificare la funzionalità LOCAL_SOURCE_SUBNETS
# Questo script simula la configurazione del modulo con subnet locali

echo "=========================================="
echo "Test LOCAL_SOURCE_SUBNETS Configuration"
echo "=========================================="
echo ""

# Colori per output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configurazione di esempio
MODULE_ID="${1:-nethvoice-proxy1}"

echo -e "${YELLOW}Step 1: Configurazione modulo con local_source_subnets${NC}"
echo ""

CONFIG_JSON=$(cat <<'EOF'
{
  "fqdn": "proxy.nethvoice.local",
  "lets_encrypt": false,
  "addresses": {
    "address": "192.168.0.248",
    "public_address": "88.88.88.1"
  },
  "service_network": {
    "address": "10.5.4.1",
    "netmask": "10.5.4.0/24"
  },
  "local_networks": [
    "192.168.0.0/24",
    "10.5.4.0/24"
  ],
  "local_source_subnets": [
    "192.168.0.0/24"
  ]
}
EOF
)

echo "Configurazione da applicare:"
echo "$CONFIG_JSON" | jq .
echo ""

# Uncomment per eseguire realmente la configurazione
# echo "$CONFIG_JSON" | api-cli run module/${MODULE_ID}/configure-module --data -

echo -e "${YELLOW}Step 2: Verifica configurazione${NC}"
echo ""

# Uncomment per leggere la configurazione attuale
# api-cli run module/${MODULE_ID}/get-configuration | jq .output

echo -e "${GREEN}✓ Per applicare questa configurazione, decommentare i comandi nel script${NC}"
echo ""

echo "=========================================="
echo "Verifica manuale in Kamailio"
echo "=========================================="
echo ""
echo "1. Connettersi al container Kamailio:"
echo "   podman exec -it kamailio bash"
echo ""
echo "2. Verificare la variabile d'ambiente:"
echo "   echo \$LOCAL_SOURCE_SUBNETS"
echo ""
echo "3. Verificare la configurazione di Kamailio:"
echo "   grep LOCAL_SOURCE_SUBNETS /tmp/kamailio-local.cfg"
echo ""
echo "4. Verificare i log durante una chiamata di test:"
echo "   tail -f /var/log/kamailio.log | grep 'LOCAL_SOURCE'"
echo ""
echo "5. Per testare con client interno (192.168.0.50):"
echo "   - Configurare un softphone con IP nella subnet 192.168.0.0/24"
echo "   - Effettuare una chiamata"
echo "   - Verificare nei messaggi SIP che l'IP usato sia 192.168.0.248 (non 88.88.88.1)"
echo ""
echo "6. Per testare con client esterno:"
echo "   - Configurare un softphone con IP esterno"
echo "   - Effettuare una chiamata"
echo "   - Verificare nei messaggi SIP che l'IP usato sia 88.88.88.1"
echo ""

echo -e "${GREEN}✓ Test completato${NC}"

