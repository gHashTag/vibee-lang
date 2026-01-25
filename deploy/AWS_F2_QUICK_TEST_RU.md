# 🚀 БЫСТРЫЙ ТЕСТ TRINITY НА AWS F2 FPGA

**Минимальный бюджет**: $5-20  
**Время теста**: 1-3 часа  
**Цель**: Валидация φ² + 1/φ² = 3 на реальном FPGA

---

## ШАГ 1: Создать AWS аккаунт (БЕСПЛАТНО)

1. Перейди на https://aws.amazon.com/
2. Нажми **"Create an AWS Account"**
3. Введи email и данные карты (для верификации)
4. **Free Tier** даёт $0 за базовые сервисы

---

## ШАГ 2: Запросить доступ к F2 инстансам

⚠️ **ВАЖНО**: F2 инстансы требуют одобрения лимита!

1. Перейди в **Service Quotas** → **EC2**
2. Найди **"Running On-Demand F instances"**
3. Запроси увеличение лимита до **8 vCPU** (для f2.6xlarge)
4. Обычно одобряют за **24-48 часов**

---

## ШАГ 3: Запустить F2 инстанс

### Через AWS Console:

1. Перейди в **EC2** → **Launch Instance**
2. Выбери AMI: **FPGA Developer AMI** (поиск "fpga")
3. Instance type: **f2.6xlarge** ($1.65/час)
4. Storage: 100 GB (минимум для Vivado)
5. Security Group: SSH (порт 22)
6. Нажми **Launch**

### Через AWS CLI:

```bash
# Установи AWS CLI
pip install awscli

# Настрой credentials
aws configure
# AWS Access Key ID: [твой ключ]
# AWS Secret Access Key: [твой секрет]
# Default region: us-east-1
# Default output format: json

# Запусти F2 инстанс
aws ec2 run-instances \
  --image-id ami-0123456789abcdef0 \
  --instance-type f2.6xlarge \
  --key-name my-key \
  --security-group-ids sg-xxxxxxxx \
  --count 1
```

---

## ШАГ 4: Подключиться и настроить

```bash
# SSH к инстансу
ssh -i my-key.pem centos@<PUBLIC_IP>

# Проверить FPGA
sudo fpga-describe-local-image -S 0 -H

# Клонировать TRINITY
git clone https://github.com/gHashTag/vibee-lang.git
cd vibee-lang/trinity/output/fpga
```

---

## ШАГ 5: Собрать AFI (Amazon FPGA Image)

```bash
# Установить AWS FPGA SDK
git clone https://github.com/aws/aws-fpga.git
cd aws-fpga
source sdk_setup.sh
source hdk_setup.sh

# Скопировать TRINITY Verilog
cp ~/vibee-lang/trinity/output/fpga/*.v $CL_DIR/design/

# Собрать AFI (занимает ~1-2 часа)
cd $CL_DIR/build/scripts
./aws_build_dcp_from_cl.sh

# Создать AFI
aws ec2 create-fpga-image \
  --name "trinity-v5-test" \
  --input-storage-location Bucket=my-bucket,Key=trinity.tar
```

---

## ШАГ 6: Загрузить AFI и запустить тест

```bash
# Загрузить AFI на FPGA
sudo fpga-load-local-image -S 0 -I agfi-xxxxxxxxxxxxxxxxx

# Проверить статус
sudo fpga-describe-local-image -S 0 -R -H

# Запустить тест Golden Identity
cd ~/vibee-lang
./bin/vibee run tests/fpga_golden_identity.999
```

---

## ШАГ 7: ВЫКЛЮЧИТЬ ИНСТАНС!

⚠️ **КРИТИЧЕСКИ ВАЖНО** - иначе будет списываться $1.65/час!

```bash
# Через CLI
aws ec2 stop-instances --instance-ids i-xxxxxxxxxxxxxxxxx

# Или через Console
# EC2 → Instances → Select → Instance State → Stop
```

---

## 💰 РАСЧЁТ СТОИМОСТИ

| Этап | Время | Стоимость |
|------|-------|-----------|
| Запуск инстанса | 5 мин | $0.14 |
| Настройка SDK | 30 мин | $0.83 |
| Сборка AFI | 60 мин | $1.65 |
| Тест Golden Identity | 15 мин | $0.41 |
| **ИТОГО** | **~2 часа** | **~$3.50** |

+ S3 storage для AFI: ~$0.50
+ Data transfer: ~$0.10

**ОБЩАЯ СТОИМОСТЬ ТЕСТА: ~$5**

---

## ⚡ БЫСТРЫЙ СТАРТ (КОПИПАСТА)

```bash
# 1. Подключись к F2
ssh -i key.pem centos@<IP>

# 2. Установи всё
sudo yum install -y git
git clone https://github.com/aws/aws-fpga.git
cd aws-fpga && source sdk_setup.sh && source hdk_setup.sh

# 3. Клонируй TRINITY
git clone https://github.com/gHashTag/vibee-lang.git

# 4. Проверь FPGA
sudo fpga-describe-local-image -S 0 -H

# 5. После теста - ВЫКЛЮЧИ!
# aws ec2 stop-instances --instance-ids <ID>
```

---

## 🎯 ЧТО ПРОВЕРЯЕМ

| Тест | Ожидаемый результат |
|------|---------------------|
| Golden Identity | φ² + 1/φ² = 3.0000000000 |
| PAS Daemons | 578.8x vs Binary |
| Berry Phase | 0.11423 mod 2π |
| SU(3) Core | Стабильная работа |

---

## ⚠️ ВАЖНЫЕ ЗАМЕЧАНИЯ

1. **F2 требует одобрения** - запроси лимит ЗАРАНЕЕ (24-48ч)
2. **Сборка AFI долгая** - 1-2 часа, планируй время
3. **ВЫКЛЮЧАЙ ИНСТАНС** - $1.65/час = $40/день если забудешь!
4. **us-east-1** - самый дешёвый регион для F2

---

**φ² + 1/φ² = 3 | TRINITY ГОТОВ К ТЕСТУ!**
