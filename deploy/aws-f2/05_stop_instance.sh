#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY FPGA - ШАГ 5: ОСТАНОВКА ИНСТАНСА
# ═══════════════════════════════════════════════════════════════════════════════
# ⚠️ КРИТИЧЕСКИ ВАЖНО - иначе будет списываться $1.65/час!
# φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Получаем Instance ID
if [ -n "$1" ]; then
    INSTANCE_ID="$1"
elif [ -f /tmp/trinity_instance_id ]; then
    INSTANCE_ID=$(cat /tmp/trinity_instance_id)
else
    echo "❌ Укажи Instance ID: ./05_stop_instance.sh <INSTANCE_ID>"
    echo ""
    echo "Найти ID:"
    echo "  aws ec2 describe-instances --filters 'Name=tag:Name,Values=trinity-fpga-v5' --query 'Reservations[].Instances[].InstanceId' --output text"
    exit 1
fi

REGION="us-east-1"

echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    TRINITY FPGA - ОСТАНОВКА ИНСТАНСА"
echo "                    φ² + 1/φ² = 3 | PHOENIX = 999"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "Instance ID: $INSTANCE_ID"
echo ""

# Проверяем статус
STATUS=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --region $REGION \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text 2>/dev/null || echo "not-found")

if [ "$STATUS" == "not-found" ]; then
    echo "❌ Инстанс не найден: $INSTANCE_ID"
    exit 1
fi

echo "Текущий статус: $STATUS"
echo ""

if [ "$STATUS" == "running" ]; then
    read -p "Остановить инстанс? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "⏳ Останавливаю инстанс..."
        aws ec2 stop-instances --instance-ids $INSTANCE_ID --region $REGION
        
        echo "⏳ Ожидаю остановки..."
        aws ec2 wait instance-stopped --instance-ids $INSTANCE_ID --region $REGION
        
        echo ""
        echo "✅ Инстанс остановлен!"
        echo ""
        echo "💰 Тарификация прекращена."
        echo ""
        echo "Для удаления инстанса (освободит EBS):"
        echo "  aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION"
    else
        echo "Отменено."
    fi
elif [ "$STATUS" == "stopped" ]; then
    echo "✅ Инстанс уже остановлен."
    echo ""
    echo "Для запуска:"
    echo "  aws ec2 start-instances --instance-ids $INSTANCE_ID --region $REGION"
    echo ""
    echo "Для удаления:"
    echo "  aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION"
else
    echo "Статус: $STATUS"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"

# Очищаем временные файлы
rm -f /tmp/trinity_instance_id /tmp/trinity_public_ip /tmp/trinity_s3_bucket 2>/dev/null || true
