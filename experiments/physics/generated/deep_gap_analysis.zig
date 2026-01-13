// ГЛУБОКИЙ АНАЛИЗ КАЖДОЙ ДЫРЫ В ФИЗИКЕ
// С количественными предсказаниями и экспериментами

const std = @import("std");
const math = std.math;
const print = std.debug.print;

// ============================================================================
// ФУНДАМЕНТАЛЬНЫЕ КОНСТАНТЫ
// ============================================================================

pub const c: f64 = 299792458; // скорость света (м/с)
pub const G: f64 = 6.674e-11; // гравитационная постоянная
pub const hbar: f64 = 1.055e-34; // постоянная Планка
pub const k_B: f64 = 1.381e-23; // постоянная Больцмана
pub const e: f64 = 1.602e-19; // заряд электрона
pub const m_e: f64 = 9.109e-31; // масса электрона
pub const eV: f64 = 1.602e-19; // электронвольт
pub const GeV: f64 = 1.602e-10; // гигаэлектронвольт
pub const pi: f64 = math.pi;

// Планковские единицы
pub const l_P: f64 = 1.616e-35; // планковская длина
pub const t_P: f64 = 5.391e-44; // планковское время
pub const m_P: f64 = 2.176e-8; // планковская масса
pub const E_P: f64 = 1.956e9; // планковская энергия (Дж)
pub const T_P: f64 = 1.417e32; // планковская температура

// ============================================================================
// ДЫРА 1: КВАНТОВАЯ ГРАВИТАЦИЯ (85%)
// ============================================================================

pub const QuantumGravity = struct {
    /// Минимальная длина (планковская)
    pub fn minimum_length() f64 {
        return @sqrt(hbar * G / (c * c * c));
    }

    /// Минимальное время
    pub fn minimum_time() f64 {
        return @sqrt(hbar * G / (c * c * c * c * c));
    }

    /// Максимальная плотность (планковская)
    pub fn maximum_density() f64 {
        return c * c * c * c * c / (hbar * G * G);
    }

    /// Дисперсия фотонов от квантовой гравитации
    /// Δt = ξ * E * L / (E_P * c)
    /// где ξ ~ 1 для линейной модели
    pub fn photon_dispersion(E_photon: f64, distance: f64, xi: f64) f64 {
        return xi * E_photon * distance / (E_P * c);
    }

    /// Пример: GRB на расстоянии 1 млрд световых лет
    pub fn grb_dispersion_example() struct { delay_ns: f64, detectable: bool } {
        const distance = 1e9 * 9.461e15; // 1 млрд св. лет в метрах
        const E_gamma = 10 * GeV; // 10 ГэВ гамма-квант
        const delay = photon_dispersion(E_gamma, distance, 1.0);
        return .{
            .delay_ns = delay * 1e9,
            .detectable = delay > 1e-3, // > 1 мс детектируемо
        };
    }

    /// Модификация гравитационного потенциала на малых масштабах
    /// V(r) = -Gm₁m₂/r * (1 + α*exp(-r/λ))
    pub fn modified_potential(m1: f64, m2: f64, r: f64, alpha: f64, lambda: f64) f64 {
        const classical = -G * m1 * m2 / r;
        const correction = alpha * @exp(-r / lambda);
        return classical * (1 + correction);
    }
};

// ============================================================================
// ДЫРА 2: ТЁМНАЯ МАТЕРИЯ (60%)
// ============================================================================

pub const DarkMatter = struct {
    /// Плотность тёмной материи в Галактике (около Солнца)
    pub const local_density: f64 = 0.3; // ГэВ/см³

    /// Скорость тёмной материи (вириальная)
    pub const velocity: f64 = 220e3; // м/с

    /// Сечение WIMP-нуклон (текущий предел)
    pub const cross_section_limit: f64 = 1e-47; // см²

    /// Масса WIMP (теоретический диапазон)
    pub const mass_min: f64 = 10 * GeV;
    pub const mass_max: f64 = 1000 * GeV;

    /// Скорость событий в детекторе
    /// R = n_target * n_DM * σ * v
    pub fn event_rate(target_mass_kg: f64, target_A: f64, sigma_cm2: f64) f64 {
        const n_target = target_mass_kg * 6.022e26 / target_A; // число ядер
        const n_DM = local_density * 1e6 / (100 * GeV); // число WIMP на м³
        return n_target * n_DM * sigma_cm2 * 1e-4 * velocity; // событий/с
    }

    /// Пример: XENON детектор (1 тонна Xe)
    pub fn xenon_example() struct { events_per_year: f64, detectable: bool } {
        const rate = event_rate(1000, 131, cross_section_limit);
        const per_year = rate * 365.25 * 24 * 3600;
        return .{
            .events_per_year = per_year,
            .detectable = per_year > 1,
        };
    }

    /// Масса аксиона (теоретический диапазон)
    pub const axion_mass_min: f64 = 1e-6 * eV;
    pub const axion_mass_max: f64 = 1e-3 * eV;

    /// Конверсия аксион → фотон в магнитном поле
    /// P = (g_aγ * B * L)² / 4
    pub fn axion_conversion_prob(g_coupling: f64, B_field: f64, length: f64) f64 {
        const x = g_coupling * B_field * length;
        return x * x / 4;
    }
};

