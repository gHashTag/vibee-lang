#!/bin/bash
# WebArena Environment Setup Script
# Запускать на сервере с Docker (AWS EC2 t3a.xlarge, 1000GB)
# φ² + 1/φ² = 3 | PHOENIX = 999

set -e

HOSTNAME="${1:-localhost}"
echo "═══════════════════════════════════════════════════════════════"
echo "  WebArena Environment Setup"
echo "  Hostname: $HOSTNAME"
echo "═══════════════════════════════════════════════════════════════"

# Проверка Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker не установлен. Установите Docker и повторите."
    exit 1
fi

echo "✓ Docker найден"

# Создание директории для данных
mkdir -p ~/webarena-data
cd ~/webarena-data

# ═══════════════════════════════════════════════════════════════
# 1. Shopping Website (OneStopShop) - порт 7770
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[1/5] Shopping Website (порт 7770)..."

if [ ! -f "shopping_final_0712.tar" ]; then
    echo "  Скачивание образа (~15GB)..."
    wget -q --show-progress http://metis.lti.cs.cmu.edu/webarena-images/shopping_final_0712.tar
fi

if ! docker images | grep -q "shopping_final_0712"; then
    echo "  Загрузка образа в Docker..."
    docker load --input shopping_final_0712.tar
fi

if ! docker ps | grep -q "shopping"; then
    docker run --name shopping -p 7770:80 -d shopping_final_0712
    sleep 60
    docker exec shopping /var/www/magento2/bin/magento setup:store-config:set --base-url="http://${HOSTNAME}:7770"
    docker exec shopping mysql -u magentouser -pMyPassword magentodb -e "UPDATE core_config_data SET value='http://${HOSTNAME}:7770/' WHERE path = 'web/secure/base_url';"
    docker exec shopping /var/www/magento2/bin/magento cache:flush
fi
echo "  ✓ Shopping готов: http://${HOSTNAME}:7770"

# ═══════════════════════════════════════════════════════════════
# 2. Shopping Admin (CMS) - порт 7780
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[2/5] Shopping Admin (порт 7780)..."

if [ ! -f "shopping_admin_final_0719.tar" ]; then
    echo "  Скачивание образа..."
    wget -q --show-progress http://metis.lti.cs.cmu.edu/webarena-images/shopping_admin_final_0719.tar
fi

if ! docker images | grep -q "shopping_admin_final_0719"; then
    docker load --input shopping_admin_final_0719.tar
fi

if ! docker ps | grep -q "shopping_admin"; then
    docker run --name shopping_admin -p 7780:80 -d shopping_admin_final_0719
    sleep 60
    docker exec shopping_admin /var/www/magento2/bin/magento setup:store-config:set --base-url="http://${HOSTNAME}:7780"
    docker exec shopping_admin mysql -u magentouser -pMyPassword magentodb -e "UPDATE core_config_data SET value='http://${HOSTNAME}:7780/' WHERE path = 'web/secure/base_url';"
    docker exec shopping_admin php /var/www/magento2/bin/magento config:set admin/security/password_is_forced 0
    docker exec shopping_admin php /var/www/magento2/bin/magento config:set admin/security/password_lifetime 0
    docker exec shopping_admin /var/www/magento2/bin/magento cache:flush
fi
echo "  ✓ Shopping Admin готов: http://${HOSTNAME}:7780/admin"

# ═══════════════════════════════════════════════════════════════
# 3. Reddit (Forum) - порт 9999
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[3/5] Reddit Forum (порт 9999)..."

if [ ! -f "postmill-populated-exposed-withimg.tar" ]; then
    echo "  Скачивание образа..."
    wget -q --show-progress http://metis.lti.cs.cmu.edu/webarena-images/postmill-populated-exposed-withimg.tar
fi

if ! docker images | grep -q "postmill-populated-exposed-withimg"; then
    docker load --input postmill-populated-exposed-withimg.tar
fi

if ! docker ps | grep -q "forum"; then
    docker run --name forum -p 9999:80 -d postmill-populated-exposed-withimg
fi
echo "  ✓ Reddit готов: http://${HOSTNAME}:9999"

# ═══════════════════════════════════════════════════════════════
# 4. GitLab - порт 8023
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[4/5] GitLab (порт 8023)..."

if [ ! -f "gitlab-populated-final-port8023.tar" ]; then
    echo "  Скачивание образа (~10GB)..."
    wget -q --show-progress http://metis.lti.cs.cmu.edu/webarena-images/gitlab-populated-final-port8023.tar
fi

if ! docker images | grep -q "gitlab-populated-final-port8023"; then
    docker load --input gitlab-populated-final-port8023.tar
fi

if ! docker ps | grep -q "gitlab"; then
    docker run --name gitlab -d -p 8023:8023 gitlab-populated-final-port8023 /opt/gitlab/embedded/bin/runsvdir-start
    echo "  Ожидание запуска GitLab (5 минут)..."
    sleep 300
    docker exec gitlab sed -i "s|^external_url.*|external_url 'http://${HOSTNAME}:8023'|" /etc/gitlab/gitlab.rb
    docker exec gitlab gitlab-ctl reconfigure
fi
echo "  ✓ GitLab готов: http://${HOSTNAME}:8023"

# ═══════════════════════════════════════════════════════════════
# 5. Wikipedia - порт 8888
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[5/5] Wikipedia (порт 8888)..."

if [ ! -f "wikipedia_en_all_maxi_2022-05.zim" ]; then
    echo "  Скачивание Wikipedia (~90GB)..."
    wget -q --show-progress http://metis.lti.cs.cmu.edu/webarena-images/wikipedia_en_all_maxi_2022-05.zim
fi

if ! docker ps | grep -q "wikipedia"; then
    docker run -d --name=wikipedia --volume=$(pwd):/data -p 8888:80 ghcr.io/kiwix/kiwix-serve:3.3.0 wikipedia_en_all_maxi_2022-05.zim
fi
echo "  ✓ Wikipedia готов: http://${HOSTNAME}:8888"

# ═══════════════════════════════════════════════════════════════
# Проверка всех сервисов
# ═══════════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Проверка сервисов..."
echo "═══════════════════════════════════════════════════════════════"

sleep 10

check_service() {
    local name=$1
    local url=$2
    local code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    if [ "$code" = "200" ] || [ "$code" = "302" ]; then
        echo "  ✓ $name: HTTP $code"
    else
        echo "  ❌ $name: HTTP $code (ожидается 200/302)"
    fi
}

check_service "Shopping (7770)" "http://${HOSTNAME}:7770"
check_service "Shopping Admin (7780)" "http://${HOSTNAME}:7780"
check_service "Reddit (9999)" "http://${HOSTNAME}:9999"
check_service "GitLab (8023)" "http://${HOSTNAME}:8023"
check_service "Wikipedia (8888)" "http://${HOSTNAME}:8888"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  WebArena Environment Ready!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Экспортируйте переменные окружения:"
echo ""
echo "export SHOPPING=\"${HOSTNAME}:7770\""
echo "export SHOPPING_ADMIN=\"${HOSTNAME}:7780/admin\""
echo "export REDDIT=\"${HOSTNAME}:9999\""
echo "export GITLAB=\"${HOSTNAME}:8023\""
echo "export WIKIPEDIA=\"${HOSTNAME}:8888/wikipedia_en_all_maxi_2022-05/A/User:The_other_Kiwix_guy/Landing\""
echo ""
