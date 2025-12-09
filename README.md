# 🎄 Complete Media Stack with Traefik

A fully automated, secure, and production-ready media server stack featuring Traefik reverse proxy, the *arr suite, qBittorrent, and Plex.

## 🎁 What's Included

### Core Services
- **Traefik** - Reverse proxy with automatic HTTPS
- **qBittorrent** - Torrent download client
- **Prowlarr** - Indexer manager
- **Radarr** - Movie management
- **Sonarr** - TV show management
- **Lidarr** - Music management
- **Bazarr** - Subtitle management
- **Plex** - Media server with hardware transcoding

### Features
✅ Automatic SSL/TLS with Let's Encrypt  
✅ Secure password generation and storage  
✅ Proper file permissions (chmod 600 for secrets)  
✅ Staggered container startup to avoid rate limits  
✅ Health checks and dependency management  
✅ Isolated Docker networks  
✅ Git-safe with .gitignore protection  
✅ Complete automation - one script does everything  

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose installed
- Two USB drives mounted at `~/media/usb6tb` and `~/media/usb11tb`
- Ports 80, 443, 8080, 6881 available

### One-Command Setup

```bash
chmod +x master-setup.sh
./master-setup.sh
```

The script will:
1. Ask for your credentials (interactive)
2. Generate all configuration files
3. Create directory structure
4. Pull Docker images
5. Start all services
6. Display access URLs and credentials

**That's it!** ☕

## 📁 Directory Structure

```
.
├── docker-compose.yml          # Main compose file
├── .env                        # Environment variables (chmod 600)
├── .gitignore                  # Git protection
├── master-setup.sh             # Main setup script
├── pull-images.sh              # Sequential image puller
├── CREDENTIALS.txt             # Generated credentials (delete after use)
├── .secrets/                   # Individual secret files (chmod 700)
│   ├── traefik_password
│   ├── qbittorrent_password
│   └── *_api keys
├── traefik/
│   ├── traefik.yml             # Static configuration
│   ├── acme.json               # SSL certificates (chmod 600)
│   ├── dynamic/
│   │   └── middlewares.yml     # Security headers, rate limits
│   └── logs/
└── ~/media/
    ├── usb11tb/
    │   ├── downloads/          # qBittorrent downloads
    │   │   ├── complete/
    │   │   ├── incomplete/
    │   │   └── torrents/
    │   └── media/
    │       ├── movies/
    │       ├── tv/
    │       └── anime/
    └── usb6tb/
        ├── downloads/
        └── media/
            ├── music/
            ├── books/
            └── audiobooks/
```

## 🔐 Security Features

### Password Management
- **Auto-generated passwords** - Cryptographically secure random strings
- **Bcrypt hashes** - For Traefik dashboard authentication
- **Separate storage** - `.secrets/` directory with chmod 700
- **Git-protected** - All sensitive files in `.gitignore`

### File Permissions
```bash
.env              # 600 (read/write owner only)
.secrets/*        # 600 (read/write owner only)
traefik/acme.json # 600 (required by Traefik)
CREDENTIALS.txt   # 600 (delete after recording)
```

### Network Isolation
- **media_network** (172.28.0.0/16) - Internal service communication
- **traefik_public** - External access through reverse proxy
- Services only exposed via Traefik (except Plex on host network)

## 🌐 Access URLs

Add to `/etc/hosts` for local access:
```bash
echo '127.0.0.1 traefik.local prowlarr.local radarr.local sonarr.local lidarr.local bazarr.local qbit.local' | sudo tee -a /etc/hosts
```

### Service URLs
| Service | URL | Purpose |
|---------|-----|---------|
| Traefik Dashboard | http://traefik.local:8080 | Monitor routing & SSL |
| qBittorrent | https://qbit.local | Download management |
| Prowlarr | https://prowlarr.local | Indexer management |
| Radarr | https://radarr.local | Movie library |
| Sonarr | https://sonarr.local | TV show library |
| Lidarr | https://lidarr.local | Music library |
| Bazarr | https://bazarr.local | Subtitle management |
| Plex | http://localhost:32400/web | Media streaming |

## ⚙️ Configuration

### Initial Setup (After First Start)

#### 1. Configure Prowlarr
1. Access https://prowlarr.local
2. Go to **Settings → Apps → Add Application**
3. Add each *arr service:
   - **Radarr**: http://radarr:7878 + API key from CREDENTIALS.txt
   - **Sonarr**: http://sonarr:8989 + API key
   - **Lidarr**: http://lidarr:8686 + API key
4. Go to **Indexers → Add Indexer**
5. Add your preferred indexers (public or private trackers)

#### 2. Configure Download Client in Each *arr
1. In each service (Radarr/Sonarr/Lidarr):
2. Go to **Settings → Download Clients → Add → qBittorrent**
3. Configure:
   - **Host**: `qbittorrent`
   - **Port**: `8090`
   - **Username**: `admin`
   - **Password**: From CREDENTIALS.txt
   - **Category**: Set appropriate category (movies/tv/music)

#### 3. Set Media Paths
- **Radarr**: Root Folder → `/data/media/movies`
- **Sonarr**: Root Folder → `/data/media/tv`
- **Lidarr**: Root Folder → `/data2/media/music`

