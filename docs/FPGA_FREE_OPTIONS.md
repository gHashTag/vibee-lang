# FPGA: Бесплатные и дешёвые варианты тестирования

## БЕСПЛАТНО: Онлайн симуляторы

### 1. EDA Playground (ЛУЧШИЙ ВАРИАНТ) ⭐

**URL:** https://www.edaplayground.com

**Что это:** Бесплатный онлайн симулятор Verilog/VHDL

**Возможности:**
- ✅ Icarus Verilog (бесплатно)
- ✅ Verilator (бесплатно)
- ✅ ModelSim (требует регистрацию)
- ✅ Synopsys VCS (требует регистрацию)
- ✅ Waveform viewer (EPWave)
- ✅ Сохранение проектов
- ✅ Sharing проектов

**Как использовать:**
1. Зайти на https://www.edaplayground.com
2. Зарегистрироваться (бесплатно)
3. Выбрать "Icarus Verilog" как симулятор
4. Вставить код из `trinity/output/fpga/hello_fpga_led.v`
5. Нажать "Run"

**Ограничения:**
- Только симуляция, не реальный FPGA
- Нет синтеза

---

### 2. 8bitworkshop

**URL:** https://8bitworkshop.com

**Что это:** Онлайн IDE для ретро-разработки с Verilog

**Возможности:**
- ✅ Verilog симуляция
- ✅ Визуализация в браузере
- ✅ Примеры проектов

**Как использовать:**
1. Зайти на https://8bitworkshop.com
2. Выбрать "Verilog" платформу
3. Писать и тестировать код

---

## ДЕШЁВАЯ АРЕНДА: Облачные FPGA

### AWS F2 Instances

**Цена:** ~$1.65/час (f2.6xlarge - 1 FPGA)

**Что это:** Реальные FPGA (AMD Virtex UltraScale+) в облаке

**Расчёт:**
- 1 час = $1.65
- 10 часов = $16.50
- Для теста достаточно 2-3 часа = **~$5**

**Как использовать:**
```bash
# 1. Создать AWS аккаунт
# 2. Запросить квоту на F2 instances
# 3. Запустить FPGA Developer AMI
# 4. Загрузить Verilog код
# 5. Синтезировать и протестировать
```

**Плюсы:**
- Реальный FPGA
- Vivado включён
- Платишь только за использование

**Минусы:**
- Сложная настройка
- Нужна кредитная карта
- Квота может быть отклонена

---

## СРАВНЕНИЕ ВСЕХ ВАРИАНТОВ

| Вариант | Цена | Реальный FPGA? | Сложность |
|---------|------|----------------|-----------|
| **EDA Playground** | $0 | ❌ Симуляция | ⭐ Легко |
| **8bitworkshop** | $0 | ❌ Симуляция | ⭐ Легко |
| **Google Colab + iverilog** | $0 | ❌ Симуляция | ⭐⭐ Средне |
| **AWS F2 (2-3 часа)** | ~$5 | ✅ Да | ⭐⭐⭐ Сложно |
| **TinyFPGA BX** | $38 | ✅ Да | ⭐⭐ Средне |
| **Arty A7-35T** | $150 | ✅ Да | ⭐⭐ Средне |

---

## РЕКОМЕНДАЦИЯ: EDA Playground

**Для немедленного тестирования без затрат:**

### Шаг 1: Регистрация
1. Зайти на https://www.edaplayground.com
2. Нажать "Log In" → "Sign Up"
3. Ввести email и пароль

### Шаг 2: Создать проект
1. Нажать "New"
2. В левой панели (testbench) вставить:

```verilog
// Testbench
module tb;
  reg clk = 0;
  reg rst_n = 0;
  wire [3:0] led;
  
  // DUT
  hello_fpga_led_top dut (
    .clk(clk),
    .rst_n(rst_n),
    .led(led)
  );
  
  // Clock
  always #5 clk = ~clk;
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb);
    
    #100 rst_n = 1;
    #1000;
    
    $display("LED = %b", led);
    $display("Test PASS!");
    $finish;
  end
endmodule
```

3. В правой панели (design) вставить код из `hello_fpga_led.v`

### Шаг 3: Запустить
1. Выбрать "Icarus Verilog 12.0"
2. Включить "Open EPWave after run"
3. Нажать "Run"

### Шаг 4: Результат
- Увидите waveforms
- Увидите "Test PASS!"
- Это доказательство работы кода!

---

## АЛЬТЕРНАТИВА: TinyFPGA BX ($38)

Если нужен реальный FPGA дешевле $150:

**TinyFPGA BX** - $38
- Lattice iCE40LP8K FPGA
- USB программирование
- Open-source toolchain (IceStorm)
- 7680 logic cells

**Где купить:**
- https://www.crowdsupply.com/tinyfpga/tinyfpga-bx
- https://tinyfpga.com

**Ограничения:**
- Меньше ресурсов чем Arty A7
- Другой toolchain (не Vivado)
- Нужно адаптировать constraints

---

## ВЫВОД

| Цель | Лучший вариант | Цена |
|------|----------------|------|
| Быстрый тест | EDA Playground | $0 |
| Реальный FPGA дёшево | TinyFPGA BX | $38 |
| Полноценная разработка | Arty A7-35T | $150 |
| Облачный FPGA | AWS F2 | ~$5/тест |

**Рекомендация:** Начать с EDA Playground (бесплатно), затем решить нужен ли реальный FPGA.

---

**φ² + 1/φ² = 3 | PHOENIX = 999**
