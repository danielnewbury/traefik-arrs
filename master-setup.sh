#!/bin/bash

# 🎄 MASTER MEDIA STACK SETUP - CREATES EVERYTHING 🎄
# One script to rule them all!
# Creates: docker-compose.yml, .env, traefik configs, acme.json, directories, pull script

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo -e "${GREEN}${BOLD}"
echo "╔═══════════════════════════════════════════════╗"
echo "║   🎄 MASTER MEDIA STACK SETUP 🎄              ║"
echo "║   Creates EVERYTHING You Need!                ║"
echo "╚═══════════════════════════════════════════════╝"
echo -e "${NC}\n"

# Helper functions
generate_api_key() {
    openssl rand -hex 16
}

generate_traefik_hash_escaped() {
    local password=$1
    if command -v htpasswd &> /dev/null; then
        htpasswd -nbB admin "$password" | sed -e 's/^admin://' | sed 's/\$/\\$/g'
    else
        docker run --rm httpd:alpine htpasswd -nbB admin "$password" 2>/dev/null | sed -e 's/^admin://' | sed 's/\$/\\$/g'
    fi
}

generate_traefik_hash_static() {
    local password=$1
    if command -v htpasswd &> /dev/null; then
        htpasswd -nbB admin "$password" | sed -e 's/^admin://'
    else
        docker run --rm httpd:alpine htpasswd -nbB admin "$password" 2>/dev/null | sed -e 's/^admin://'
    fi
}

# ============================================
# STEP 1: Collect User Input
# ============================================
echo -e "${CYAN}📝 Step 1: Interactive Configuration${NC}\n"

read -rp "   Enter Traefik Dashboard Password: " TRAEFIK_ADMIN_PASS
read -rp "   Enter qBittorrent Admin Password: " QBIT_ADMIN_PASS
read -rp "   Enter Let's Encrypt Email: " ACME_EMAIL
read -rp "   Enter PUID (default 1000): " PUID
PUID=${PUID:-1000}
read -rp "   Enter PGID (default 1000): " PGID
PGID=${PGID:-1000}

echo -e "\n${GREEN}✓${NC} Configuration collected\n"

# Generate API keys
PROWLARR_API_KEY=$(generate_api_key)
RADARR_API_KEY=$(generate_api_key)
SONARR_API_KEY=$(generate_api_key)
LIDARR_API_KEY=$(generate_api_key)
BAZARR_API_KEY=$(generate_api_key)

# Generate hashes
TRAEFIK_HASH_ESCAPED=$(generate_traefik_hash_escaped "$TRAEFIK_ADMIN_PASS")
TRAEFIK_HASH_STATIC=$(generate_traefik_hash_static "$TRAEFIK_ADMIN_PASS")

# ============================================
# STEP 2: Create .env File
# ============================================
echo -e "${CYAN}🔐 Step 2: Creating .env File${NC}\n"

cat > .env << EOF
# 🎄 Media Stack Environment Variables
# Generated: $(date)

PUID=${PUID}
PGID=${PGID}
TZ=Europe/London

TRAEFIK_ADMIN_USER=admin
TRAEFIK_ADMIN_PASS=${TRAEFIK_ADMIN_PASS}
TRAEFIK_HASH_ESCAPED=${TRAEFIK_HASH_ESCAPED}
TRAEFIK_DOMAIN=local
ACME_EMAIL=${ACME_EMAIL}

QBIT_ADMIN_USER=admin
QBIT_ADMIN_PASS=${QBIT_ADMIN_PASS}

PROWLARR_API_KEY=${PROWLARR_API_KEY}
RADARR_API_KEY=${RADARR_API_KEY}
SONARR_API_KEY=${SONARR_API_KEY}
LIDARR_API_KEY=${LIDARR_API_KEY}
BAZARR_API_KEY=${BAZARR_API_KEY}

PLEX_CLAIM=
EOF

chmod 600 .env
echo -e "${GREEN}✓${NC} .env created (chmod 600)\n"