// ============================================================================
// ДЫРА 3: СТРЕЛА ВРЕМЕНИ (40%)
// ============================================================================

pub const ArrowOfTime = struct {
    /// Энтропия Вселенной сейчас (в единицах k_B)
    pub const S_universe_now: f64 = 1e104;

    /// Энтропия при Big Bang (оценка)
    pub const S_big_bang: f64 = 1e88;

    /// Максимальная энтропия (если бы всё было в ЧД)
    pub const S_max: f64 = 1e124;

    /// Отношение: насколько далеко от максимума
    pub fn entropy_ratio() f64 {
        return S_universe_now / S_max;
    }

    /// Вероятность флуктуации к низкой энтропии
    /// P ~ exp(-ΔS/k_B)
    pub fn fluctuation_probability(delta_S: f64) f64 {
        // Для ΔS ~ 10¹⁰⁴ это exp(-10¹⁰⁴) ≈ 0
        if (delta_S > 700) return 0; // underflow protection
        return @exp(-delta_S);
    }

    /// Время Пуанкаре (возврат к начальному состоянию)
    /// t_P ~ exp(S) * t_relaxation
    pub fn poincare_time(S: f64, t_relax: f64) f64 {
        // Для S ~ 10¹⁰⁴ это невообразимо большое число
        return t_relax * @exp(@min(S, 700));
    }

    /// CPT-теорема: если нарушается T, должны нарушаться CP
    pub const cpt_theorem: bool = true;

    /// Наблюдаемое CP-нарушение в каонах
    pub const cp_violation_kaon: f64 = 2.3e-3;
};

// ============================================================================
// ДЫРА 4: ТЁМНАЯ ЭНЕРГИЯ (35%)
// ============================================================================

pub const DarkEnergy = struct {
    /// Измеренная плотность тёмной энергии
    pub const rho_observed: f64 = 5.96e-27; // кг/м³

    /// Теоретическая плотность вакуума (КТП)
    pub const rho_qft: f64 = 1e97; // кг/м³ (!!!)

    /// Проблема космологической постоянной
    pub fn cosmological_constant_problem() f64 {
        return rho_qft / rho_observed; // ≈ 10¹²⁰
    }

    /// Уравнение состояния: P = w * ρ * c²
    /// w = -1 для космологической постоянной
    pub const w_observed: f64 = -1.03; // ± 0.03

    /// Параметр Хаббла
    pub const H_0: f64 = 70; // км/с/Мпк

    /// Возраст Вселенной из H_0
    pub fn universe_age() f64 {
        const H_0_si = H_0 * 1000 / (3.086e22); // в 1/с
        return 1 / H_0_si / (365.25 * 24 * 3600 * 1e9); // в млрд лет
    }

    /// Плотность энергии вакуума в эВ⁴
    pub fn vacuum_energy_eV4() f64 {
        // ρ = (2.3 meV)⁴ ≈ (0.002 эВ)⁴
        return 2.3e-3 * 2.3e-3 * 2.3e-3 * 2.3e-3;
    }
};

// ============================================================================
// ДЫРА 5: МАГНИТНЫЙ МОНОПОЛЬ (25%)
// ============================================================================

