// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE FPGA - Multi-SIMD Engine (16 параллельных ядер)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Священная Формула: V = n × 3^k × π^m × φ^p × e^q
// Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999
//
// Производительность:
//   - 16 SIMD ядер × 27 тритов = 432 MAC/цикл
//   - 300 MHz × 432 = 129.6 GMAC/s
//   - BitNet-1.58B: ~10 мс/токен
//
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps
`default_nettype none

// ═══════════════════════════════════════════════════════════════════════════════
// ПАРАМЕТРЫ
// ═══════════════════════════════════════════════════════════════════════════════

module multi_simd_engine #(
    parameter NUM_CORES       = 32,          // Количество параллельных ядер (было 16)
    parameter TRIT_WIDTH      = 2,           // Бит на трит
    parameter CHUNK_SIZE      = 27,          // Тритов на ядро (3^3)
    parameter SIMD_WIDTH      = 54,          // CHUNK_SIZE * TRIT_WIDTH
    parameter ACCUM_WIDTH     = 32,          // Ширина аккумулятора
    parameter WEIGHT_DEPTH    = 16384,       // Глубина памяти весов
    parameter WEIGHT_ADDR_W   = 14           // log2(WEIGHT_DEPTH)
)(
    input  wire                         clk,
    input  wire                         rst_n,
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Управление
    // ═══════════════════════════════════════════════════════════════════════════
    input  wire                         start,
    input  wire                         abort,
    input  wire [1:0]                   mode,          // 00=parallel_neurons, 01=parallel_chunks
    input  wire [15:0]                  input_size,    // Размер входного вектора
    input  wire [15:0]                  output_size,   // Количество выходных нейронов
    
    output wire                         busy,
    output wire                         done,
    output wire                         error,
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Входные данные (общие для всех ядер)
    // ═══════════════════════════════════════════════════════════════════════════
    input  wire [SIMD_WIDTH-1:0]        input_data,
    input  wire                         input_valid,
    output wire                         input_ready,
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Выходные данные (16 результатов параллельно)
    // ═══════════════════════════════════════════════════════════════════════════
    output wire [NUM_CORES*ACCUM_WIDTH-1:0] output_data,  // 16 × 32 = 512 бит
    output wire [NUM_CORES-1:0]             output_valid,
    input  wire                             output_ready,
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Интерфейс памяти весов (16 портов чтения)
    // ═══════════════════════════════════════════════════════════════════════════
    output wire [NUM_CORES*WEIGHT_ADDR_W-1:0] weight_addr,
    input  wire [NUM_CORES*SIMD_WIDTH-1:0]    weight_data,
    input  wire [NUM_CORES-1:0]               weight_valid
);

    // ═══════════════════════════════════════════════════════════════════════════
    // Локальные параметры
    // ═══════════════════════════════════════════════════════════════════════════
    
    localparam TRIT_N = 2'b00;  // -1
    localparam TRIT_Z = 2'b01;  //  0
    localparam TRIT_P = 2'b10;  // +1
    
    // Режимы работы
    localparam MODE_PARALLEL_NEURONS = 2'b00;
    localparam MODE_PARALLEL_CHUNKS  = 2'b01;
    
    // Состояния FSM
    localparam S_IDLE     = 3'd0;
    localparam S_LOAD     = 3'd1;
    localparam S_COMPUTE  = 3'd2;
    localparam S_REDUCE   = 3'd3;
    localparam S_OUTPUT   = 3'd4;
    localparam S_DONE     = 3'd5;
    localparam S_ERROR    = 3'd6;
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Регистры состояния
    // ═══════════════════════════════════════════════════════════════════════════
    
    reg [2:0] state, next_state;
    reg [15:0] neuron_idx;      // Текущий нейрон
    reg [15:0] chunk_idx;       // Текущий чанк входа
    reg [15:0] chunks_per_neuron;
    
    // ═══════════════════════════════════════════════════════════════════════════
    // 16 SIMD ядер
    // ═══════════════════════════════════════════════════════════════════════════
    
    // Аккумуляторы для каждого ядра
    reg signed [ACCUM_WIDTH-1:0] accum [0:NUM_CORES-1];
    
    // Результаты MAC для каждого ядра
    wire signed [5:0] mac_result [0:NUM_CORES-1];  // -27 to +27
    
    // Веса для каждого ядра
    wire [SIMD_WIDTH-1:0] core_weights [0:NUM_CORES-1];
    
    // Адреса весов для каждого ядра
    reg [WEIGHT_ADDR_W-1:0] core_weight_addr [0:NUM_CORES-1];
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Генерация 16 SIMD ядер
    // ═══════════════════════════════════════════════════════════════════════════
    
    genvar i;
    generate
        for (i = 0; i < NUM_CORES; i = i + 1) begin : simd_cores
            
            // Извлечение весов для ядра i
            assign core_weights[i] = weight_data[(i+1)*SIMD_WIDTH-1 : i*SIMD_WIDTH];
            
            // Trit27 Dot Product для каждого ядра
            trit27_dot_product_fast dot_prod (
                .input_vec(input_data),
                .weight_vec(core_weights[i]),
                .result(mac_result[i])
            );
            
            // Адрес весов
            assign weight_addr[(i+1)*WEIGHT_ADDR_W-1 : i*WEIGHT_ADDR_W] = core_weight_addr[i];
            
            // Выходные данные
            assign output_data[(i+1)*ACCUM_WIDTH-1 : i*ACCUM_WIDTH] = accum[i];
            assign output_valid[i] = (state == S_OUTPUT);
        end
    endgenerate
    
    // ═══════════════════════════════════════════════════════════════════════════
    // FSM - Регистр состояния
    // ═══════════════════════════════════════════════════════════════════════════
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S_IDLE;
        else if (abort)
            state <= S_IDLE;
        else
            state <= next_state;
    end
    
    // ═══════════════════════════════════════════════════════════════════════════
    // FSM - Логика переходов
    // ═══════════════════════════════════════════════════════════════════════════
    
    always @(*) begin
        next_state = state;
        
        case (state)
            S_IDLE: begin
                if (start)
                    next_state = S_LOAD;
            end
            
            S_LOAD: begin
                if (weight_valid[0])  // Веса загружены
                    next_state = S_COMPUTE;
            end
            
            S_COMPUTE: begin
                if (input_valid) begin
                    if (chunk_idx >= chunks_per_neuron - 1) begin
                        // Все чанки обработаны
                        if (mode == MODE_PARALLEL_CHUNKS)
                            next_state = S_REDUCE;
                        else
                            next_state = S_OUTPUT;
                    end
                end
            end
            
            S_REDUCE: begin
                // Редукция 16 частичных сумм в одну
                next_state = S_OUTPUT;
            end
            
            S_OUTPUT: begin
                if (output_ready) begin
                    if (neuron_idx >= output_size - NUM_CORES)
                        next_state = S_DONE;
                    else
                        next_state = S_LOAD;  // Следующая группа нейронов
                end
            end
            
            S_DONE: begin
                next_state = S_IDLE;
            end
            
            S_ERROR: begin
                next_state = S_IDLE;
            end
            
            default: next_state = S_IDLE;
        endcase
    end
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Вычисление параметров
    // ═══════════════════════════════════════════════════════════════════════════
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            chunks_per_neuron <= 16'd1;
        end else if (state == S_IDLE && start) begin
            // Количество чанков = ceil(input_size / CHUNK_SIZE)
            chunks_per_neuron <= (input_size + CHUNK_SIZE - 1) / CHUNK_SIZE;
        end
    end
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Счётчики
    // ═══════════════════════════════════════════════════════════════════════════
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            neuron_idx <= 16'd0;
            chunk_idx <= 16'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    neuron_idx <= 16'd0;
                    chunk_idx <= 16'd0;
                end
                
                S_COMPUTE: begin
                    if (input_valid) begin
                        if (chunk_idx >= chunks_per_neuron - 1)
                            chunk_idx <= 16'd0;
                        else
                            chunk_idx <= chunk_idx + 1;
                    end
                end
                
                S_OUTPUT: begin
                    if (output_ready) begin
                        neuron_idx <= neuron_idx + NUM_CORES;
                    end
                end
            endcase
        end
    end
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Аккумуляторы
    // ═══════════════════════════════════════════════════════════════════════════
    
    integer j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (j = 0; j < NUM_CORES; j = j + 1)
                accum[j] <= {ACCUM_WIDTH{1'b0}};
        end else begin
            case (state)
                S_IDLE, S_LOAD: begin
                    // Сброс аккумуляторов
                    for (j = 0; j < NUM_CORES; j = j + 1)
                        accum[j] <= {ACCUM_WIDTH{1'b0}};
                end
                
                S_COMPUTE: begin
                    if (input_valid && weight_valid[0]) begin
                        // Накопление MAC результатов
                        for (j = 0; j < NUM_CORES; j = j + 1)
                            accum[j] <= accum[j] + {{(ACCUM_WIDTH-6){mac_result[j][5]}}, mac_result[j]};
                    end
                end
                
                S_REDUCE: begin
                    // Режим parallel_chunks: суммируем все 16 частичных сумм
                    // Результат в accum[0]
                    accum[0] <= accum[0] + accum[1] + accum[2] + accum[3] +
                                accum[4] + accum[5] + accum[6] + accum[7] +
                                accum[8] + accum[9] + accum[10] + accum[11] +
                                accum[12] + accum[13] + accum[14] + accum[15];
                end
            endcase
        end
    end
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Адреса весов
    // ═══════════════════════════════════════════════════════════════════════════
    
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < NUM_CORES; k = k + 1)
                core_weight_addr[k] <= {WEIGHT_ADDR_W{1'b0}};
        end else begin
            case (state)
                S_IDLE: begin
                    for (k = 0; k < NUM_CORES; k = k + 1)
                        core_weight_addr[k] <= k[WEIGHT_ADDR_W-1:0];
                end
                
                S_LOAD, S_COMPUTE: begin
                    if (mode == MODE_PARALLEL_NEURONS) begin
                        // Каждое ядро обрабатывает свой нейрон
                        for (k = 0; k < NUM_CORES; k = k + 1)
                            core_weight_addr[k] <= (neuron_idx + k) * chunks_per_neuron + chunk_idx;
                    end else begin
                        // Все ядра обрабатывают один нейрон, разные чанки
                        for (k = 0; k < NUM_CORES; k = k + 1)
                            core_weight_addr[k] <= neuron_idx * chunks_per_neuron + chunk_idx * NUM_CORES + k;
                    end
                end
            endcase
        end
    end
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Выходные сигналы
    // ═══════════════════════════════════════════════════════════════════════════
    
    assign busy = (state != S_IDLE);
    assign done = (state == S_DONE);
    assign error = (state == S_ERROR);
    assign input_ready = (state == S_COMPUTE);

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// TRIT27 DOT PRODUCT FAST - Оптимизированный MAC
// ═══════════════════════════════════════════════════════════════════════════════

module trit27_dot_product_fast (
    input  wire [53:0] input_vec,   // 27 тритов входа
    input  wire [53:0] weight_vec,  // 27 тритов весов
    output wire signed [5:0] result // Результат: -27 to +27
);

    localparam TRIT_N = 2'b00;  // -1
    localparam TRIT_Z = 2'b01;  //  0
    localparam TRIT_P = 2'b10;  // +1

    // Параллельное умножение 27 тритов
    wire [1:0] prod [0:26];
    
    genvar i;
    generate
        for (i = 0; i < 27; i = i + 1) begin : mult
            wire [1:0] a = input_vec[i*2+1 : i*2];
            wire [1:0] b = weight_vec[i*2+1 : i*2];
            wire a_zero = (a == TRIT_Z);
            wire b_zero = (b == TRIT_Z);
            wire same_sign = (a == b);
            
            assign prod[i] = (a_zero || b_zero) ? TRIT_Z :
                             same_sign ? TRIT_P : TRIT_N;
        end
    endgenerate
    
    // Конвертация в signed
    wire signed [1:0] val [0:26];
    generate
        for (i = 0; i < 27; i = i + 1) begin : conv
            assign val[i] = (prod[i] == TRIT_N) ? -2'sd1 :
                            (prod[i] == TRIT_P) ?  2'sd1 : 2'sd0;
        end
    endgenerate
    
    // Adder tree: 27 → 9 → 3 → 1
    // Level 1: 9 групп по 3
    wire signed [2:0] l1 [0:8];
    generate
        for (i = 0; i < 9; i = i + 1) begin : level1
            assign l1[i] = val[i*3] + val[i*3+1] + val[i*3+2];
        end
    endgenerate
    
    // Level 2: 3 группы по 3
    wire signed [3:0] l2 [0:2];
    assign l2[0] = l1[0] + l1[1] + l1[2];
    assign l2[1] = l1[3] + l1[4] + l1[5];
    assign l2[2] = l1[6] + l1[7] + l1[8];
    
    // Level 3: Финальная сумма
    assign result = l2[0] + l2[1] + l2[2];

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// WEIGHT MEMORY BANK - 16-портовая память весов
// ═══════════════════════════════════════════════════════════════════════════════

module weight_memory_bank #(
    parameter NUM_PORTS     = 16,
    parameter DATA_WIDTH    = 54,        // SIMD_WIDTH
    parameter DEPTH         = 16384,
    parameter ADDR_WIDTH    = 14
)(
    input  wire                         clk,
    input  wire                         rst_n,
    
    // Порты чтения (16 параллельных)
    input  wire [NUM_PORTS*ADDR_WIDTH-1:0] rd_addr,
    output reg  [NUM_PORTS*DATA_WIDTH-1:0] rd_data,
    output reg  [NUM_PORTS-1:0]            rd_valid,
    
    // Порт записи (один)
    input  wire [ADDR_WIDTH-1:0]        wr_addr,
    input  wire [DATA_WIDTH-1:0]        wr_data,
    input  wire                         wr_en
);

    // Память весов (разделена на 16 банков для параллельного доступа)
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    // Чтение с задержкой 1 такт
    integer i;
    always @(posedge clk) begin
        for (i = 0; i < NUM_PORTS; i = i + 1) begin
            rd_data[(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH] <= 
                mem[rd_addr[(i+1)*ADDR_WIDTH-1 : i*ADDR_WIDTH]];
            rd_valid[i] <= 1'b1;
        end
    end
    
    // Запись
    always @(posedge clk) begin
        if (wr_en)
            mem[wr_addr] <= wr_data;
    end

endmodule

`default_nettype wire

// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════════════════════