# ============================================
# STEP 3: Create docker-compose.yml
# ============================================
echo -e "${CYAN}🐳 Step 3: Creating docker-compose.yml${NC}\n"

cat > docker-compose.yml << 'COMPOSE_EOF'
networks:
  media_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/16
  traefik_public:
    driver: bridge

volumes:
  radarr_config:
  sonarr_config:
  lidarr_config:
  readarr_config:
  prowlarr_config:
  bazarr_config:
  qbittorrent_config:
  plex_config:

services:
  traefik:
    image: traefik:latest
    container_name: traefik
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    networks:
      - traefik_public
      - media_network
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    environment:
      - TZ=${TZ}
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik/traefik.yml:/etc/traefik/traefik.yml:ro
      - ./traefik/dynamic:/etc/traefik/dynamic:ro
      - ./traefik/acme.json:/acme.json
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host(`traefik.local`)"
      - "traefik.http.routers.traefik.service=api@internal"
      - "traefik.http.routers.traefik.middlewares=auth"
      - "traefik.http.middlewares.auth.basicauth.users=${TRAEFIK_HASH_ESCAPED}"
    healthcheck:
      test: ["CMD", "traefik", "healthcheck", "--ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    restart: unless-stopped
    networks:
      - media_network
      - traefik_public
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
      - WEBUI_PORT=8090
    volumes:
      - qbittorrent_config:/config
      - ~/media/usb11tb/downloads:/data/downloads
      - ~/media/usb6tb/downloads:/data2/downloads
    ports:
      - "6881:6881"
      - "6881:6881/udp"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.qbittorrent.rule=Host(`qbit.local`)"
      - "traefik.http.routers.qbittorrent.entrypoints=websecure"
      - "traefik.http.routers.qbittorrent.tls=true"
      - "traefik.http.services.qbittorrent.loadbalancer.server.port=8090"
      - "traefik.docker.network=traefik_public"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8090"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    restart: unless-stopped
    networks:
      - media_network
      - traefik_public
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
    volumes:
      - prowlarr_config:/config
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.prowlarr.rule=Host(`prowlarr.local`)"
      - "traefik.http.routers.prowlarr.entrypoints=websecure"
      - "traefik.http.routers.prowlarr.tls=true"
      - "traefik.http.services.prowlarr.loadbalancer.server.port=9696"
      - "traefik.docker.network=traefik_public"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9696/ping"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    depends_on:
      qbittorrent:
        condition: service_healthy

  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    restart: unless-stopped
    networks:
      - media_network
      - traefik_public
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
    volumes:
      - radarr_config:/config
      - ~/media/usb11tb:/data
      - ~/media/usb6tb:/data2
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.radarr.rule=Host(`radarr.local`)"
      - "traefik.http.routers.radarr.entrypoints=websecure"
      - "traefik.http.routers.radarr.tls=true"
      - "traefik.http.services.radarr.loadbalancer.server.port=7878"
      - "traefik.docker.network=traefik_public"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:7878/ping"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 90s
    depends_on:
      prowlarr:
        condition: service_healthy

  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    restart: unless-stopped
    networks:
      - media_network
      - traefik_public
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
    volumes:
      - sonarr_config:/config
      - ~/media/usb11tb:/data
      - ~/media/usb6tb:/data2
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.sonarr.rule=Host(`sonarr.local`)"
      - "traefik.http.routers.sonarr.entrypoints=websecure"
      - "traefik.http.routers.sonarr.tls=true"
      - "traefik.http.services.sonarr.loadbalancer.server.port=8989"
      - "traefik.docker.network=traefik_public"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8989/ping"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 120s
    depends_on:
      radarr:
        condition: service_healthy

  lidarr:
    image: lscr.io/linuxserver/lidarr:latest
    container_name: lidarr
    restart: unless-stopped
    networks:
      - media_network
      - traefik_public
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
    volumes:
      - lidarr_config:/config
      - ~/media/usb11tb:/data
      - ~/media/usb6tb:/data2
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.lidarr.rule=Host(`lidarr.local`)"
      - "traefik.http.routers.lidarr.entrypoints=websecure"
      - "traefik.http.routers.lidarr.tls=true"
      - "traefik.http.services.lidarr.loadbalancer.server.port=8686"
      - "traefik.docker.network=traefik_public"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8686/api/v1/system/status"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 150s
    depends_on:
      sonarr:
        condition: service_healthy

  bazarr:
    image: lscr.io/linuxserver/bazarr:latest
    container_name: bazarr
    restart: unless-stopped
    networks:
      - media_network
      - traefik_public
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
    volumes:
      - bazarr_config:/config
      - ~/media/usb11tb:/data
      - ~/media/usb6tb:/data2
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.bazarr.rule=Host(`bazarr.local`)"
      - "traefik.http.routers.bazarr.entrypoints=websecure"
      - "traefik.http.routers.bazarr.tls=true"
      - "traefik.http.services.bazarr.loadbalancer.server.port=6767"
      - "traefik.docker.network=traefik_public"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:6767/ping"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 210s
    depends_on:
      lidarr:
        condition: service_healthy

  plex:
    image: lscr.io/linuxserver/plex:latest
    container_name: plex
    restart: unless-stopped
    network_mode: host
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
      - VERSION=docker
      - PLEX_CLAIM=${PLEX_CLAIM}
    volumes:
      - plex_config:/config
      - ~/media/usb11tb:/media
      - ~/media/usb6tb:/data2
    devices:
      - /dev/dri:/dev/dri
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:32400/identity"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 240s
    depends_on:
      bazarr:
        condition: service_healthy
COMPOSE_EOF

echo -e "${GREEN}✓${NC} docker-compose.yml created\n"

# ============================================
# STEP 4: Create Traefik Configuration
# ============================================
echo -e "${CYAN}⚡ Step 4: Creating Traefik Configs${NC}\n"

mkdir -p traefik/{dynamic,certs,logs}

# Static config
cat > traefik/traefik.yml << TRAEFIK_EOF
global:
  checkNewVersion: true
  sendAnonymousUsage: false

log:
  level: INFO
  filePath: /etc/traefik/logs/traefik.log

accessLog:
  filePath: /etc/traefik/logs/access.log

api:
  dashboard: true
  insecure: true

providers:
  docker:
    exposedByDefault: false
    network: traefik_public
  file:
    directory: /etc/traefik/dynamic
    watch: true

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

certificatesResolvers:
  le:
    acme:
      email: ${ACME_EMAIL}
      storage: /acme.json
      tlsChallenge: {}
      # For production, uncomment:
      # caServer: "https://acme-v02.api.letsencrypt.org/directory"

ping:
  entryPoint: web
TRAEFIK_EOF

echo -e "${GREEN}✓${NC} traefik/traefik.yml created"

# Dynamic config
cat > traefik/dynamic/middlewares.yml << 'DYNAMIC_EOF'
http:
  middlewares:
    security-headers:
      headers:
        browserXssFilter: true
        contentTypeNosniff: true
        forceSTSHeader: true
        frameDeny: true
        stsIncludeSubdomains: true
        stsPreload: true
        stsSeconds: 31536000

    rate-limit:
      rateLimit:
        average: 100
        burst: 50
        period: 1m

    compress:
      compress: {}
DYNAMIC_EOF

echo -e "${GREEN}✓${NC} traefik/dynamic/middlewares.yml created"

# Create acme.json with proper permissions
touch traefik/acme.json
chmod 600 traefik/acme.json
echo -e "${GREEN}✓${NC} traefik/acme.json created (chmod 600)\n"

# ============================================
# STEP 5: Create Directories
# ============================================
echo -e "${CYAN}📁 Step 5: Creating Directory Structure${NC}\n"

mkdir -p ~/media/{usb6tb,usb11tb}/{downloads/{complete,incomplete,torrents},media}
mkdir -p ~/media/usb11tb/media/{movies,tv,anime}
mkdir -p ~/media/usb6tb/media/{music,books,audiobooks}

echo -e "${GREEN}✓${NC} Media directories created\n"

# ============================================
# STEP 6: Create .gitignore
# ============================================
echo -e "${CYAN}🔒 Step 6: Creating Security Files${NC}\n"

cat > .gitignore << 'GITIGNORE_EOF'
.env
.env.*
*.key
*.pem
*.crt
*_config/
traefik/acme.json
traefik/logs/
*.bak
*.backup
media/
.DS_Store
Thumbs.db
.secrets/
CREDENTIALS.txt
GITIGNORE_EOF

echo -e "${GREEN}✓${NC} .gitignore created"

# Create secrets directory
mkdir -p .secrets
chmod 700 .secrets

echo "${TRAEFIK_ADMIN_PASS}" > .secrets/traefik_password
echo "${QBIT_ADMIN_PASS}" > .secrets/qbittorrent_password
echo "${PROWLARR_API_KEY}" > .secrets/prowlarr_api
echo "${RADARR_API_KEY}" > .secrets/radarr_api
echo "${SONARR_API_KEY}" > .secrets/sonarr_api
echo "${LIDARR_API_KEY}" > .secrets/lidarr_api
echo "${BAZARR_API_KEY}" > .secrets/bazarr_api

chmod 600 .secrets/*
echo -e "${GREEN}✓${NC} .secrets/ created\n"

# ============================================
# STEP 7: Create Credentials File
# ============================================
echo -e "${CYAN}📝 Step 7: Creating CREDENTIALS.txt${NC}\n"

cat > CREDENTIALS.txt << CRED_EOF
🎄 MEDIA STACK CREDENTIALS 🎄
==============================
Generated: $(date)

⚠️  DELETE THIS FILE AFTER RECORDING CREDENTIALS!

🔐 TRAEFIK DASHBOARD
-------------------
URL: http://traefik.local:8080
Username: admin
Password: ${TRAEFIK_ADMIN_PASS}

🌊 QBITTORRENT
-------------------
URL: https://qbit.local
Username: admin
Password: ${QBIT_ADMIN_PASS}

🔍 PROWLARR | API: ${PROWLARR_API_KEY}
🎬 RADARR   | API: ${RADARR_API_KEY}
📺 SONARR   | API: ${SONARR_API_KEY}
🎵 LIDARR   | API: ${LIDARR_API_KEY}
💬 BAZARR   | API: ${BAZARR_API_KEY}

🎥 PLEX: http://localhost:32400/web

CONFIG:
-------
PUID/PGID: ${PUID}/${PGID}
ACME Email: ${ACME_EMAIL}
CRED_EOF

chmod 600 CREDENTIALS.txt
echo -e "${GREEN}✓${NC} CREDENTIALS.txt created\n"

# ============================================
# STEP 8: Create Pull Script
# ============================================
echo -e "${CYAN}🚀 Step 8: Creating pull-images.sh${NC}\n"

cat > pull-images.sh << 'PULL_EOF'
#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Sequential Docker Image Pull ==="
echo ""

SERVICES=("traefik" "qbittorrent" "prowlarr" "radarr" "sonarr" "lidarr" "bazarr" "plex")
FAILED=()
SUCCESS=()

for service in "${SERVICES[@]}"; do
    echo -e "${YELLOW}[→]${NC} Pulling $service..."
    
    if docker compose pull "$service" 2>&1; then
        echo -e "${GREEN}[✓]${NC} $service pulled"
        SUCCESS+=("$service")
    else
        echo -e "\033[0;31m[✗]\033[0m $service failed"
        FAILED+=("$service")
    fi
    echo ""
    sleep 2
done

echo "========================================="
if [ ${#FAILED[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ All images pulled successfully!${NC}"
    echo "Ready to start: docker compose up -d"
else
    echo -e "\033[0;31m✗ Failed: ${FAILED[*]}${NC}"
    echo "Start working services: docker compose up -d ${SUCCESS[*]}"
fi
PULL_EOF

chmod +x pull-images.sh
echo -e "${GREEN}✓${NC} pull-images.sh created\n"

# ============================================
# FINAL SUMMARY
# ============================================
clear
echo -e "${GREEN}${BOLD}"
echo "╔═══════════════════════════════════════════════╗"
echo "║          🎁 SETUP COMPLETE! 🎁                ║"
echo "╚═══════════════════════════════════════════════╝"
echo -e "${NC}\n"

echo -e "${CYAN}📦 Created Files:${NC}"
echo "  ✓ docker-compose.yml"
echo "  ✓ .env (chmod 600)"
echo "  ✓ traefik/traefik.yml"
echo "  ✓ traefik/dynamic/middlewares.yml"
echo "  ✓ traefik/acme.json (chmod 600)"
echo "  ✓ .gitignore"
echo "  ✓ .secrets/ directory"
echo "  ✓ CREDENTIALS.txt (chmod 600)"
echo "  ✓ pull-images.sh (executable)"
echo "  ✓ ~/media/usb{6tb,11tb} structure"
echo ""

echo -e "${CYAN}🚀 Next Steps:${NC}"
echo "  1. Pull Docker images"
echo "  2. Start all services"
echo "  3. View credentials"
echo ""

# Ask if user wants to continue with deployment
read -p "Continue with pulling images and starting services? (y/n) " -n 1 -r
echo -e "\n"

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # ============================================
    # STEP 9: Pull Images
    # ============================================
    echo -e "${CYAN}🐋 Step 9: Pulling Docker Images${NC}\n"
    
    if [ -x ./pull-images.sh ]; then
        ./pull-images.sh
    else
        echo -e "${YELLOW}[!]${NC} Running docker compose pull..."
        docker compose pull
    fi
    
    echo ""
    
    # ============================================
    # STEP 10: Start Services
    # ============================================
    echo -e "${CYAN}🚀 Step 10: Starting Services${NC}\n"
    
    read -p "Start all services now? (y/n) " -n 1 -r
    echo -e "\n"
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker compose up -d
        
        echo ""
        echo -e "${GREEN}${BOLD}✓ All services started!${NC}\n"
        
        # Wait a moment for services to initialize
        sleep 3
        
        echo -e "${CYAN}📊 Service Status:${NC}"
        docker compose ps
        
        echo ""
    else
        echo -e "${YELLOW}[!]${NC} Skipped. Start manually with: ${GREEN}docker compose up -d${NC}"
    fi
else
    echo -e "${YELLOW}[!]${NC} Deployment skipped."
    echo ""
    echo -e "${CYAN}Manual steps:${NC}"
    echo "  1. ${GREEN}./pull-images.sh${NC}     # Pull all Docker images"
    echo "  2. ${GREEN}docker compose up -d${NC}  # Start all services"
fi

echo ""
echo -e "${CYAN}📍 Access Points (add to /etc/hosts):${NC}"
echo "  ${GREEN}echo '127.0.0.1 traefik.local prowlarr.local radarr.local sonarr.local lidarr.local bazarr.local qbit.local' | sudo tee -a /etc/hosts${NC}"
echo ""
echo -e "${CYAN}🌐 Service URLs:${NC}"
echo "  • Traefik:    http://traefik.local:8080"
echo "  • qBittorrent: https://qbit.local"
echo "  • Prowlarr:   https://prowlarr.local"
echo "  • Radarr:     https://radarr.local"
echo "  • Sonarr:     https://sonarr.local"
echo "  • Lidarr:     https://lidarr.local"
echo "  • Bazarr:     https://bazarr.local"
echo "  • Plex:       http://localhost:32400/web"
echo ""

echo -e "${YELLOW}⚠️  Security Reminders:${NC}"
echo "  • Delete CREDENTIALS.txt after saving passwords"
echo "  • Never commit .env or .secrets/ to git"
echo "  • Update ACME email if you used placeholder"
echo ""

read -p "Show credentials now? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    cat CREDENTIALS.txt
fi

echo ""
echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║   🎄 SETUP COMPLETE! HAPPY STREAMING! 🎅     ║${NC}"
echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════╝${NC}"
echo ""