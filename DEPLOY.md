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

git clone https://github.com/edorguez/tourism-agency.git /opt/docker-projects/tourism-agency
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
cloudflared tunnel route dns edoutput-tunnel edoutput.dev
cloudflared tunnel route dns edoutput-tunnel www.edoutput.dev
cloudflared tunnel route dns edoutput-tunnel '*.edoutput.dev'
```

Si el CLI no acepta el wildcard, crea el registro en el dashboard de Cloudflare:

```text
Tipo: CNAME
Nombre: *
Destino: <UUID>.cfargotunnel.com
Proxy: activado
```

El certificado Universal SSL cubre `edoutput.dev` y `*.edoutput.dev` (un nivel),
por eso los tenants usan `cliente.edoutput.dev`.

Copiar las credenciales al servidor y crear el `config.yml` en la misma carpeta:

```bash
sudo mkdir -p /opt/docker-projects-data/edge/cloudflared
sudo chown -R 65532:65532 /opt/docker-projects-data/edge/cloudflared
scp ~/.cloudflared/<UUID>.json usuario@servidor:/opt/docker-projects-data/edge/cloudflared/

# La imagen oficial de cloudflared corre como UID/GID 65532.
sudo chown 65532:65532 /opt/docker-projects-data/edge/cloudflared/<UUID>.json
sudo chmod 600 /opt/docker-projects-data/edge/cloudflared/<UUID>.json
```

Crear **sin versionar** el archivo:

`/opt/docker-projects-data/edge/cloudflared/config.yml`

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

  - hostname: edoutput.dev
    service: http://portfolio-page-edge:80

  - hostname: www.edoutput.dev
    service: http://portfolio-page-edge:80

  # Tenants de business-manager.
  - hostname: "*.edoutput.dev"
    service: http://business-manager-edge:80

  - service: http_status:404
```

Permisos:

```bash
sudo chown 65532:65532 /opt/docker-projects-data/edge/cloudflared/config.yml
sudo chmod 644 /opt/docker-projects-data/edge/cloudflared/config.yml
```

`/opt/docker-projects/edge/docker-compose.yml`

```yaml
services:
  edoutput-cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: edoutput-cloudflared
    command: tunnel --config /etc/cloudflared/config.yml run
    volumes:
      # Un solo mount: config.yml y <UUID>.json viven aquí.
      - /opt/docker-projects-data/edge/cloudflared:/etc/cloudflared:ro
    networks:
      - shared-edge
    restart: unless-stopped

networks:
  shared-edge:
    external: true
    name: shared-edge
```

> No montes `./config.yml` por separado dentro de `/etc/cloudflared`: Docker no
> puede crear un mountpoint dentro de una carpeta que ya está montada read-only.

Arrancar el túnel después de los proyectos:

```bash
cd /opt/docker-projects/edge
docker compose up -d
```

## Cloudflare

- Activar **Always Use HTTPS**.
- SSL/TLS: **Full (strict)**; si aparece error 526, usar **Full**.
- No hace falta instalar certificados en el servidor.

## Portfolio (`edoutput.dev`)

El portfolio vive en `edoutput.dev` y `www.edoutput.dev`, servido por
`portfolio-page-edge:80` dentro de la red `shared-edge`.

Su despliegue está documentado en:

```text
/opt/docker-projects/portfolio-page/DEPLOY.md
```

No hay que tocar los tres proyectos actuales ni el wildcard de tenants.

