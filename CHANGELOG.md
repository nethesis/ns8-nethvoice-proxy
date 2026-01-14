# CHANGELOG

All notable changes to this module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Types of changes

`Added` for new features.
`Changed` for changes in existing functionality.
`Deprecated` for soon-to-be removed features.
`Removed` for now removed features.
`Fixed` for any bug fixes.
`Security` in case of vulnerabilities.

---

## [Unreleased]

### Added

- `kamailio` module folder
- `postgres` module folder
- `redis` module folder
- `rtpengine` module folder
- basic structure of folders and files (`modules`, `.env.template`, `.gitignore`, `CHANGELOG.md`, ...)
- **LOCAL_SOURCE_SUBNETS**: Nuova funzionalità per gestire subnet locali che non devono utilizzare l'advertised IP pubblico. Permette di configurare una o più subnet (separate da virgola) da cui i pacchetti SIP ricevuti non useranno l'IP pubblico advertised ma l'IP privato locale. Utile per scenari con client SIP sia interni (LAN) che esterni (Internet).
