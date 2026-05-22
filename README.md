# Robot Asistente (JOY) + monitoreo en en la nube

Aplicación Flutter para controlar el robot (WiFi, Bluetooth, modo autónomo con IA). Incluye una **pila de monitoreo** (backend + MongoDB + dashboard web) en Docker, alineada al proyecto final de Sistemas Operativos II.

## Dirección IP pública del servidor

Sustituye por la IP de tu droplet de DigitalOcean (ejemplo de referencia: `142.93.3.189`).

- **Dashboard web (HTTP):** `http://TU_IP/`
- **API de eventos (HTTP):** `http://TU_IP:8080/`

En el panel de DigitalOcean, abre los puertos **80** y **8080** (Firewall / Networking → Inbound rules).

## Diseño de la arquitectura

```mermaid
flowchart LR
  subgraph phone[Teléfono Android]
    App[App Flutter]
  end
  subgraph droplet[Servidor Ubuntu / DigitalOcean]
    subgraph docker[Docker Compose]
      FE[Nginx + dashboard]
      BE[Node.js API]
      DB[(MongoDB)]
    end
  end
  App -->|"POST /api/events"| BE
  FE -->|"GET /api/events vía proxy"| BE
  BE --> DB
```

Flujo: la app envía eventos (comandos, ping, parada segura) al backend; el backend persiste en MongoDB; el navegador consulta el mismo API a través del frontend (proxy `/api/`).

## Tecnologías utilizadas

| Componente | Tecnología |
|------------|------------|
| App móvil | Flutter (Dart), paquete `http` |
| Backend | Node.js 20, Express, controlador MongoDB oficial |
| Base de datos | MongoDB 7 en contenedor |
| Frontend | HTML/CSS/JS estático servido por Nginx |
| Orquestación | Docker Compose |

Código de la pila: carpeta `monitoring/`.

## Instrucciones de uso

### 1. Servidor (Ubuntu en DigitalOcean)

1. Instala Docker y el plugin Compose ([documentación oficial](https://docs.docker.com/engine/install/ubuntu/)).
2. **Importante (requisito del enunciado):** MongoDB debe ir **en Docker**. Si instalaste MongoDB en el sistema (`mongod`), detén el servicio para ahorrar RAM en droplets pequeños:  
   `sudo systemctl disable --now mongod`
3. Sube la carpeta `monitoring/` al servidor (por ejemplo con `scp` o clonando tu repositorio).
4. En el servidor:

```bash
cd monitoring
docker compose up -d --build
```

5. Comprueba contenedores: `docker compose ps`  
   Salud del API: `curl -s http://127.0.0.1:8080/health`

### 2. App Flutter: enviar eventos al backend

Compila o ejecuta definiendo la URL base del API (puerto **8080**):

```bash
flutter run --dart-define=EVENT_LOG_URL=http://TU_IP:8080
```

Si no defines `EVENT_LOG_URL`, la app funciona igual pero **no** envía eventos al servidor.

### 3. Guía rápida para la demostración (pausar contenedores)

Desde `monitoring/`:

| Qué demostrar | Comando |
|----------------|---------|
| Sin backend no hay registro | `docker compose stop backend` → enviar desde la app; luego `docker compose start backend` |
| Sin base de datos: se recibe pero no guarda | `docker compose stop mongo` (el backend puede devolver error 500 al guardar) |
| Sin frontend: no hay dashboard, el API sigue | `docker compose stop frontend` → la app puede seguir enviando a `:8080` |

## Estructura del repositorio

- `lib/` — código Flutter.
- `monitoring/docker-compose.yml` — tres servicios en contenedores.
- `monitoring/backend/` — API REST.
- `monitoring/frontend/` — dashboard web.

## Getting Started (Flutter)

Para desarrollo local del cliente móvil, consulta la [documentación de Flutter](https://docs.flutter.dev/).
