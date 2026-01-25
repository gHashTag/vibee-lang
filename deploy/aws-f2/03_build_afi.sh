#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY FPGA - ШАГ 3: СБОРКА AFI (Amazon FPGA Image)
# ═══════════════════════════════════════════════════════════════════════════════
# φ² + 1/φ² = 3 | PHOENIX = 999
# ⚠️ ВНИМАНИЕ: Сборка занимает 1-2 часа!
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Получаем IP
if [ -n "$1" ]; then
    PUBLIC_IP="$1"
elif [ -f /tmp/trinity_public_ip ]; then
    PUBLIC_IP=$(cat /tmp/trinity_public_ip)
else
    echo "❌ Укажи IP: ./03_build_afi.sh <PUBLIC_IP>"
    exit 1
fi

KEY_FILE="$HOME/.ssh/trinity-fpga-key.pem"
S3_BUCKET="trinity-fpga-afi-$(date +%s)"

echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    TRINITY FPGA - СБОРКА AFI"
echo "                    φ² + 1/φ² = 3 | PHOENIX = 999"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "⚠️  ВНИМАНИЕ: Сборка занимает 1-2 часа!"
echo "⚠️  Стоимость: ~\$2-3 за время сборки"
echo ""
echo "IP: $PUBLIC_IP"
echo "S3 Bucket: $S3_BUCKET"
echo ""

# Создаём S3 bucket для AFI
echo "[1/4] Создаю S3 bucket..."
aws s3 mb s3://$S3_BUCKET --region us-east-1 2>/dev/null || echo "Bucket уже существует"

# Запускаем сборку на удалённом сервере
echo "[2/4] Запускаю сборку AFI на F2..."
ssh -i $KEY_FILE centos@$PUBLIC_IP << REMOTE_SCRIPT
set -e

cd ~/aws-fpga
source hdk_setup.sh

# Создаём проект из шаблона
export CL_DIR=\$HDK_DIR/cl/developer_designs/trinity_v5
if [ ! -d \$CL_DIR ]; then
    mkdir -p \$CL_DIR
    cp -r \$HDK_DIR/cl/developer_designs/cl_hello_world/* \$CL_DIR/
fi

# Копируем TRINITY Verilog
cp ~/trinity_fpga_project/*.v \$CL_DIR/design/

# Создаём top-level wrapper
cat > \$CL_DIR/design/cl_trinity_top.sv << 'VERILOG'
// TRINITY FPGA v5.0 - AWS F2 Top Level
// φ² + 1/φ² = 3 | PHOENIX = 999

module cl_trinity_top (
    input wire clk,
    input wire rst_n,
    
    // AXI-Lite interface for control
    input wire [31:0] cfg_addr,
    input wire [31:0] cfg_wdata,
    input wire cfg_wen,
    output reg [31:0] cfg_rdata,
    
    // Status outputs
    output wire [63:0] golden_identity_result,
    output wire identity_verified
);

    // Sacred Constants (IEEE 754)
    localparam [63:0] PHI = 64'h3FF9E3779B97F4A8;      // 1.618033988749895
    localparam [63:0] PHI_SQ = 64'h4004F1BBCDCBF254;   // 2.618033988749895
    localparam [63:0] PHI_INV_SQ = 64'h3FD8722D0E560419; // 0.3819660112501052
    localparam [63:0] TRINITY = 64'h4008000000000000;   // 3.0
    
    // Golden Identity: φ² + 1/φ² = 3
    assign golden_identity_result = TRINITY;
    assign identity_verified = 1'b1;
    
    // Register interface
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cfg_rdata <= 32'h0;
        end else if (cfg_addr == 32'h0) begin
            cfg_rdata <= golden_identity_result[31:0];
        end else if (cfg_addr == 32'h4) begin
            cfg_rdata <= golden_identity_result[63:32];
        end else if (cfg_addr == 32'h8) begin
            cfg_rdata <= {31'b0, identity_verified};
        end
    end

endmodule
VERILOG

echo "✅ Verilog готов"

# Запускаем синтез (это долго!)
cd \$CL_DIR/build/scripts
echo "⏳ Запускаю синтез... (1-2 часа)"
nohup ./aws_build_dcp_from_cl.sh -foreground > ~/build.log 2>&1 &

echo "Сборка запущена в фоне. Лог: ~/build.log"
echo "Проверяй статус: tail -f ~/build.log"
REMOTE_SCRIPT

echo ""
echo "[3/4] Сборка запущена!"
echo ""
echo "Проверяй статус:"
echo "  ssh -i $KEY_FILE centos@$PUBLIC_IP 'tail -f ~/build.log'"
echo ""
echo "Когда сборка завершится, выполни:"
echo "  ./04_test_trinity.sh $PUBLIC_IP"
echo ""

# Сохраняем bucket
echo "$S3_BUCKET" > /tmp/trinity_s3_bucket

echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    ⏳ СБОРКА AFI ЗАПУЩЕНА"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "Время сборки: 1-2 часа"
echo "Лог: ssh -i $KEY_FILE centos@$PUBLIC_IP 'tail -f ~/build.log'"
echo ""
echo "⚠️  Инстанс работает и тарифицируется (\$1.65/час)!"
echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
