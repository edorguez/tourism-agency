# Despliegue de tourism-agency

## URLs

- Local: `http://localhost:8081`
- Público: `https://tourism-agency.edoutput.dev`

## Requisitos

- Docker Engine + Compose v2
- Red compartida `shared-edge`
- `cloudflared` solo para crear el túnel y los DNS (el túnel corre en Docker en el servidor)

## Prueba local

```bash
docker network inspect shared-edge >/dev/null 2>&1 || docker network create shared-edge
cp .env.example .env
docker compose up -d --build
```

Verificar:

```bash
curl -f http://localhost:8081/healthz
curl -I http://localhost:8081
```

## Servidor

```bash
sudo mkdir -p /opt/docker-projects /opt/docker-projects-data
sudo chown -R "$USER":"$USER" /opt/docker-projects /opt/docker-projects-data

git clone https://github.com/EdoRguez/tourism-agency.git /opt/docker-projects/tourism-agency
cd /opt/docker-projects/tourism-agency

cp .env.example .env
./deploy/bootstrap.sh
docker compose up -d --build
```

## Cloudflare Tunnel

Crear el túnel una sola vez desde una máquina con navegador:

```bash
brew install cloudflared
cloudflared tunnel login
cloudflared tunnel create edoutput-tunnel
cloudflared tunnel list
```

Crear los DNS:

```bash
cloudflared tunnel route dns edoutput-tunnel tourism-agency.edoutput.dev
cloudflared tunnel route dns edoutput-tunnel gps-medical-assistance.edoutput.dev
cloudflared tunnel route dns edoutput-tunnel business-manager.edoutput.dev
cloudflared tunnel route dns edoutput-tunnel www.edoutput.dev
cloudflared tunnel route dns edoutput-tunnel '*.edoutput.dev'
```

Copiar las credenciales al servidor:

```bash
sudo mkdir -p /opt/docker-projects-data/edge/cloudflared
sudo chown -R "$USER":"$USER" /opt/docker-projects-data/edge
scp ~/.cloudflared/<UUID>.json usuario@servidor:/opt/docker-projects-data/edge/cloudflared/

# La imagen oficial de cloudflared corre como UID/GID 65532.
sudo chown 65532:65532 /opt/docker-projects-data/edge/cloudflared/<UUID>.json
sudo chmod 600 /opt/docker-projects-data/edge/cloudflared/<UUID>.json
```

En el servidor, crear **sin versionar**:

`/opt/docker-projects/edge/config.yml`

```yaml
tunnel: <UUID>
credentials-file: /etc/cloudflared/<UUID>.json

ingress:
  - hostname: tourism-agency.edoutput.dev
    service: http://tourism-agency-edge:80

  - hostname: gps-medical-assistance.edoutput.dev
    service: http://gps-medical-assistance-edge:80

  - hostname: business-manager.edoutput.dev
    service: http://business-manager-edge:80

  # Reservado para el portfolio futuro.
  - hostname: www.edoutput.dev
    service: http_status:404

  # Tenants de business-manager.
  - hostname: "*.edoutput.dev"
    service: http://business-manager-edge:80

  - service: http_status:404
```

Permisos del archivo de configuración (no contiene secretos, pero cloudflared debe poder leerlo):

```bash
sudo chown 65532:65532 /opt/docker-projects/edge/config.yml
sudo chmod 644 /opt/docker-projects/edge/config.yml
```

`/opt/docker-projects/edge/docker-compose.yml`

```yaml
services:
  edoutput-cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: edoutput-cloudflared
    command: tunnel --config /etc/cloudflared/config.yml run
    volumes:
      - ./config.yml:/etc/cloudflared/config.yml:ro
      - /opt/docker-projects-data/edge/cloudflared:/etc/cloudflared:ro
    networks:
      - shared-edge
    restart: unless-stopped

networks:
  shared-edge:
    external: true
    name: shared-edge
```

Arrancar el túnel después de los tres proyectos:

```bash
cd /opt/docker-projects/edge
docker compose up -d
```

## Cloudflare

- Activar **Always Use HTTPS**.
- SSL/TLS: **Full (strict)**; si aparece error 526, usar **Full**.
- No hace falta instalar certificados en el servidor.

## Portfolio futuro (`edoutput.dev`)

El apex `edoutput.dev` y `www.edoutput.dev` quedan reservados para el portfolio.
Hoy `www` responde 404 a propósito y el apex no tiene ruta en el túnel.

Cuando exista el proyecto `portfolio`:

1. Añadir su edge a la red `shared-edge`.
2. En `/opt/docker-projects/edge/config.yml`, antes del wildcard, agregar:

```yaml
  - hostname: edoutput.dev
    service: http://portfolio-edge:80

  - hostname: www.edoutput.dev
    service: http://portfolio-edge:80
```

3. Crear el DNS del apex:

```bash
cloudflared tunnel route dns edoutput-tunnel edoutput.dev
```

No hace falta tocar los tres proyectos actuales.

