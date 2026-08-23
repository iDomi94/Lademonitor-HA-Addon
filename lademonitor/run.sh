#!/usr/bin/env bash
set -e

# Persistentes Datenverzeichnis - /data ist der von Supervisor pro Add-on
# bereitgestellte, automatisch per Snapshot gesicherte Pfad (Aequivalent zum
# /config-Pfad-Mapping im Unraid-Einzelcontainer-Dockerfile des Server-Repos).
# Eigenes Unterverzeichnis statt /data direkt, damit Postgres nicht ueber
# /data/options.json oder andere Supervisor-Dateien im PGDATA-Wurzel stolpert.
export PGDATA=/data/postgres
mkdir -p "$PGDATA"

LOG_LEVEL="info"
if [ -f /data/options.json ]; then
  LOG_LEVEL=$(python3 -c "import json; print(json.load(open('/data/options.json')).get('log_level', 'info'))" 2>/dev/null || echo "info")
fi

# Delegiert Initialisierung (initdb beim allerersten Start) und den
# root->postgres-Nutzerwechsel an das offizielle Postgres-Entrypoint-Skript -
# laeuft im Hintergrund, damit uvicorn im selben Container als zweiter
# Prozess starten kann (identischer Ansatz wie entrypoint.sh im Server-Repo).
docker-entrypoint.sh postgres &
PG_PID=$!

echo "Warte auf Postgres..."
until pg_isready -h localhost -U "$POSTGRES_USER" >/dev/null 2>&1; do
  sleep 1
done
echo "Postgres bereit, starte Backend (log level: $LOG_LEVEL)."

/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 --log-level "$LOG_LEVEL" &
APP_PID=$!

# Stirbt einer der beiden Prozesse, soll der ganze Container stoppen -
# Supervisors Restart-Policy startet ihn dann komplett neu, statt dass die
# App weiterlaeuft, obwohl z.B. Postgres abgestuerzt ist.
wait -n "$PG_PID" "$APP_PID"
exit $?
