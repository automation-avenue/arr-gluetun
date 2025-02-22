#!/bin/bash

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Service ports definition
declare -A service_ports=(
    ["radarr"]="7878"
    ["sonarr"]="8989"
    ["prowlarr"]="9696"
    ["bazarr"]="6767"
    ["lidarr"]="8686"
    ["readarr"]="8787"
    ["qbittorrent"]="8080"
    ["jellyfin"]="8096"
)

# Function to ask yes/no questions
ask_yes_no() {
    while true; do
        read -p "$1 (y/n): " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer y or n.";;
        esac
    done
}

# Function to get current user info
get_current_user_info() {
    current_user=$(whoami)
    current_uid=$(id -u)
    current_gid=$(id -g)
    current_timezone=$(timedatectl | grep "Time zone" | awk '{print $3}')
}

# Function to explain PUID/PGID
explain_puid_pgid() {
    echo -e "${BLUE}About PUID and PGID:${NC}"
    echo "PUID (Process User ID) and PGID (Process Group ID) are used to run the containers"
    echo "with specific user permissions. This ensures that the files created by the containers"
    echo "have the correct ownership and permissions on your host system."
    echo
    echo -e "${BLUE}Current system information:${NC}"
    echo "User: $current_user"
    echo "PUID: $current_uid"
    echo "PGID: $current_gid"
    echo "Timezone: $current_timezone"
    echo
}

# Get current user information
get_current_user_info

# Ask for PUID/PGID configuration
echo -e "${BLUE}User Configuration${NC}"
explain_puid_pgid

if ask_yes_no "Do you want to use these default settings?"; then
    PUID=$current_uid
    PGID=$current_gid
    TZ=$current_timezone
else
    echo -e "${BLUE}Custom configuration:${NC}"
    read -p "Enter PUID (default: $current_uid): " input_puid
    PUID=${input_puid:-$current_uid}
    
    read -p "Enter PGID (default: $current_gid): " input_pgid
    PGID=${input_pgid:-$current_gid}
    
    echo -e "${BLUE}Common timezones examples:${NC}"
    echo "Europe/Paris"
    echo "Europe/London"
    echo "America/New_York"
    echo "Asia/Tokyo"
    echo "Current: $current_timezone"
    read -p "Enter timezone (default: $current_timezone): " input_tz
    TZ=${input_tz:-$current_timezone}
fi

# Create docker-compose.yml file
echo "---" > docker-compose.yml
echo "services:" >> docker-compose.yml

# List of available services
declare -A services
services=(
    ["radarr"]="Movie manager"
    ["sonarr"]="TV series manager"
    ["prowlarr"]="Indexer manager"
    ["bazarr"]="Subtitle manager"
    ["lidarr"]="Music manager"
    ["readarr"]="Book manager"
    ["qbittorrent"]="Torrent client"
    ["jellyfin"]="Media server"
)

# Ask which services to install
echo -e "${BLUE}Which services would you like to install?${NC}"
declare -A selected_services
for service in "${!services[@]}"; do
    if ask_yes_no "Install ${service} (${services[$service]}) ?"; then
        selected_services[$service]=1
    fi
done

# Ask about using Gluetun
use_gluetun=false
if ask_yes_no "Do you want to use Gluetun (VPN) ?"; then
    use_gluetun=true
    # Gluetun configuration
    read -p "Enter your VPN username: " vpn_user
    read -s -p "Enter your VPN password: " vpn_password
    echo
    read -p "Enter VPN server country (e.g., Netherlands): " vpn_country
    read -p "VPN type (openvpn/wireguard): " vpn_type
fi

