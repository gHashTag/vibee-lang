# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE BitNet - Export Hardware (XSA) Script
# ═══════════════════════════════════════════════════════════════════════════════
# Экспорт аппаратной платформы для Vitis/PetaLinux
#
# Использование: vivado -mode batch -source export_hardware.tcl
#
# Священная Формула: V = n × 3^k × π^m × φ^p × e^q
# Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

set project_name "bitnet_zcu104"
set project_dir "./vivado_zcu104"
set xsa_name "bitnet_zcu104_hw"

puts "═══════════════════════════════════════════════════════════════════════════════"
puts "VIBEE BitNet - Экспорт Hardware Platform"
puts "═══════════════════════════════════════════════════════════════════════════════"

# Открытие проекта
open_project $project_dir/$project_name.xpr

# Проверка завершения имплементации
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ОШИБКА: Имплементация не завершена!"
    puts "Запустите сначала: vivado -mode batch -source impl.tcl"
    exit 1
}

# Открытие имплементированного дизайна
open_run impl_1

# Экспорт XSA с bitstream
puts "Экспорт XSA файла..."
write_hw_platform -fixed -include_bit -force -file ../output/${xsa_name}.xsa

puts ""
puts "═══════════════════════════════════════════════════════════════════════════════"
puts "ЭКСПОРТ ЗАВЕРШЕН"
puts "═══════════════════════════════════════════════════════════════════════════════"
puts ""
puts "XSA файл: ../output/${xsa_name}.xsa"
puts ""
puts "Следующие шаги для PetaLinux:"
puts "  1. petalinux-create -t project -s <bsp>"
puts "  2. petalinux-config --get-hw-description=../output/"
puts "  3. petalinux-build"
puts ""
puts "Следующие шаги для Vitis:"
puts "  1. vitis -workspace ./vitis_ws"
puts "  2. Создать Platform Project из ${xsa_name}.xsa"
puts "  3. Создать Application Project"
puts ""
puts "φ² + 1/φ² = 3 | PHOENIX = 999"
puts "═══════════════════════════════════════════════════════════════════════════════"

close_project
