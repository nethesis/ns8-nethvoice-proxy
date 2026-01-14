# Gestione Subnet Locali - LOCAL_SOURCE_SUBNETS

## Descrizione

La funzionalità `LOCAL_SOURCE_SUBNETS` permette di definire una o più subnet da cui Kamailio riceve pacchetti SIP che **non devono** utilizzare l'indirizzo IP pubblico configurato come `advertise`.

## Scenario d'uso

In un'architettura come quella descritta dove:
- Kamailio è configurato con un IP privato (es. `192.168.0.248`) e un IP pubblico advertised (es. `88.88.88.1`)
- Ci sono client SIP esterni che si connettono via Internet (devono usare l'IP pubblico)
- Ci sono client SIP interni nella LAN locale (es. subnet `192.168.0.0/24`)

I client interni **non devono** ricevere risposte SIP con l'IP pubblico `88.88.88.1` ma con l'IP privato locale `192.168.0.248`.

## Configurazione

### Tramite API di configurazione

Durante la configurazione del modulo, è possibile specificare le subnet locali nel campo `local_source_subnets`:

```json
{
  "fqdn": "proxy.example.com",
  "addresses": {
    "address": "192.168.0.248",
    "public_address": "88.88.88.1"
  },
  "service_network": {
    "address": "10.5.4.1",
    "netmask": "10.5.4.0/24"
  },
  "local_source_subnets": [
    "192.168.0.0/24",
    "10.0.0.0/16"
  ]
}
```

### Tramite variabile d'ambiente

È possibile impostare direttamente la variabile d'ambiente `LOCAL_SOURCE_SUBNETS` con le subnet separate da virgola:

```bash
export LOCAL_SOURCE_SUBNETS="192.168.0.0/24,10.0.0.0/16"
```

## Funzionamento

Quando Kamailio riceve un pacchetto SIP:

1. Controlla il source IP (`$si`) del pacchetto
2. Verifica se il source IP appartiene a una delle subnet definite in `LOCAL_SOURCE_SUBNETS`
3. Se c'è un match:
   - Usa `set_advertised_address(PRIVATE_IP)` per quella richiesta
   - Le risposte SIP conterranno l'IP privato invece di quello pubblico
4. Se non c'è un match:
   - Usa il comportamento standard con l'IP advertised pubblico

## Esempio pratico

### Configurazione

```
PRIVATE_IP = 192.168.0.248
PUBLIC_IP = 88.88.88.1
LOCAL_SOURCE_SUBNETS = "192.168.0.0/24"
```

### Scenario 1: Client esterno (IP: 88.88.88.100)

- Il client esterno invia un INVITE a `88.88.88.1:5060`
- Kamailio riceve il pacchetto
- Source IP `88.88.88.100` NON è in `LOCAL_SOURCE_SUBNETS`
- Kamailio risponde usando l'advertised IP pubblico `88.88.88.1`

### Scenario 2: Client interno (IP: 192.168.0.50)

- Il client interno invia un INVITE a `192.168.0.248:5060`
- Kamailio riceve il pacchetto
- Source IP `192.168.0.50` è in `LOCAL_SOURCE_SUBNETS` (192.168.0.0/24)
- Kamailio **imposta l'advertised address al PRIVATE_IP** (`192.168.0.248`)
- Il client riceve risposte con IP `192.168.0.248` invece di `88.88.88.1`

## Debug

Per verificare il funzionamento, abilitare il debug in Kamailio. Nei log appariranno messaggi come:

```
[DEV] - Checking if 192.168.0.50 is in subnet: 192.168.0.0/24
[DEV] - Source IP 192.168.0.50 is in LOCAL_SOURCE_SUBNET 192.168.0.0/24, using PRIVATE_IP for advertise
```

## Note tecniche

- Il controllo viene effettuato nella route `CHECK_LOCAL_SOURCE` subito dopo `REQINIT`
- La funzione Kamailio `is_in_subnet($si, $subnet)` viene utilizzata per il matching
- Le subnet possono essere definite in notazione CIDR (es. `192.168.0.0/24`)
- Se `LOCAL_SOURCE_SUBNETS` è vuoto o non definito, la funzionalità non viene applicata
- Questa impostazione è particolarmente utile per:
  - Installazioni behind NAT con client sia interni che esterni
  - Scenari di VPN dove alcuni client sono in subnet private specifiche
  - Integrazioni con centralini locali che non devono vedere l'IP pubblico

