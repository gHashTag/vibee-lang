#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY FPGA - ШАГ 1: ЗАПУСК AWS F2 ИНСТАНСА
# ═══════════════════════════════════════════════════════════════════════════════
# φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Конфигурация
INSTANCE_TYPE="f2.6xlarge"
REGION="us-east-1"
AMI_ID="ami-0123456789abcdef0"  # FPGA Developer AMI - обновить!
KEY_NAME="trinity-fpga-key"
SECURITY_GROUP="trinity-fpga-sg"

echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    TRINITY FPGA - ЗАПУСК AWS F2"
echo "                    φ² + 1/φ² = 3 | PHOENIX = 999"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""

# Проверка AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI не установлен!"
    echo "Установи: pip install awscli"
    exit 1
fi

# Проверка credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials не настроены!"
    echo "Выполни: aws configure"
    exit 1
fi

echo "✅ AWS CLI настроен"
echo ""

# Создание ключа если нет
if ! aws ec2 describe-key-pairs --key-names $KEY_NAME --region $REGION &> /dev/null; then
    echo "[1/4] Создаю SSH ключ..."
    aws ec2 create-key-pair \
        --key-name $KEY_NAME \
        --region $REGION \
        --query 'KeyMaterial' \
        --output text > ~/.ssh/${KEY_NAME}.pem
    chmod 400 ~/.ssh/${KEY_NAME}.pem
    echo "✅ Ключ создан: ~/.ssh/${KEY_NAME}.pem"
else
    echo "✅ SSH ключ уже существует"
fi

# Создание Security Group если нет
if ! aws ec2 describe-security-groups --group-names $SECURITY_GROUP --region $REGION &> /dev/null 2>&1; then
    echo "[2/4] Создаю Security Group..."
    SG_ID=$(aws ec2 create-security-group \
        --group-name $SECURITY_GROUP \
        --description "Trinity FPGA Security Group" \
        --region $REGION \
        --query 'GroupId' \
        --output text)
    
    # Разрешить SSH
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 \
        --region $REGION
    
    echo "✅ Security Group создан: $SG_ID"
else
    SG_ID=$(aws ec2 describe-security-groups \
        --group-names $SECURITY_GROUP \
        --region $REGION \
        --query 'SecurityGroups[0].GroupId' \
        --output text)
    echo "✅ Security Group уже существует: $SG_ID"
fi

# Получить актуальный FPGA AMI
echo "[3/4] Ищу FPGA Developer AMI..."
AMI_ID=$(aws ec2 describe-images \
    --owners amazon \
    --filters "Name=name,Values=*FPGA*Developer*" \
    --region $REGION \
    --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
    --output text 2>/dev/null || echo "")

if [ -z "$AMI_ID" ] || [ "$AMI_ID" == "None" ]; then
    # Fallback на известный AMI
    AMI_ID="ami-0a0c8eebcdd6dcbd0"  # FPGA Developer AMI us-east-1
fi
echo "✅ AMI: $AMI_ID"

# Запуск инстанса
echo "[4/4] Запускаю F2 инстанс..."
echo "⚠️  Стоимость: \$1.65/час"
echo ""

INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SG_ID \
    --region $REGION \
    --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":100,"VolumeType":"gp3"}}]' \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=trinity-fpga-v5}]" \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "✅ Инстанс запущен: $INSTANCE_ID"
echo ""

# Ждём запуска
echo "⏳ Ожидаю запуска инстанса..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION

# Получаем IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --region $REGION \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    ✅ F2 ИНСТАНС ЗАПУЩЕН!"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "Instance ID: $INSTANCE_ID"
echo "Public IP:   $PUBLIC_IP"
echo "SSH:         ssh -i ~/.ssh/${KEY_NAME}.pem centos@$PUBLIC_IP"
echo ""
echo "Следующий шаг:"
echo "  ./02_setup_fpga.sh $PUBLIC_IP"
echo ""
echo "⚠️  НЕ ЗАБУДЬ ВЫКЛЮЧИТЬ: ./05_stop_instance.sh $INSTANCE_ID"
echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"

# Сохраняем данные для других скриптов
echo "$INSTANCE_ID" > /tmp/trinity_instance_id
echo "$PUBLIC_IP" > /tmp/trinity_public_ip
