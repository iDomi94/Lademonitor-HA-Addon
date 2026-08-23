# Lademonitor – Home Assistant Add-on

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](LICENSE)

Home-Assistant-Supervisor-Add-on-Repository für
[Lademonitor-Server](https://github.com/iDomi94/Lademonitor-Server)
(selbstgehostete Ladevorgang-Tracking-App für ein E-Auto). Läuft direkt
innerhalb von Home Assistant OS/Supervised, als Alternative zum bisherigen
Unraid-Einzelcontainer-Deployment – gleicher Container-Ansatz (Backend +
Postgres in einem Image), nur mit Supervisor-Konventionen (`/data`-Pfad,
Ingress) statt manuellem Docker-Run.

## Installation

1. **Einstellungen → Add-ons → Add-on-Store → ⋮ → Repositories**
2. URL dieses Repos eintragen: `https://github.com/iDomi94/Lademonitor-HA-Addon`
3. "Lademonitor" installieren, danach starten
4. Web-UI über den Sidebar-Eintrag (Ingress) oder direkt über
   `http://<home-assistant-ip>:8111` erreichbar
5. Ersten Account registrieren (`/register`) – wird automatisch Admin,
   siehe Haupt-Repo für die weiteren Schritte (Fahrzeug anlegen etc.)

Für die HACS-Integration (Statistik-Sensoren + vereinfachter Push aus HA-
Automationen) siehe separat:
[Lademonitor-HA](https://github.com/iDomi94/Lademonitor-HA)

## Daten & Backup

Alle Daten (komplette Postgres-Datenbank) liegen unter dem von Supervisor
verwalteten `/data`-Pfad des Add-ons und sind damit Teil regulärer
HA-Backups/Snapshots. Zusätzlich gibt es weiterhin den eingebauten
Export/Import (Einstellungen → Daten-Backup im Web-UI) für portable
CSV-Backups.

## Aufbau dieses Repos

```
repository.yaml       - Add-on-Repository-Metadaten für Supervisor
lademonitor/
  config.yaml           - Add-on-Konfiguration (Ports, Ingress, Optionen)
  build.yaml              - Basis-Image pro Architektur
  Dockerfile                - Baut Backend + Postgres in einem Image
  run.sh                      - Entrypoint: startet Postgres + uvicorn
  server/                      - Git-Submodule -> Lademonitor-Server
                              (liefert backend/app + requirements.txt)
```

`server/` ist ein Git-Submodule, kein kopierter Code – vermeidet Drift
zwischen Server- und Add-on-Repo. Nach einem Update von
`Lademonitor-Server` den Submodule-Pointer aktualisieren:

```bash
git submodule update --remote lademonitor/server
git add lademonitor/server
git commit -m "Server-Submodule aktualisieren"
```

und die `version` in `lademonitor/config.yaml` entsprechend erhöhen (nötig,
damit Supervisor ein Update anzeigt).

## Lokal bauen/testen

```bash
cd lademonitor
docker build --build-arg BUILD_FROM=postgres:16 -t lademonitor-addon-test .
docker run --rm -p 8111:8000 -v "$(pwd)/testdata:/data" lademonitor-addon-test
```

Ein vollständiger Supervisor-Test (Ingress, Snapshots, Multi-Arch-Build) ist
nur auf echter Home-Assistant-OS-Hardware möglich.