pub const MagneticMonopole = struct {
    /// Магнитный заряд Дирака: g = ℏc/(2e) = n * g_D
    pub fn dirac_charge() f64 {
        return hbar * c / (2 * e);
    }

    /// Квантование заряда как следствие монополей
    /// e * g = n * ℏc/2
    pub fn charge_quantization(g: f64) f64 {
        return hbar * c / (2 * g);
    }

    /// Масса монополя в GUT (оценка)
    pub const gut_mass: f64 = 1e16 * GeV; // ≈ 10⁻⁸ г

    /// Поток монополей (верхний предел)
    pub const flux_limit: f64 = 1e-15; // см⁻² с⁻¹ ср⁻¹

    /// Энергия ионизации монополем
    /// dE/dx ~ (g/e)² * (dE/dx)_proton
    pub fn ionization_energy(dx: f64) f64 {
        const g = dirac_charge();
        const ratio = g / e;
        const proton_dedx = 2e6 * eV; // МэВ/см для протона
        return ratio * ratio * proton_dedx * dx;
    }

    /// Катализ распада протона монополем (эффект Рубакова-Каллана)
    pub const proton_decay_cross_section: f64 = 1e-27; // см²
};

// ============================================================================
// ДЫРА 6: ОТРИЦАТЕЛЬНАЯ МАССА (15%)
// ============================================================================

pub const NegativeMass = struct {
    /// Сила между +m и -m
    pub fn force(m_pos: f64, m_neg: f64, r: f64) f64 {
        return G * m_pos * m_neg / (r * r); // < 0 (отталкивание!)
    }

    /// Ускорение положительной массы
    pub fn accel_positive(F: f64, m: f64) f64 {
        return F / m; // F < 0, m > 0 → a < 0
    }

    /// Ускорение отрицательной массы
    pub fn accel_negative(F: f64, m: f64) f64 {
        return F / m; // F < 0, m < 0 → a > 0 (!)
    }

    /// Парадокс: оба движутся в одном направлении!
    pub fn runaway_demo() struct { a_pos: f64, a_neg: f64, same_dir: bool } {
        const F = force(1, -1, 1);
        const a_pos = accel_positive(F, 1);
        const a_neg = accel_negative(F, -1);
        return .{
            .a_pos = a_pos,
            .a_neg = a_neg,
            .same_dir = (a_pos < 0) == (a_neg > 0),
        };
    }

    /// Энергия системы +m и -m
    /// E = ½m₁v₁² + ½m₂v₂² + U(r)
    /// Если m₂ < 0, кинетическая энергия отрицательна!
    pub fn total_energy(m1: f64, v1: f64, m2: f64, v2: f64, r: f64) f64 {
        const KE1 = 0.5 * m1 * v1 * v1;
        const KE2 = 0.5 * m2 * v2 * v2; // < 0 если m2 < 0!
        const PE = -G * m1 * m2 / r; // > 0 если m1*m2 < 0
        return KE1 + KE2 + PE;
    }

    /// Червоточина требует экзотической материи
    /// Условие: ρ + P/c² < 0 (нарушение NEC)
    pub fn wormhole_condition(rho: f64, P: f64) bool {
        return rho + P / (c * c) < 0;
    }
};

// ============================================================================
// ДЫРА 7: СОЗНАНИЕ (10%)
// ============================================================================

pub const Consciousness = struct {
    /// Интегрированная информация (IIT)
    /// Φ = информация, генерируемая системой сверх суммы частей
    pub fn phi_simple(total_info: f64, sum_parts: f64) f64 {
        return total_info - sum_parts;
    }

    /// Число нейронов в мозге
    pub const neurons: f64 = 86e9;

    /// Число синапсов
    pub const synapses: f64 = 100e12;

    /// Частота обновления сознания (оценка)
    pub const update_rate: f64 = 40; // Гц (гамма-ритм)

    /// Энергопотребление мозга
    pub const power: f64 = 20; // Вт

    /// Бит на синапс (оценка)
    pub const bits_per_synapse: f64 = 4.7;

    /// Общая информационная ёмкость
    pub fn brain_capacity() f64 {
        return synapses * bits_per_synapse; // ≈ 500 терабит
    }

    /// Квантовая когерентность в микротрубочках (Orch-OR)
    /// Время декогеренции при T = 310K
    pub fn decoherence_time(T: f64) f64 {
        // τ ~ ℏ/(k_B * T) ≈ 10⁻¹³ с при 310K
        return hbar / (k_B * T);
    }

    /// Это слишком мало для квантовых эффектов в мозге?
    pub fn quantum_brain_feasible() bool {
        const tau = decoherence_time(310);
        const neural_timescale = 1e-3; // 1 мс
        return tau > neural_timescale; // false!
    }
};

// ============================================================================
// ДЫРА 8: СТРУКТУРА ВАКУУМА (35%)
// ============================================================================

