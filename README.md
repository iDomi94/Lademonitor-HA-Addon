# Lademonitor – Home Assistant Add-on

**Sprache:** Deutsch | [English](README.en.md)

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

> **Dazu passend:** [Lademonitor-HA](https://github.com/iDomi94/Lademonitor-HA)
> (HACS-Integration) holt Statistik-Sensoren (Kosten/Verbrauch/km) direkt in
> HA und ersetzt den bisherigen `rest_command`-Aufruf mit manuellem
> Bearer-Token durch einen normalen Service
> (`lademonitor.push_charging_session`) – deren README enthält eine
> vollständige Beispiel-Automation. Läuft der Server als dieses Add-on auf
> derselben HA-Instanz, als Server-URL einfach `http://localhost:8000`
> (interner Add-on-Port) oder die HA-IP mit Port `8111` eintragen.

## Netzwerkzugriff (lokal vs. extern)

Sowohl der Ingress-Zugriff (Sidebar-Button) als auch der Direktport `8111`
funktionieren nur innerhalb des lokalen Netzwerks deines Home-Assistant-
Servers – keiner der beiden Wege macht die App automatisch von außerhalb
erreichbar.

- **Ingress** ist zudem kein Ersatz für einen echten API-Zugang: Die
  Sidebar-URL ist an eine eingeloggte HA-Browser-Session gebunden
  (Token pro Session) und daher für eigenständige API-Clients wie die
  [iOS-App](https://github.com/iDomi94/Lademonitor-App) nicht nutzbar –
  die App muss immer den Direktport ansprechen.
- Für Zugriff von unterwegs (z.B. die iOS-App außerhalb des Heimnetzes)
  gibt es zwei Wege:
  1. **VPN ins Heimnetz** (z.B. WireGuard) – einfachste und empfohlene
     Lösung, kein zusätzlicher öffentlicher Port nötig.
  2. **Eigener Reverse-Proxy/Nginx-Vhost** (eigene Subdomain mit TLS),
     der auf `http://<home-assistant-ip>:8111` zeigt – analog zum
     bisherigen Unraid+Nginx-Setup. Falls du Home Assistant selbst
     schon per Nginx nach außen gibst, reicht das dafür **nicht** aus:
     dieser Proxy zeigt in der Regel nur auf HAs eigenen Port (8123,
     inkl. der darüber laufenden Ingress-Pfade), nicht auf 8111 – dafür
     braucht es einen eigenen, zusätzlichen Server-/Location-Block.
  3. Bei öffentlicher Erreichbarkeit unbedingt den Sicherheitshinweis im
     [Server-Repo](https://github.com/iDomi94/Lademonitor-Server#sicherheitshinweis)
     beachten (u.a. kein Rate-Limiting auf Login/Registrierung).

## Daten & Backup

Alle Daten (komplette Postgres-Datenbank) liegen unter dem von Supervisor
verwalteten `/data`-Pfad des Add-ons und sind damit Teil regulärer
HA-Backups/Snapshots. Zusätzlich gibt es weiterhin den eingebauten
Export/Import (Einstellungen → Daten-Backup im Web-UI) für portable
CSV-Backups.

## Aufbau dieses Repos

```
repository.yaml       - Add-on-Repository-Metadaten für Supervisor
.github/workflows/
  check-server-release.yml - prueft periodisch auf neue Lademonitor-Server-
                              Releases, aktualisiert Submodule + Version, taggt
  build.yml                 - baut bei jedem v*.*.*-Tag das Multi-Arch-Image
                              und veroeffentlicht es nach GHCR
lademonitor/
  config.yaml           - Add-on-Konfiguration (image, Ports, Ingress, Optionen)
  build.yaml              - Basis-Image pro Architektur (nur fuer lokale Builds/CI)
  Dockerfile                - Baut Backend + Postgres in einem Image
  run.sh                      - Entrypoint: startet Postgres + uvicorn
  server/                      - Git-Submodule -> Lademonitor-Server
                              (liefert backend/app + requirements.txt)
```

**Wie bei [Wealth Dashboard](https://github.com/halvar20000/wealth-dashboard)**
baut Supervisor nichts mehr selbst auf dem Home-Assistant-Host: `config.yaml`
referenziert unter `image:` ein fertiges, vorgebautes Multi-Arch-Image aus
GHCR (`ghcr.io/idomi94/lademonitor-addon`), Supervisor zieht nur noch den zur
`version` passenden Tag.

`server/` bleibt dabei ein Git-Submodule, kein kopierter Code, um Drift
zwischen Server- und Add-on-Repo im Quellcode zu vermeiden – gehalten wird es
aber nicht mehr von Hand, sondern automatisch:

1. `check-server-release.yml` läuft alle 6 Stunden (und manuell per
   „Run workflow“) und prüft das neueste `v*.*.*`-Release von
   `Lademonitor-Server`.
2. Bei einer neuen Version setzt es den Submodule-Pointer auf genau diesen
   Tag, hebt `version` in `lademonitor/config.yaml` auf denselben Stand an
   und pusht einen passenden Git-Tag (z.B. `v0.19.0`).
3. Dieser Tag löst `build.yml` aus: Multi-Arch-Build (amd64/aarch64) und
   Push nach `ghcr.io/idomi94/lademonitor-addon:<version>` (+ `:latest`).
4. Supervisor zeigt danach auf allen Installationen ein Update an – Add-on-
   und Server-Version sind damit immer identisch, ganz ohne manuellen
   Submodule-Bump.

Einmalig nötig, damit die Workflows funktionieren: In den
Repository-Einstellungen unter **Settings → Actions → General → Workflow
permissions** „Read and write permissions“ aktivieren (für den Git-Tag-Push
und den GHCR-Push mit dem Standard-`GITHUB_TOKEN`), und das entstehende
GHCR-Package einmal auf „Public“ stellen, damit Supervisor es ohne Login
ziehen kann.

## Lokal bauen/testen

```bash
cd lademonitor
docker build --build-arg BUILD_FROM=postgres:16 -t lademonitor-addon-test .
docker run --rm -p 8111:8000 -v "$(pwd)/testdata:/data" lademonitor-addon-test
```

Ein vollständiger Supervisor-Test (Ingress, Snapshots, Multi-Arch-Build) ist
nur auf echter Home-Assistant-OS-Hardware möglich.