#### 4. Configure Plex
1. Access http://localhost:32400/web
2. Complete first-time setup wizard
3. Add libraries:
   - Movies: `/media/media/movies`
   - TV Shows: `/media/media/tv`
   - Music: `/data2/media/music`

### Production Deployment

#### Enable Let's Encrypt
1. Edit `traefik/traefik.yml`
2. Update email: `email: your-email@example.com`
3. Uncomment the production CA server line
4. Update domain from `.local` to your actual domain
5. Restart Traefik: `docker compose restart traefik`

#### Security Hardening
- [ ] Change default passwords (stored in CREDENTIALS.txt)
- [ ] Delete CREDENTIALS.txt after recording
- [ ] Set strong ACME email in .env
- [ ] Configure firewall (allow 80, 443, block others)
- [ ] Enable UFW or iptables
- [ ] Consider VPN for qBittorrent
- [ ] Regular backups of config volumes

## 🛠️ Management Commands

### Service Control
```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# Restart a specific service
docker compose restart radarr

# View logs
docker compose logs -f sonarr

# View status
docker compose ps

# Update images and restart
./pull-images.sh && docker compose up -d
```

### Backup Configs
```bash
# Backup a service config
docker run --rm \
  -v radarr_config:/config \
  -v $(pwd):/backup \
  alpine tar czf /backup/radarr-backup.tar.gz /config

# Restore a service config
docker run --rm \
  -v radarr_config:/config \
  -v $(pwd):/backup \
  alpine tar xzf /backup/radarr-backup.tar.gz -C /
```

### Monitoring
```bash
# Real-time resource usage
docker stats

# Check health status
docker compose ps --format "table {{.Service}}\t{{.Status}}\t{{.Health}}"

# Traefik logs
docker compose logs -f traefik

# All service logs
docker compose logs -f
```

## 🐛 Troubleshooting

### Services Won't Start
```bash
# Check logs for specific service
docker compose logs radarr

# Check all container status
docker compose ps

# Restart specific service
docker compose restart radarr

# Recreate service
docker compose up -d --force-recreate radarr
```

### Permission Errors
```bash
# Fix ownership of media directories
sudo chown -R 1000:1000 ~/media/usb11tb
sudo chown -R 1000:1000 ~/media/usb6tb

# Verify PUID/PGID in .env match your user
id -u  # Should match PUID
id -g  # Should match PGID
```

### Network Issues
```bash
# Check if network exists
docker network ls | grep media

# Recreate networks
docker compose down
docker network prune -f
docker compose up -d

# Check for port conflicts
sudo netstat -tulpn | grep -E ':(80|443|8080|6881)'
```

### Can't Access Services
```bash
# Verify /etc/hosts
cat /etc/hosts | grep local

# Check Traefik routing
docker compose logs traefik | grep -i error

# Test direct container access
curl http://localhost:9696  # Prowlarr direct
```

### SSL Certificate Issues
```bash
# Check acme.json permissions
ls -la traefik/acme.json  # Should be 600

# Fix permissions
chmod 600 traefik/acme.json

# Check certificate status in Traefik dashboard
# http://traefik.local:8080
```

### Docker Hub Rate Limits
The included `pull-images.sh` script pulls images sequentially with delays to avoid rate limits. If you still hit limits:

```bash
# Login to Docker Hub for higher limits
docker login

# Or pull images manually with delays
for service in traefik qbittorrent prowlarr radarr sonarr; do
  docker compose pull $service
  sleep 10
done
```

## 📊 Resource Requirements

### Minimum
- **CPU**: 4 cores
- **RAM**: 8GB
- **Storage**: 500GB+ for media
- **Network**: 50 Mbps down/10 Mbps up

### Recommended
- **CPU**: 8+ cores (for Plex transcoding)
- **RAM**: 16GB+
- **Storage**: Multiple TB for media library
- **GPU**: Intel iGPU or NVIDIA for hardware transcoding
- **Network**: 100+ Mbps

## 🔄 Updates

### Updating Services
```bash
# Pull latest images
./pull-images.sh

# Recreate containers with new images
docker compose up -d

# Or update specific service
docker compose pull radarr
docker compose up -d radarr
```

### Updating the Stack
```bash
# Backup current configuration
cp docker-compose.yml docker-compose.yml.backup
cp .env .env.backup

# Pull new changes (if using git)
git pull

# Review changes
diff docker-compose.yml docker-compose.yml.backup

# Apply updates
docker compose up -d
```

## 🤝 Contributing

Found an issue or want to improve this setup? 

1. Check existing issues
2. Create a detailed bug report or feature request
3. Submit pull requests with improvements

## ⚠️ Important Notes

- **Delete CREDENTIALS.txt** after recording passwords somewhere safe
- **Never commit .env** or `.secrets/` to version control
- **Backup regularly** - configs are in Docker volumes
- **Monitor disk space** - Media can fill drives quickly
- **Legal compliance** - Only download content you own or have rights to
- **VPN recommended** - For torrent traffic privacy

## 📜 License

MIT License - Feel free to modify and distribute

## 🎅 Credits

Created with ❤️ for the homelab and self-hosting community

---

**🎄 Happy Streaming! 🎁**