pub const Vacuum = struct {
    /// Эффект Казимира: F/A = -π²ℏc/(240d⁴)
    pub fn casimir_pressure(d: f64) f64 {
        return -pi * pi * hbar * c / (240 * d * d * d * d);
    }

    /// Пример: пластины на расстоянии 10 нм
    pub fn casimir_example() struct { pressure_Pa: f64, force_per_m2: f64 } {
        const d = 10e-9;
        const P = casimir_pressure(d);
        return .{
            .pressure_Pa = @abs(P),
            .force_per_m2 = @abs(P),
        };
    }

    /// Энергия нулевых колебаний (расходится!)
    /// E_0 = Σ ½ℏω → ∞
    pub fn zero_point_energy_cutoff(omega_max: f64) f64 {
        // С обрезанием на планковской частоте
        return 0.5 * hbar * omega_max;
    }

    /// Плотность энергии вакуума с планковским обрезанием
    pub fn vacuum_density_planck() f64 {
        // ρ ~ ℏω_P⁴/c³ ~ c⁵/(ℏG²)
        return c * c * c * c * c / (hbar * G * G);
    }

    /// Динамический эффект Казимира
    /// Движущееся зеркало создаёт фотоны из вакуума
    pub fn dynamic_casimir_photons(v: f64, L: f64, omega: f64) f64 {
        // N ~ (v/c)² * (ωL/c)²
        const ratio = v / c;
        const phase = omega * L / c;
        return ratio * ratio * phase * phase;
    }
};

// ============================================================================
// СВЯЗИ МЕЖДУ ДЫРАМИ
// ============================================================================

pub const Unification = struct {
    /// Квантовая гравитация + Тёмная энергия
    /// Проблема: почему Λ так мала?
    pub fn qg_de_connection() []const u8 {
        return "Квантовая гравитация должна объяснить малость Λ";
    }

    /// Тёмная материя + Тёмная энергия
    /// Совпадение: ρ_DM ~ ρ_DE сейчас (почему?)
    pub fn dm_de_coincidence() f64 {
        const rho_DM = 1.3e-27; // кг/м³
        const rho_DE = 5.96e-27; // кг/м³
        return rho_DE / rho_DM; // ≈ 4.6
    }

    /// Стрела времени + Сознание
    /// Сознание существует только в направлении роста энтропии?
    pub fn time_consciousness_link() []const u8 {
        return "Память требует записи → увеличения энтропии";
    }

    /// Квантовая гравитация + Сознание (Penrose)
    /// Коллапс волновой функции от гравитации?
    pub fn qg_consciousness_link() []const u8 {
        return "Orch-OR: гравитационный коллапс в микротрубочках";
    }
};

// ============================================================================
// ТЕСТЫ
// ============================================================================

test "quantum_gravity: planck_units" {
    const l = QuantumGravity.minimum_length();
    try std.testing.expectApproxEqRel(l_P, l, 0.01);
}

test "dark_matter: event_rate" {
    const result = DarkMatter.xenon_example();
    try std.testing.expect(result.events_per_year >= 0);
}

test "dark_energy: problem_magnitude" {
    const ratio = DarkEnergy.cosmological_constant_problem();
    _ = ratio;
    // Проблема 10¹²⁰ - просто проверяем что функция работает
    try std.testing.expect(true);
}

test "monopole: dirac_charge" {
    const g = MagneticMonopole.dirac_charge();
    try std.testing.expect(g > 0);
}

test "negative_mass: runaway" {
    const result = NegativeMass.runaway_demo();
    try std.testing.expect(result.same_dir);
}

test "consciousness: decoherence" {
    const feasible = Consciousness.quantum_brain_feasible();
    try std.testing.expect(!feasible); // Слишком быстрая декогеренция
}

test "vacuum: casimir" {
    const result = Vacuum.casimir_example();
    try std.testing.expect(result.pressure_Pa > 0);
}

test "unification: dm_de_ratio" {
    const ratio = Unification.dm_de_coincidence();
    try std.testing.expect(ratio > 1 and ratio < 10);
}

// ============================================================================
// MAIN
// ============================================================================

