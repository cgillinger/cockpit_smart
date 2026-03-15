# cockpit-smart — SMART Diskstatus för Cockpit

Cockpit-plugin som visar S.M.A.R.T.-hälsa och attribut för alla anslutna diskar.

## Funktioner

- Hälsostatus (PASSED/FAILED) per disk
- Automatisk identifiering av disktyp (HDD/SSD/NVMe)
- Nyckelattribut markerade (reallocated sectors, pending sectors, etc.)
- NVMe-specifika attribut (available spare, percentage used, media errors)
- Varningsmarkeringar för kritiska värden
- Expanderbara detaljer för alla SMART-attribut
- Manuell uppdatering via knapp

## Diskar som visas (server2)

| Disk | Typ | Enhet |
|------|-----|-------|
| Intel SSD 520 120GB | SSD | /dev/sda |
| Samsung PM9C1 512GB | NVMe | /dev/nvme0n1 |
| WD Green 3TB | HDD | /dev/sdb |
| WD Red Plus 6TB | HDD | /dev/sdc |

## Installation

```bash
# På server2 (192.168.50.8)
sudo bash install.sh
```

Kräver: `smartmontools`, `python3`, `cockpit`

## Åtkomst

- LAN: `https://192.168.50.8:9090/cockpit-smart/`
- Tailscale: `https://100.105.110.22:9090/cockpit-smart/`

Alternativt: Klicka "SMART Status" i Cockpit-menyn.

## Filstruktur

```
cockpit-smart/
├── manifest.json              # Cockpit plugin-manifest
├── index.html                 # UI (HTML + CSS + JS)
├── scripts/
│   └── smart-collect.sh       # Datainsamling (smartctl → JSON)
├── install.sh                 # Installationsskript
└── README.md
```

## Hur det fungerar

1. `index.html` använder `cockpit.spawn()` för att köra `smart-collect.sh` med superuser-rättigheter
2. `smart-collect.sh` kör `smartctl` mot alla diskar och samlar info/hälsa/attribut
3. Output tolkas som JSON och renderas som kort per disk i webbgränssnittet

## Testning utan Cockpit

Öppna `index.html` direkt i en webbläsare — den faller tillbaka på mockdata som matchar server2:s diskar.
