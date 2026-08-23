# Add-on-Build fuer Home Assistant Supervisor: Postgres + FastAPI-Backend im
# selben Container, analog zum bestehenden Unraid-Einzelcontainer-Dockerfile
# in Lademonitor-Server (bewusst KEIN s6-overlay/HA-Base-Image - siehe
# config.yaml, run.sh uebernimmt die PID1-Rolle selbst wie entrypoint.sh dort).
# Backend-Code kommt per Git-Submodule aus Lademonitor-Server (Pfad
# server/, siehe .gitmodules im Repo-Root) statt kopiert zu werden, um Drift
# zwischen Server- und Add-on-Repo zu vermeiden.
ARG BUILD_FROM
FROM ${BUILD_FROM}

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      python3 python3-pip python3-venv build-essential && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY server/backend/requirements.txt .
RUN python3 -m venv /venv && /venv/bin/pip install --no-cache-dir -r requirements.txt

COPY server/backend/app ./app
COPY run.sh /run.sh
RUN chmod +x /run.sh

# Fest verdrahtete Zugangsdaten fuer die interne, nicht nach aussen
# exponierte Postgres-Instanz (nur via localhost im selben Container
# erreichbar) - identisch zur Begruendung im Root-Dockerfile des Server-Repos
ENV POSTGRES_USER=charging \
    POSTGRES_PASSWORD=charging \
    POSTGRES_DB=charging \
    DATABASE_URL=postgresql+psycopg://charging:charging@localhost:5432/charging \
    PATH="/venv/bin:${PATH}"

EXPOSE 8000
ENTRYPOINT ["/run.sh"]