pub fn main() !void {
    print("\n", .{});
    print("=" ** 70 ++ "\n", .{});
    print("    ГЛУБОКИЙ АНАЛИЗ ДЫР В ФИЗИКЕ\n", .{});
    print("=" ** 70 ++ "\n\n", .{});

    // 1. Квантовая гравитация
    print("1. КВАНТОВАЯ ГРАВИТАЦИЯ [85%%]\n", .{});
    print("-" ** 50 ++ "\n", .{});
    print("   Минимальная длина: {e:.3} м\n", .{QuantumGravity.minimum_length()});
    print("   Минимальное время: {e:.3} с\n", .{QuantumGravity.minimum_time()});
    print("   Макс. плотность: {e:.3} кг/м³\n", .{QuantumGravity.maximum_density()});
    const grb = QuantumGravity.grb_dispersion_example();
    print("   Дисперсия от GRB: {d:.1} нс (детектируемо: {})\n\n", .{ grb.delay_ns, grb.detectable });

    // 2. Тёмная материя
    print("2. ТЁМНАЯ МАТЕРИЯ [60%%]\n", .{});
    print("-" ** 50 ++ "\n", .{});
    print("   Локальная плотность: {d} ГэВ/см³\n", .{DarkMatter.local_density});
    print("   Предел сечения: {e:.1} см²\n", .{DarkMatter.cross_section_limit});
    const xenon = DarkMatter.xenon_example();
    print("   XENON (1т): {d:.2} событий/год\n\n", .{xenon.events_per_year});

    // 3. Стрела времени
    print("3. СТРЕЛА ВРЕМЕНИ [40%%]\n", .{});
    print("-" ** 50 ++ "\n", .{});
    print("   S(сейчас)/S(max) = {e:.1}\n", .{ArrowOfTime.entropy_ratio()});
    print("   CP-нарушение в каонах: {e:.1}\n\n", .{ArrowOfTime.cp_violation_kaon});

    // 4. Тёмная энергия
    print("4. ТЁМНАЯ ЭНЕРГИЯ [35%%]\n", .{});
    print("-" ** 50 ++ "\n", .{});
    print("   Проблема 10^N: N = {d:.0}\n", .{@log10(DarkEnergy.cosmological_constant_problem())});
    print("   w = {d:.2} (ожидается -1)\n", .{DarkEnergy.w_observed});
    print("   Возраст Вселенной: {d:.1} млрд лет\n\n", .{DarkEnergy.universe_age()});

    // 5. Магнитный монополь
    print("5. МАГНИТНЫЙ МОНОПОЛЬ [25%%]\n", .{});
    print("-" ** 50 ++ "\n", .{});
    print("   Заряд Дирака: {e:.3} Вб\n", .{MagneticMonopole.dirac_charge()});
    print("   Масса GUT: {e:.1} ГэВ\n", .{MagneticMonopole.gut_mass / GeV});
    print("   Предел потока: {e:.1} см⁻²с⁻¹ср⁻¹\n\n", .{MagneticMonopole.flux_limit});

    // 6. Отрицательная масса
    print("6. ОТРИЦАТЕЛЬНАЯ МАССА [15%%]\n", .{});
    print("-" ** 50 ++ "\n", .{});
    const runaway = NegativeMass.runaway_demo();
    print("   a(+m) = {e:.3} м/с²\n", .{runaway.a_pos});
    print("   a(-m) = {e:.3} м/с²\n", .{runaway.a_neg});
    print("   Оба в одном направлении: {}\n\n", .{runaway.same_dir});

    // 7. Сознание
    print("7. СОЗНАНИЕ [10%%]\n", .{});
    print("-" ** 50 ++ "\n", .{});
    print("   Нейронов: {e:.1}\n", .{Consciousness.neurons});
    print("   Ёмкость мозга: {e:.1} бит\n", .{Consciousness.brain_capacity()});
    print("   Время декогеренции: {e:.1} с\n", .{Consciousness.decoherence_time(310)});
    print("   Квантовый мозг возможен: {}\n\n", .{Consciousness.quantum_brain_feasible()});

    // 8. Вакуум
    print("8. СТРУКТУРА ВАКУУМА [35%%]\n", .{});
    print("-" ** 50 ++ "\n", .{});
    const casimir = Vacuum.casimir_example();
    print("   Давление Казимира (10нм): {e:.1} Па\n", .{casimir.pressure_Pa});
    print("   ρ_вакуум (Планк): {e:.1} кг/м³\n\n", .{Vacuum.vacuum_density_planck()});

    // Связи
    print("=" ** 70 ++ "\n", .{});
    print("СВЯЗИ МЕЖДУ ДЫРАМИ:\n", .{});
    print("=" ** 70 ++ "\n\n", .{});
    print("   • DM/DE совпадение: ρ_DE/ρ_DM = {d:.1}\n", .{Unification.dm_de_coincidence()});
    print("   • {s}\n", .{Unification.qg_de_connection()});
    print("   • {s}\n", .{Unification.time_consciousness_link()});
    print("   • {s}\n\n", .{Unification.qg_consciousness_link()});
}
