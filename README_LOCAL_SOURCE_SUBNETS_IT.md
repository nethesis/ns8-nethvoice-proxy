# LOCAL_SOURCE_SUBNETS - Gestione Subnet Locali

## 📋 Panoramica

Funzionalità che permette di gestire pacchetti SIP provenienti da subnet locali in modo differente rispetto ai pacchetti esterni, senza dover utilizzare l'advertised IP pubblico per le risposte ai client interni.

## 🎯 Problema Risolto

Nell'architettura attuale:

```
Internet (88.88.88.1/24) 
    ↓
Router1 (NAT)
    ↓
LAN Switch (192.168.0.0/24)
    ↓
    ├─ NethServer (192.168.0.248) → Kamailio
    └─ PC con Softphone (192.168.0.50)
```

**Situazione precedente:**
- Kamailio configurato con:
  - `PRIVATE_IP = 192.168.0.248`
  - `PUBLIC_IP = 88.88.88.1` (advertised)
- **Problema**: TUTTI i client (interni ed esterni) ricevevano risposte SIP con IP `88.88.88.1`
- I client interni (192.168.0.50) non potevano comunicare correttamente perché ricevevano IP pubblico

**Soluzione implementata:**
- Definire subnet locali in `LOCAL_SOURCE_SUBNETS`
- I client in queste subnet ricevono risposte con IP privato `192.168.0.248`
- I client esterni continuano a ricevere risposte con IP pubblico `88.88.88.1`

## 🚀 Configurazione

### Esempio Base

```json
{
  "fqdn": "proxy.nethvoice.local",
  "addresses": {
    "address": "192.168.0.248",
    "public_address": "88.88.88.1"
  },
  "service_network": {
    "address": "10.5.4.1",
    "netmask": "10.5.4.0/24"
  },
  "local_source_subnets": [
    "192.168.0.0/24"
  ]
}
```

### Con Subnet Multiple

```json
{
  "local_source_subnets": [
    "192.168.0.0/24",
    "192.168.1.0/24",
    "10.0.0.0/16"
  ]
}
```

## 📊 Come Funziona

```
Pacchetto SIP da 192.168.0.50 → Kamailio
    ↓
Verifica: 192.168.0.50 ∈ 192.168.0.0/24? → SÌ
    ↓
set_advertised_address(192.168.0.248)
    ↓
Risposta SIP con IP: 192.168.0.248 ✓
```

```
Pacchetto SIP da 88.88.88.100 → Kamailio
    ↓
Verifica: 88.88.88.100 ∈ 192.168.0.0/24? → NO
    ↓
Usa advertised IP normale
    ↓
Risposta SIP con IP: 88.88.88.1 ✓
```

## 🔧 Verifica Configurazione

```bash
# Visualizza variabile d'ambiente nel modulo
cat ~/.config/state/environment | grep LOCAL_SOURCE_SUBNETS

# Visualizza nel container Kamailio
docker exec kamailio env | grep LOCAL_SOURCE_SUBNETS

# Verifica configurazione generata
docker exec kamailio cat /tmp/kamailio-local.cfg | grep LOCAL_SOURCE_SUBNETS
```

## 📝 Debug

Abilitare debug in Kamailio per vedere nei log:

```
[DEV] - Checking if 192.168.0.50 is in subnet: 192.168.0.0/24
[DEV] - Source IP 192.168.0.50 is in LOCAL_SOURCE_SUBNET 192.168.0.0/24, using PRIVATE_IP for advertise
```

## ⚠️ Note Importanti

- ✅ **100% compatibile** con configurazioni esistenti
- Subnet in notazione CIDR: `192.168.0.0/24`
- Subnet multiple separate da virgola
- Se non definito o vuoto → comportamento invariato

## 📚 Documentazione

- Dettagli tecnici: `docs/LOCAL_SOURCE_SUBNETS.md`
- Test: `tests/10_actions/15_configure_local_source_subnets.robot`
- Esempi: `examples/configure-with-local-subnets.json`

## 📄 Licenza

Copyright (C) 2023 Nethesis S.r.l.
SPDX-License-Identifier: GPL-3.0-or-later

