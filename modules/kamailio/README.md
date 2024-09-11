# Kamailio container

## Environment variables

- `KML_INTERNAL_NETWORK` Comma sepaated list of internal ip addresses. Example: "10.18.0.7,192.168.1.123" or "192.168.1.123"
- `KML_SERVER_HEADER` DESC. Example: "NethServer 8 nethvoice-proxy1"
- `KML_SIP_URL` DESC. Example: "127.0.0.1"
- `KML_UA_HEADER` DESC. Example: "NethServer 8 nethvoice-proxy1"
- `POSTGRES_DB` Kamailio Postgres DB backend name. Example: "kamailio"
- `POSTGRES_HOST` Kamailio Postgres DB backend host. Example: "127.0.0.1"
- `POSTGRES_PASSWORD` Kamailio Postgres DB backend password. Example: "MySuperSecurePassword"
- `POSTGRES_PORT` Kamailio Postgres DB backend port. Example: "20011"
- `POSTGRES_USER` Kamailio Postgres DB backend username. Example: "postgres"
- `PUBLIC_IP` Public IP of Kamailio. Example: "80.11.11.11"
- `REDIS_HOST` Redis DB backend host. Example: "127.0.0.1"
- `REDIS_PORT` Redis DB backend port. Example: "20012"
- `RTP_PORT_MIN` Kamailio RTP port range start. Example: "10000"
- `RTP_PORT_MAX` Kamailio RTP port range end. Example: "20000"
- `SIP_PORT` Kamailio SIP port. Example: "5060"