# Generate configuration for each selected service
for service in "${!selected_services[@]}"; do
    echo -e "${GREEN}Generating configuration for $service...${NC}"
    
    echo "" >> docker-compose.yml
    echo "############################" >> docker-compose.yml
    echo "# ${service^^}" >> docker-compose.yml
    echo "############################" >> docker-compose.yml
    echo "" >> docker-compose.yml
    echo "  $service:" >> docker-compose.yml
    echo "    image: lscr.io/linuxserver/$service:latest" >> docker-compose.yml
    echo "    container_name: $service" >> docker-compose.yml
    
    if [ "$use_gluetun" = true ] && [ "$service" != "jellyfin" ]; then
        echo "    network_mode: \"service:gluetun\"" >> docker-compose.yml
    fi
    
    # Add specific configuration for each service
    case $service in
        "jellyfin")
            cat << EOF >> docker-compose.yml
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TZ
    volumes:
      - /media/arr/jellyfin/config:/config
      - /media/arr/sonarr/tvseries:/data/tvshows
      - /media/arr/radarr/movies:/data/movies
    ports:
      - 8096:8096
    restart: unless-stopped
EOF
            ;;
        "qbittorrent")
            cat << EOF >> docker-compose.yml
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TZ
      - WEBUI_PORT=8080
      - TORRENTING_PORT=6881
    volumes:
      - /media/arr/qbittorrent/config:/config
      - /media/arr/qbittorrent/downloads:/downloads
    ports:
      - 8080:8080
      - 6881:6881
      - 6881:6881/udp
    restart: unless-stopped
EOF
            ;;
        "prowlarr")
            cat << EOF >> docker-compose.yml
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TZ
    volumes:
      - /media/arr/$service/config:/config
    ports:
      - 9696:9696
    restart: unless-stopped
EOF
            ;;
        "radarr")
            cat << EOF >> docker-compose.yml
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TZ
    volumes:
      - /media/arr/$service/config:/config
      - /media/arr/radarr/movies:/movies
      - /media/arr/qbittorrent/downloads:/downloads
    ports:
      - 7878:7878
    restart: unless-stopped
EOF
            ;;
        "sonarr")
            cat << EOF >> docker-compose.yml
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TZ
    volumes:
      - /media/arr/$service/config:/config
      - /media/arr/sonarr/tvseries:/tv
      - /media/arr/qbittorrent/downloads:/downloads
    ports:
      - 8989:8989
    restart: unless-stopped
EOF
            ;;
        *)
            port=${service_ports[$service]}
            cat << EOF >> docker-compose.yml
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TZ
    volumes:
      - /media/arr/$service/config:/config
    ports:
      - $port:$port
    restart: unless-stopped
EOF
            ;;
    esac
done

# Add Gluetun if selected
if [ "$use_gluetun" = true ]; then
    cat << EOF >> docker-compose.yml

############################
# GLUETUN
############################

  gluetun:
    image: qmcgaw/gluetun
    container_name: gluetun
    ports:
      - 9696:9696 #prowlarr
      - 7878:7878 #radarr
      - 8989:8989 #sonarr
      - 6767:6767 #bazarr
      - 8686:8686 #lidarr
      - 8787:8787 #readarr
      - 8080:8080 #qbittorrent
      - 6881:6881 #qbittorrent
      - 6881:6881/udp #qbittorrent
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    environment:
      - VPN_SERVICE_PROVIDER=nordvpn
      - VPN_TYPE=$vpn_type
      - OPENVPN_USER=$vpn_user
      - OPENVPN_PASSWORD=$vpn_password
      - SERVER_COUNTRIES=$vpn_country
EOF
fi

# Create necessary directories
echo -e "${GREEN}Creating necessary directories...${NC}"
for service in "${!selected_services[@]}"; do
    mkdir -p /media/arr/$service/config
    case $service in
        "radarr")
            mkdir -p /media/arr/radarr/movies
            ;;
        "sonarr")
            mkdir -p /media/arr/sonarr/tvseries
            ;;
        "qbittorrent")
            mkdir -p /media/arr/qbittorrent/downloads
            ;;
    esac
done

# Set correct permissions
echo -e "${GREEN}Setting correct permissions...${NC}"
chown -R $PUID:$PGID /media/arr

echo -e "${GREEN}Configuration complete! The docker-compose.yml file has been generated.${NC}"
echo -e "${BLUE}You can now run 'docker-compose up -d' to start your services.${NC}"
