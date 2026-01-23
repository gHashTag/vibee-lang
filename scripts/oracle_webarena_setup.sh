#!/bin/bash
# Oracle Cloud WebArena Setup Script
# Run this on your Oracle Cloud VM

set -e

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║           WEBARENA SETUP FOR ORACLE CLOUD                        ║"
echo "╚══════════════════════════════════════════════════════════════════╝"

# 1. Install Docker
echo ""
echo "=== Installing Docker ==="
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# 2. Pull WebArena images
echo ""
echo "=== Pulling WebArena Docker images (this takes ~30 minutes) ==="

docker pull webarenaimages/shopping_final_0712
docker pull webarenaimages/shopping_admin_final_0719
docker pull webarenaimages/postmill-populated-exposed-withimg
docker pull webarenaimages/gitlab-populated-final-port8023

# 3. Start containers
echo ""
echo "=== Starting WebArena containers ==="

docker run -d --name shopping -p 7770:80 webarenaimages/shopping_final_0712
docker run -d --name shopping_admin -p 7780:80 webarenaimages/shopping_admin_final_0719
docker run -d --name forum -p 9999:80 webarenaimages/postmill-populated-exposed-withimg
docker run -d --name gitlab -p 8023:8023 webarenaimages/gitlab-populated-final-port8023

# 4. Wait for services to start
echo ""
echo "=== Waiting for services to start (2 minutes) ==="
sleep 120

# 5. Check status
echo ""
echo "=== Container Status ==="
docker ps

# 6. Get IP
IP=$(curl -s ifconfig.me)
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    SETUP COMPLETE!                               ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║                                                                  ║"
echo "║  Your server IP: $IP"
echo "║                                                                  ║"
echo "║  Services:                                                       ║"
echo "║    Shopping:       http://$IP:7770"
echo "║    Shopping Admin: http://$IP:7780/admin"
echo "║    Reddit/Forum:   http://$IP:9999"
echo "║    GitLab:         http://$IP:8023"
echo "║                                                                  ║"
echo "║  Now run on your local machine:                                  ║"
echo "║                                                                  ║"
echo "║  export SERVER_IP=\"$IP\""
echo "║  export SHOPPING=\"http://\$SERVER_IP:7770\""
echo "║  export SHOPPING_ADMIN=\"http://\$SERVER_IP:7780/admin\""
echo "║  export REDDIT=\"http://\$SERVER_IP:9999\""
echo "║  export GITLAB=\"http://\$SERVER_IP:8023\""
echo "║                                                                  ║"
echo "║  python scripts/webarena_full_benchmark.py --tasks 100           ║"
echo "║                                                                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
