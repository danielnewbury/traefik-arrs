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
