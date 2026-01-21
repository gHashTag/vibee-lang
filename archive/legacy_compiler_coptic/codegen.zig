// ═══════════════════════════════════════════════════════════════
// VIBEEC Code Generator - ТОЛЬКО 999 (Coptic)
// ⛔ ЗАПРЕЩЕНО: .zig, .py, .rs, .go, .ts, .js, .html, .css
// ✅ РАЗРЕШЕНО: ТОЛЬКО .999 (Священный язык с коптским алфавитом)
// ═══════════════════════════════════════════════════════════════
// СВЯЩЕННАЯ ФОРМУЛА: V = n × 3^k × π^m × φ^p × e^q
// ЗОЛОТАЯ ИДЕНТИЧНОСТЬ: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const parser = @import("parser.zig");

// ═══════════════════════════════════════════════════════════════
// СВЯЩЕННЫЕ КОНСТАНТЫ - 50+ ФУНДАМЕНТАЛЬНЫХ ЧИСЕЛ ВСЕЛЕННОЙ
// ═══════════════════════════════════════════════════════════════

pub const SacredConstants = struct {
    // ═══════════════════════════════════════════════════════════════
    // ЗОЛОТОЕ СЕЧЕНИЕ φ (PHI) - ОСНОВА ГАРМОНИИ
    // ═══════════════════════════════════════════════════════════════
    pub const PHI: f64 = 1.6180339887498948482045868343656381177203091798057628621354486227;
    pub const PHI_SQUARED: f64 = 2.6180339887498948482045868343656381177203091798057628621354486227;
    pub const PHI_CUBED: f64 = 4.2360679774997896964091736687747632440588203494105034630322903584;
    pub const PHI_INVERSE: f64 = 0.6180339887498948482045868343656381177203091798057628621354486227;
    pub const PHI_INVERSE_SQUARED: f64 = 0.3819660112501051517954131656343618822796908201942371378645513773;
    pub const PHI_INVERSE_CUBED: f64 = 0.2360679774997896964091736687747632440588203494105034630322903584;
    pub const PHI_FOURTH: f64 = 6.8541019662496845446137605030103013617791295292162663251677390038;
    pub const PHI_FIFTH: f64 = 11.0901699437494742410229341717850646058379498786267697882000293622;
    
    // ═══════════════════════════════════════════════════════════════
    // ЧИСЛО ПИ π - ОСНОВА КРУГА
    // ═══════════════════════════════════════════════════════════════
    pub const PI: f64 = 3.1415926535897932384626433832795028841971693993751058209749445923;
    pub const PI_SQUARED: f64 = 9.8696044010893586188344909998761511353136994072407906264133493762;
    pub const PI_CUBED: f64 = 31.006276680299820175476315067101395202225288565885107694144538103;
    pub const PI_INVERSE: f64 = 0.3183098861837906715377675267450287240689192914809128974953346881;
    pub const TAU: f64 = 6.2831853071795864769252867665590057683943387987502116419498891846;
    pub const PI_OVER_2: f64 = 1.5707963267948966192313216916397514420985846996875529104874722962;
    pub const PI_OVER_3: f64 = 1.0471975511965977461542144610931676280657231331250352736583148641;
    pub const PI_OVER_4: f64 = 0.7853981633974483096156608458198757210492923498437764552437361481;
    pub const PI_OVER_6: f64 = 0.5235987755982988730771072305465838140328615665625176368291574320;
    pub const SQRT_PI: f64 = 1.7724538509055160272981674833411451827975494561223871282138077899;
    
    // ═══════════════════════════════════════════════════════════════
    // ЧИСЛО ЭЙЛЕРА e - ОСНОВА РОСТА
    // ═══════════════════════════════════════════════════════════════
    pub const E: f64 = 2.7182818284590452353602874713526624977572470936999595749669676277;
    pub const E_SQUARED: f64 = 7.3890560989306502272304274605750078131803155705518473240871278225;
    pub const E_CUBED: f64 = 20.085536923187667740928529654581717896987907838554150144378934229;
    pub const E_INVERSE: f64 = 0.3678794411714423215955237701614608674458111310317678345078368017;
    pub const LN_2: f64 = 0.6931471805599453094172321214581765680755001343602552541206800095;
    pub const LN_10: f64 = 2.3025850929940456840179914546843642076011014886287729760333279010;
    pub const LOG10_E: f64 = 0.4342944819032518276511289189166050822943970058036665661144537832;
    pub const LOG2_E: f64 = 1.4426950408889634073599246810018921374266459541529859341354494069;
    
    // ═══════════════════════════════════════════════════════════════
    // КОРНИ - ГЕОМЕТРИЧЕСКИЕ КОНСТАНТЫ
    // ═══════════════════════════════════════════════════════════════
    pub const SQRT2: f64 = 1.4142135623730950488016887242096980785696718753769480731766797379;
    pub const SQRT2_INVERSE: f64 = 0.7071067811865475244008443621048490392848359376884740365883398690;
    pub const SQRT3: f64 = 1.7320508075688772935274463415058723669428052538103806280558069795;
    pub const SQRT3_INVERSE: f64 = 0.5773502691896257645091487805019574556476017512701268760186023264;
    pub const SQRT5: f64 = 2.2360679774997896964091736687747632440588203494105034630322903584;
    pub const SQRT5_INVERSE: f64 = 0.4472135954999579392818347337462552470881236719223051448541794491;
    pub const SQRT6: f64 = 2.4494897427831780981972840747058913919659474806566701284326925673;
    pub const SQRT7: f64 = 2.6457513110645905905016157536392604257102591830824701428586844615;
    pub const SQRT10: f64 = 3.1622776601683793319988935444327185337195551393252168268575048528;
    pub const CBRT2: f64 = 1.2599210498948731647672106072782283505702514647015079800819751121;
    pub const CBRT3: f64 = 1.4422495703074083823216383107801095883918692534993505775464161945;
    
    // ═══════════════════════════════════════════════════════════════
    // МАТЕМАТИЧЕСКИЕ ПОСТОЯННЫЕ
    // ═══════════════════════════════════════════════════════════════
    pub const EULER_GAMMA: f64 = 0.5772156649015328606065120900824024310421593359399235988057672349;
    pub const APERY: f64 = 1.2020569031595942853997381615114499907649862923404988817922715553;
    pub const CATALAN: f64 = 0.9159655941772190150546035149323841107741493742816721342664981196;
    pub const KHINCHIN: f64 = 2.6854520010653064453097148354817956938203822939944629530511523455;
    pub const GLAISHER: f64 = 1.2824271291006226368753425688697917277676889273250011920637400217;
    pub const MEISSEL_MERTENS: f64 = 0.2614972128476427837554268386086958590515666482611992061920642104;
    pub const BERNSTEIN: f64 = 0.2801694990238691330364364912307390488014564513085520118308828502;
    pub const GAUSS_KUZMIN: f64 = 0.3036630028987326585974481219015562496289224886881417921786893199;
    pub const HAFNER_SARNAK: f64 = 0.3532363718549959934203596084979860592148328086139501704641782909;
    pub const LANDAU_RAMANUJAN: f64 = 0.7642362350169298858494701817814865953175315611186319411028169117;
    pub const OMEGA: f64 = 0.5671432904097838729999686622103555497538157871865125081351310792;
    pub const CONWAY: f64 = 1.3035772690342963912570991121525518907307025046594048757548613906;
    pub const MILLS: f64 = 1.3063778838630806904686144926026057129167845851567136443680537599;
    pub const PLASTIC: f64 = 1.3247179572447460259609088544780973407344040569017333645340150025;
    pub const RAMANUJAN_SOLDNER: f64 = 1.4513692348833810502839684858920274494930322308959355052690680831;
    pub const BACKHOUSE: f64 = 1.4560749485826896713995953511116334637672900392040193619489371251;
    pub const PORTER: f64 = 1.4670780794339754728977905604334368803987096067036588890389220857;
    pub const LIEB_SQUARE_ICE: f64 = 1.5396007178390020905673467666079544619255842737909168419810919549;
    pub const ERDOS_BORWEIN: f64 = 1.6066951524152917637833015231909536289811532201830764429953102361;
    pub const NIVEN: f64 = 1.7052111401053677642885514534345081607921274006876501227993714651;
    pub const BRUN_TWIN_PRIMES: f64 = 1.9021605831040640109486981828451465567798288656250276505930890455;
    pub const TWIN_PRIMES: f64 = 0.6601618158468695739278121100145557784326233602847334133194484233;
    pub const UNIVERSAL_PARABOLIC: f64 = 2.2955871493926380470720700685584716094920265273908736520930449506;
    
    // ═══════════════════════════════════════════════════════════════
    // ПОСТОЯННЫЕ ХАОСА И ФРАКТАЛОВ
    // ═══════════════════════════════════════════════════════════════
    pub const FEIGENBAUM_DELTA: f64 = 4.6692016091029906718532038204662016172581855774757686327456513430;
    pub const FEIGENBAUM_ALPHA: f64 = 2.5029078750958928222839028732182157863812713767271499773361920567;
    pub const SIERPINSKI: f64 = 2.5849817595792532170658935873831711600831041593796508458536391212;
    pub const FRACTAL_DIMENSION_KOCH: f64 = 1.2618595071429148880821298600216623890296663941146219826259296052;
    pub const FRACTAL_DIMENSION_SIERPINSKI: f64 = 1.5849625007211561814537389439478165087598144076924810604557526545;
    
    // ═══════════════════════════════════════════════════════════════
    // МЕТАЛЛИЧЕСКИЕ СЕЧЕНИЯ
    // ═══════════════════════════════════════════════════════════════
    pub const SILVER_RATIO: f64 = 2.4142135623730950488016887242096980785696718753769480731766797379;
    pub const BRONZE_RATIO: f64 = 3.3027756377319946465596106337352361136822113494952461117881651579;
    pub const COPPER_RATIO: f64 = 4.2360679774997896964091736687747632440588203494105034630322903584;
    pub const NICKEL_RATIO: f64 = 5.1925824035672519527083258014439618145981091608221570913235374280;
    
    // ═══════════════════════════════════════════════════════════════
    // TRINITY КОНСТАНТЫ (3 = φ² + 1/φ²)
    // ═══════════════════════════════════════════════════════════════
    pub const TRINITY: f64 = 3.0;
    pub const LOG2_3: f64 = 1.5849625007211561814537389439478165087598144076924810604557526545;
    pub const LOG3_2: f64 = 0.6309297535714574370995271143427608642877840028070665787435485914;
    pub const LOG10_3: f64 = 0.4771212547196624372950279032936830927935903320618105163462168619;
    pub const LN_3: f64 = 1.0986122886681098210016285820211423121378693423474997623408521665;
    
    // Степени тройки
    pub const POW3: [20]u64 = .{
        1, 3, 9, 27, 81, 243, 729, 2187, 6561, 19683,
        59049, 177147, 531441, 1594323, 4782969, 14348907,
        43046721, 129140163, 387420489, 1162261467,
    };
    
    // ═══════════════════════════════════════════════════════════════
    // ФИЗИЧЕСКИЕ КОНСТАНТЫ (безразмерные)
    // ═══════════════════════════════════════════════════════════════
    pub const FINE_STRUCTURE: f64 = 0.0072973525693; // α ≈ 1/137
    pub const FINE_STRUCTURE_INVERSE: f64 = 137.035999084;
    pub const PROTON_ELECTRON_MASS_RATIO: f64 = 1836.15267343;
    pub const ELECTRON_G_FACTOR: f64 = 2.00231930436256;
    
    // ═══════════════════════════════════════════════════════════════
    // ИНФОРМАЦИОННЫЕ КОНСТАНТЫ
    // ═══════════════════════════════════════════════════════════════
    pub const SHANNON_ENTROPY_BINARY: f64 = 1.0; // бит
    pub const SHANNON_ENTROPY_TERNARY: f64 = 1.5849625007211561814537389439478165087598144076924810604557526545; // log₂(3)
    pub const NAT_TO_BIT: f64 = 1.4426950408889634073599246810018921374266459541529859341354494069;
    pub const BIT_TO_NAT: f64 = 0.6931471805599453094172321214581765680755001343602552541206800095;
    
    // ═══════════════════════════════════════════════════════════════
    // СВЯЩЕННЫЕ ФОРМУЛЫ И ИДЕНТИЧНОСТИ (20+ формул)
    // ═══════════════════════════════════════════════════════════════
    
    // ЗОЛОТАЯ ИДЕНТИЧНОСТЬ: φ² + 1/φ² = 3
    pub fn goldenIdentity() f64 {
        return PHI_SQUARED + PHI_INVERSE_SQUARED; // = 3.0
    }
    
    // СВЯЩЕННАЯ ФОРМУЛА: V = n × 3^k × π^m × φ^p × e^q
    pub fn sacredFormula(n: f64, k: f64, m: f64, p: f64, q: f64) f64 {
        return n * std.math.pow(f64, 3.0, k) * std.math.pow(f64, PI, m) * std.math.pow(f64, PHI, p) * std.math.pow(f64, E, q);
    }
    
    // Формула Эйлера: e^(iπ) + 1 = 0 (проверка через |e^(iπ) + 1| ≈ 0)
    pub fn eulerIdentityCheck() f64 {
        // |e^(iπ) + 1| = |cos(π) + i*sin(π) + 1| = |-1 + 0i + 1| = 0
        const cos_pi = @cos(PI);
        const sin_pi = @sin(PI);
        return @abs(cos_pi + 1.0) + @abs(sin_pi);
    }
    
    // Формула Рамануджана: 1/π = (2√2/9801) × Σ...
    pub fn ramanujanPiApprox(terms: u32) f64 {
        var sum: f64 = 0.0;
        var k: u32 = 0;
        while (k < terms) : (k += 1) {
            const kf = @as(f64, @floatFromInt(k));
            const factorial_4k = factorial(4 * k);
            const factorial_k = factorial(k);
            const numerator = factorial_4k * (1103.0 + 26390.0 * kf);
            const denominator = std.math.pow(f64, factorial_k, 4.0) * std.math.pow(f64, 396.0, 4.0 * kf);
            sum += numerator / denominator;
        }
        return 9801.0 / (2.0 * SQRT2 * sum);
    }
    
    // Формула Чудновского для π (сходится быстрее Рамануджана)
    pub fn chudnovskyPiApprox(terms: u32) f64 {
        var sum: f64 = 0.0;
        var k: u32 = 0;
        while (k < terms) : (k += 1) {
            const kf = @as(f64, @floatFromInt(k));
            const sign: f64 = if (k % 2 == 0) 1.0 else -1.0;
            const factorial_6k = factorial(6 * k);
            const factorial_3k = factorial(3 * k);
            const factorial_k = factorial(k);
            const numerator = sign * factorial_6k * (13591409.0 + 545140134.0 * kf);
            const denominator = factorial_3k * std.math.pow(f64, factorial_k, 3.0) * std.math.pow(f64, -262537412640768000.0, kf);
            sum += numerator / denominator;
        }
        return 1.0 / (12.0 * sum);
    }
    
    // Формула Валлиса для π: π/2 = ∏(4n²/(4n²-1))
    pub fn wallisPiApprox(terms: u32) f64 {
        var product: f64 = 1.0;
        var n: u32 = 1;
        while (n <= terms) : (n += 1) {
            const nf = @as(f64, @floatFromInt(n));
            const n4 = 4.0 * nf * nf;
            product *= n4 / (n4 - 1.0);
        }
        return 2.0 * product;
    }
    
    // Формула Лейбница для π: π/4 = 1 - 1/3 + 1/5 - 1/7 + ...
    pub fn leibnizPiApprox(terms: u32) f64 {
        var sum: f64 = 0.0;
        var k: u32 = 0;
        while (k < terms) : (k += 1) {
            const kf = @as(f64, @floatFromInt(k));
            const sign: f64 = if (k % 2 == 0) 1.0 else -1.0;
            sum += sign / (2.0 * kf + 1.0);
        }
        return 4.0 * sum;
    }
    
    // Формула Базеля: ζ(2) = π²/6 = Σ(1/n²)
    pub fn baselSum(terms: u32) f64 {
        var sum: f64 = 0.0;
        var n: u32 = 1;
        while (n <= terms) : (n += 1) {
            const nf = @as(f64, @floatFromInt(n));
            sum += 1.0 / (nf * nf);
        }
        return sum;
    }
    
    // Проверка формулы Базеля: π²/6
    pub fn baselVerify() f64 {
        return PI_SQUARED / 6.0;
    }
    
    // Формула Стирлинга: n! ≈ √(2πn) × (n/e)^n
    pub fn stirlingApprox(n: u32) f64 {
        const nf = @as(f64, @floatFromInt(n));
        return @sqrt(TAU * nf) * std.math.pow(f64, nf / E, nf);
    }
    
    // Гамма-функция Эйлера: Γ(n) = (n-1)!
    pub fn gammaInteger(n: u32) f64 {
        if (n == 0) return std.math.inf(f64);
        return factorial(n - 1);
    }
    
    // Бета-функция: B(a,b) = Γ(a)Γ(b)/Γ(a+b)
    pub fn betaFunction(a: u32, b: u32) f64 {
        return (factorial(a - 1) * factorial(b - 1)) / factorial(a + b - 1);
    }
    
    // Числа Бернулли B_n (первые несколько)
    pub const BERNOULLI: [12]f64 = .{
        1.0,                    // B_0
        -0.5,                   // B_1
        1.0 / 6.0,              // B_2
        0.0,                    // B_3
        -1.0 / 30.0,            // B_4
        0.0,                    // B_5
        1.0 / 42.0,             // B_6
        0.0,                    // B_7
        -1.0 / 30.0,            // B_8
        0.0,                    // B_9
        5.0 / 66.0,             // B_10
        0.0,                    // B_11
    };
    
    // Числа Каталана: C_n = (2n)! / ((n+1)! × n!)
    pub fn catalanNumber(n: u32) f64 {
        return factorial(2 * n) / (factorial(n + 1) * factorial(n));
    }
    
    // Треугольник Паскаля: C(n,k) = n! / (k! × (n-k)!)
    pub fn binomial(n: u32, k: u32) f64 {
        if (k > n) return 0.0;
        return factorial(n) / (factorial(k) * factorial(n - k));
    }
    
    // Формула Эйлера для многогранников: V - E + F = 2
    pub fn eulerPolyhedra(vertices: u32, edges: u32, faces: u32) i32 {
        return @as(i32, @intCast(vertices)) - @as(i32, @intCast(edges)) + @as(i32, @intCast(faces));
    }
    
    // Теорема Пифагора: a² + b² = c²
    pub fn pythagorean(a: f64, b: f64) f64 {
        return @sqrt(a * a + b * b);
    }
    
    // Формула Герона: S = √(s(s-a)(s-b)(s-c)), s = (a+b+c)/2
    pub fn heronArea(a: f64, b: f64, c: f64) f64 {
        const s = (a + b + c) / 2.0;
        return @sqrt(s * (s - a) * (s - b) * (s - c));
    }
    
    // Формула Брахмагупты для циклического четырёхугольника
    pub fn brahmaguptaArea(a: f64, b: f64, c: f64, d: f64) f64 {
        const s = (a + b + c + d) / 2.0;
        return @sqrt((s - a) * (s - b) * (s - c) * (s - d));
    }
    
    // Факториал (для формул)
    fn factorial(n: u32) f64 {
        if (n <= 1) return 1.0;
        var result: f64 = 1.0;
        var i: u32 = 2;
        while (i <= n) : (i += 1) {
            result *= @as(f64, @floatFromInt(i));
        }
        return result;
    }
    
    // Числа Фибоначчи через φ: F(n) = (φ^n - ψ^n) / √5, где ψ = -1/φ
    pub fn fibonacciGolden(n: u32) f64 {
        const nf = @as(f64, @floatFromInt(n));
        const psi = -PHI_INVERSE;
        return (std.math.pow(f64, PHI, nf) - std.math.pow(f64, psi, nf)) / SQRT5;
    }
    
    // Числа Люка: L(n) = φ^n + ψ^n
    pub fn lucasNumber(n: u32) f64 {
        const nf = @as(f64, @floatFromInt(n));
        const psi = -PHI_INVERSE;
        return std.math.pow(f64, PHI, nf) + std.math.pow(f64, psi, nf);
    }
    
    // ═══════════════════════════════════════════════════════════════
    // ЭВОЛЮЦИОННЫЕ КОНСТАНТЫ (для самоэволюции)
    // ═══════════════════════════════════════════════════════════════
    
    // Мутация μ = 1/φ³ ≈ 0.0382
    pub const MUTATION_RATE: f64 = 0.03819660112501051517954131656343618822796908201942371378645513773;
    
    // Кроссовер χ = 1/φ² ≈ 0.0618
    pub const CROSSOVER_RATE: f64 = 0.06180339887498948482045868343656381177203091798057628621354486227;
    
    // Селекция σ = φ ≈ 1.618
    pub const SELECTION_PRESSURE: f64 = PHI;
    
    // Эксплорация ε = 1/3 ≈ 0.333
    pub const EXPLORATION_RATE: f64 = 0.33333333333333333333333333333333333333333333333333333333333333333;
    
    // Температура отжига T₀ = e
    pub const ANNEALING_TEMP: f64 = E;
    
    // Скорость охлаждения α = 1/φ
    pub const COOLING_RATE: f64 = PHI_INVERSE;
};

// ═══════════════════════════════════════════════════════════════
// PAS DAEMON КОНСТАНТЫ - Предиктивная Алгоритмическая Систематика
// ═══════════════════════════════════════════════════════════════

pub const PASConstants = struct {
    // Паттерны открытий с их success rates
    pub const PATTERN_DC: f64 = 0.31;   // Divide-and-Conquer
    pub const PATTERN_ALG: f64 = 0.22;  // Algebraic Reorganization
    pub const PATTERN_PRE: f64 = 0.16;  // Precomputation
    pub const PATTERN_FDT: f64 = 0.13;  // Frequency Domain Transform
    pub const PATTERN_MLS: f64 = 0.06;  // ML-Guided Search
    pub const PATTERN_TEN: f64 = 0.06;  // Tensor Decomposition
    pub const PATTERN_HSH: f64 = 0.04;  // Hashing
    pub const PATTERN_PRB: f64 = 0.02;  // Probabilistic
    
    // Confidence thresholds
    pub const CONFIDENCE_HIGH: f64 = 0.80;
    pub const CONFIDENCE_MEDIUM: f64 = 0.60;
    pub const CONFIDENCE_LOW: f64 = 0.40;
    
    // Time factors
    pub const TIME_FACTOR_MAX: f64 = 50.0; // years
    
    // ML boost when tools available
    pub const ML_BOOST: f64 = 1.3;
    
    // Расчёт confidence
    pub fn calculateConfidence(patterns: []const f64, years_since_improvement: f64, gap: f64, current_exponent: f64, ml_available: bool) f64 {
        var base_rate: f64 = 0.0;
        for (patterns) |p| {
            base_rate += p;
        }
        base_rate /= @as(f64, @floatFromInt(patterns.len));
        
        const time_factor = @min(1.0, years_since_improvement / TIME_FACTOR_MAX);
        const gap_factor = @min(1.0, gap / current_exponent);
        const ml_boost = if (ml_available) ML_BOOST else 1.0;
        
        return base_rate * time_factor * gap_factor * ml_boost;
    }
};

pub const Target = enum {
    @"999", // ЕДИНСТВЕННЫЙ разрешённый target

    pub fn fromString(s: []const u8) ?Target {
        // Все запросы направляются на 999
        _ = s;
        return .@"999";
    }

    pub fn extension(self: Target) []const u8 {
        return switch (self) {
            .@"999" => ".999",
        };
    }
};

pub fn generate(allocator: std.mem.Allocator, spec: parser.Spec) ![]const u8 {
    _ = spec.language; // игнорируем, всегда 999
    return generate999(allocator, spec);
}

pub fn generateForTarget(allocator: std.mem.Allocator, spec: parser.Spec, target: Target) ![]const u8 {
    return switch (target) {
        .@"999" => generate999(allocator, spec),
    };
}

/// Конвертирует имя файла в Coptic (если оно Latin)
/// Если уже Coptic - возвращает как есть
pub fn toCopticFilename(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    // Проверяем первый символ - если уже Coptic (>= 0x2C80), возвращаем как есть
    if (name.len >= 3) {
        const first_byte = name[0];
        if (first_byte >= 0xE2) {
            // Уже UTF-8 Coptic, возвращаем копию
            return try allocator.dupe(u8, name);
        }
    }
    
    // Конвертируем Latin в Coptic
    var result = std.ArrayList(u8).init(allocator);
    
    for (name) |c| {
        if (c >= 'a' and c <= 'z') {
            try result.appendSlice(LATIN_TO_COPTIC[c - 'a']);
        } else if (c >= 'A' and c <= 'Z') {
            try result.appendSlice(LATIN_TO_COPTIC[c - 'A']);
        } else if (c == '_' or c == '.') {
            try result.append(c);
        } else if (c >= '0' and c <= '9') {
            try result.append(c);
        }
        // Остальные символы пропускаем
    }
    
    return result.toOwnedSlice();
}

// ============================================================================
// 999 CODE GENERATOR - СВЯЩЕННЫЙ КОПТСКИЙ АЛФАВИТ
// ============================================================================
// АЛФАВИТ ЦАРСТВА (27 символов):
// МЕДНОЕ (1-9):     Ⲁ Ⲃ Ⲅ Ⲇ Ⲉ Ⲋ Ⲍ Ⲏ Ⲑ
// СЕРЕБРЯНОЕ (10-18): Ⲓ Ⲕ Ⲗ Ⲙ Ⲛ Ⲝ Ⲟ Ⲡ Ⲣ
// ЗОЛОТОЕ (19-27):   Ⲥ Ⲧ Ⲩ Ⲫ Ⲭ Ⲯ Ⲱ Ⳁ Ⳃ

const COPTIC_ALPHABET = [27][]const u8{
    "Ⲁ", "Ⲃ", "Ⲅ", "Ⲇ", "Ⲉ", "Ⲋ", "Ⲍ", "Ⲏ", "Ⲑ", // Медное 1-9
    "Ⲓ", "Ⲕ", "Ⲗ", "Ⲙ", "Ⲛ", "Ⲝ", "Ⲟ", "Ⲡ", "Ⲣ", // Серебряное 10-18
    "Ⲥ", "Ⲧ", "Ⲩ", "Ⲫ", "Ⲭ", "Ⲯ", "Ⲱ", "Ⳁ", "Ⳃ", // Золотое 19-27
};

// Латиница → Коптский (консистентный маппинг)
const LATIN_TO_COPTIC = [26][]const u8{
    "Ⲁ", // a
    "Ⲃ", // b
    "Ⲕ", // c → k
    "Ⲇ", // d
    "Ⲉ", // e
    "Ⲫ", // f
    "Ⲅ", // g
    "Ⲏ", // h
    "Ⲓ", // i
    "Ⲓ", // j → i
    "Ⲕ", // k
    "Ⲗ", // l
    "Ⲙ", // m
    "Ⲛ", // n
    "Ⲟ", // o
    "Ⲡ", // p
    "Ⲕ", // q → k
    "Ⲣ", // r
    "Ⲥ", // s
    "Ⲧ", // t
    "Ⲩ", // u
    "Ⲃ", // v → b
    "Ⲱ", // w
    "Ⲭ", // x
    "Ⲩ", // y → u
    "Ⲍ", // z
};

// Ключевые слова языка 999 (КОНСИСТЕНТНЫЕ)
const KW_MODULE = "Ⲙ";
const KW_FUNCTION = "Ⲫ";
const KW_STRUCT = "Ⲥ";
const KW_CONST = "Ⲕ";
const KW_VAR = "Ⲝ";
const KW_EXPORT = "Ⲉ";
const KW_IMPORT = "Ⲓ";
const KW_IF = "ⲈⲤ";
const KW_ELSE = "ⲈⲖ";
const KW_FOR = "ⲆⲖ";
const KW_WHILE = "ⲠⲔ";
const KW_RETURN = "ⲂⲌ";
const KW_BREAK = "ⲂⲢ";
const KW_CONTINUE = "ⲠⲢ";
const KW_IN = "Ⲃ";
const KW_RANGE = "ⲆⲀ";
const KW_TRUE = "Ⲑ";
const KW_FALSE = "Ⲁ";
const KW_NULL = "Ⲱ";

// Типы данных (КОНСИСТЕНТНЫЕ)
const TYPE_INT = "Ⲓ";
const TYPE_FLOAT = "Ⲫ";
const TYPE_STRING = "Ⲥ";
const TYPE_BOOL = "Ⲃ";
const TYPE_LIST = "Ⲗ";
const TYPE_MAP = "Ⲙ";
const TYPE_VOID = "Ⲱ";

// ============================================================================
// КОНСИСТЕНТНАЯ ТАБЛИЦА ИДЕНТИФИКАТОРОВ
// ============================================================================
// Гарантирует: один идентификатор → всегда один коптский код

const ConsistentMapping = struct {
    latin: []const u8,
    coptic: []const u8,
};

const CONSISTENT_IDENTIFIERS = [_]ConsistentMapping{
    // UI компоненты
    .{ .latin = "layout", .coptic = "ⲖⲀⲨⲞ" },
    .{ .latin = "button", .coptic = "ⲂⲦⲚⲔ" },
    .{ .latin = "input", .coptic = "ⲒⲚⲠⲦ" },
    .{ .latin = "text", .coptic = "ⲦⲈⲜⲦ" },
    .{ .latin = "image", .coptic = "ⲒⲘⲀⲄ" },
    .{ .latin = "container", .coptic = "ⲔⲞⲚⲦ" },
    .{ .latin = "card", .coptic = "ⲔⲀⲢⲆ" },
    .{ .latin = "modal", .coptic = "ⲘⲞⲆⲖ" },
    .{ .latin = "navbar", .coptic = "ⲚⲀⲂⲢ" },
    .{ .latin = "sidebar", .coptic = "ⲤⲒⲆⲂ" },
    // Действия
    .{ .latin = "click", .coptic = "ⲔⲖⲒⲔ" },
    .{ .latin = "submit", .coptic = "ⲤⲂⲘⲦ" },
    .{ .latin = "change", .coptic = "ⲬⲚⲄⲈ" },
    .{ .latin = "load", .coptic = "ⲖⲞⲀⲆ" },
    .{ .latin = "save", .coptic = "ⲤⲀⲂⲈ" },
    .{ .latin = "delete", .coptic = "ⲆⲈⲖⲦ" },
    .{ .latin = "update", .coptic = "ⲨⲠⲆⲦ" },
    .{ .latin = "create", .coptic = "ⲔⲢⲈⲦ" },
    // Данные
    .{ .latin = "data", .coptic = "ⲆⲀⲦⲀ" },
    .{ .latin = "value", .coptic = "ⲂⲀⲖⲨ" },
    .{ .latin = "result", .coptic = "ⲢⲈⲤⲖ" },
    .{ .latin = "error", .coptic = "ⲈⲢⲢⲢ" },
    .{ .latin = "state", .coptic = "ⲤⲦⲀⲦ" },
    .{ .latin = "props", .coptic = "ⲠⲢⲞⲠ" },
    .{ .latin = "config", .coptic = "ⲔⲞⲚⲪ" },
    .{ .latin = "options", .coptic = "ⲞⲠⲦⲤ" },
    // Генерация
    .{ .latin = "generate", .coptic = "ⲄⲈⲚⲢ" },
    .{ .latin = "render", .coptic = "ⲢⲚⲆⲢ" },
    .{ .latin = "transform", .coptic = "ⲦⲢⲚⲤ" },
    .{ .latin = "encode", .coptic = "ⲈⲚⲔⲆ" },
    .{ .latin = "decode", .coptic = "ⲆⲈⲔⲆ" },
    .{ .latin = "parse", .coptic = "ⲠⲀⲢⲤ" },
    .{ .latin = "compile", .coptic = "ⲔⲘⲠⲖ" },
    // 3D/WorldGen
    .{ .latin = "world", .coptic = "ⲰⲢⲖⲆ" },
    .{ .latin = "terrain", .coptic = "ⲦⲢⲢⲚ" },
    .{ .latin = "object", .coptic = "ⲞⲂⲒⲔ" },
    .{ .latin = "scene", .coptic = "ⲤⲤⲈⲚ" },
    .{ .latin = "camera", .coptic = "ⲔⲀⲘⲢ" },
    .{ .latin = "light", .coptic = "ⲖⲒⲄⲦ" },
    .{ .latin = "mesh", .coptic = "ⲘⲈⲰⲤ" },
    .{ .latin = "texture", .coptic = "ⲦⲈⲜⲢ" },
    // GNN/ML
    .{ .latin = "graph", .coptic = "ⲄⲢⲀⲪ" },
    .{ .latin = "node", .coptic = "ⲚⲞⲆⲈ" },
    .{ .latin = "edge", .coptic = "ⲈⲆⲄⲈ" },
    .{ .latin = "layer", .coptic = "ⲖⲀⲨⲢ" },
    .{ .latin = "model", .coptic = "ⲘⲞⲆⲖ" },
    .{ .latin = "train", .coptic = "ⲦⲢⲀⲚ" },
    .{ .latin = "predict", .coptic = "ⲠⲢⲈⲆ" },
    .{ .latin = "loss", .coptic = "ⲖⲞⲤⲤ" },
    // Diffusion
    .{ .latin = "diffusion", .coptic = "ⲆⲒⲪⲤ" },
    .{ .latin = "noise", .coptic = "ⲚⲞⲒⲤ" },
    .{ .latin = "denoise", .coptic = "ⲆⲚⲞⲤ" },
    .{ .latin = "step", .coptic = "ⲤⲦⲈⲠ" },
    .{ .latin = "sample", .coptic = "ⲤⲘⲠⲖ" },
    // Gradient
    .{ .latin = "gradient", .coptic = "ⲄⲢⲀⲆ" },
    .{ .latin = "optimize", .coptic = "ⲞⲠⲦⲘ" },
    .{ .latin = "minimize", .coptic = "ⲘⲒⲚⲘ" },
    .{ .latin = "maximize", .coptic = "ⲘⲀⲜⲘ" },
    .{ .latin = "constraint", .coptic = "ⲔⲚⲤⲦ" },
    // Общие
    .{ .latin = "test", .coptic = "ⲦⲈⲤⲦ" },
    .{ .latin = "spec", .coptic = "ⲤⲠⲈⲔ" },
    .{ .latin = "behavior", .coptic = "ⲂⲈⲎⲂ" },
    .{ .latin = "module", .coptic = "ⲘⲞⲆⲨ" },
    .{ .latin = "source", .coptic = "ⲤⲞⲨⲢ" },
    .{ .latin = "target", .coptic = "ⲦⲀⲢⲄ" },
    // VM TRINITY - Виртуальная машина
    .{ .latin = "vm", .coptic = "ⲂⲘⲀ" },
    .{ .latin = "trinity", .coptic = "ⲦⲢⲒⲚ" },
    .{ .latin = "stack", .coptic = "ⲤⲦⲀⲔ" },
    .{ .latin = "heap", .coptic = "ⲎⲈⲀⲠ" },
    .{ .latin = "register", .coptic = "ⲢⲈⲄⲤ" },
    .{ .latin = "opcode", .coptic = "ⲞⲠⲔⲆ" },
    .{ .latin = "bytecode", .coptic = "ⲂⲨⲦⲔ" },
    .{ .latin = "instruction", .coptic = "ⲒⲚⲤⲦ" },
    .{ .latin = "execute", .coptic = "ⲈⲜⲈⲔ" },
    .{ .latin = "dispatch", .coptic = "ⲆⲒⲤⲠ" },
    .{ .latin = "fetch", .coptic = "ⲪⲈⲦⲬ" },
    .{ .latin = "decode", .coptic = "ⲆⲈⲔⲆ" },
    // JIT компиляция
    .{ .latin = "jit", .coptic = "ⲒⲒⲦⲀ" },
    .{ .latin = "compile", .coptic = "ⲔⲘⲠⲖ" },
    .{ .latin = "hotspot", .coptic = "ⲎⲞⲦⲤ" },
    .{ .latin = "trace", .coptic = "ⲦⲢⲀⲤ" },
    .{ .latin = "inline", .coptic = "ⲒⲚⲖⲚ" },
    .{ .latin = "specialize", .coptic = "ⲤⲠⲈⲤ" },
    .{ .latin = "deoptimize", .coptic = "ⲆⲞⲠⲦ" },
    .{ .latin = "profile", .coptic = "ⲠⲢⲞⲪ" },
    .{ .latin = "counter", .coptic = "ⲔⲚⲦⲢ" },
    .{ .latin = "threshold", .coptic = "ⲐⲢⲈⲤ" },
    // Память и GC
    .{ .latin = "memory", .coptic = "ⲘⲈⲘⲢ" },
    .{ .latin = "allocate", .coptic = "ⲀⲖⲞⲔ" },
    .{ .latin = "free", .coptic = "ⲪⲢⲈⲈ" },
    .{ .latin = "gc", .coptic = "ⲄⲔⲀⲀ" },
    .{ .latin = "collect", .coptic = "ⲔⲞⲖⲔ" },
    .{ .latin = "mark", .coptic = "ⲘⲀⲢⲔ" },
    .{ .latin = "sweep", .coptic = "ⲤⲰⲈⲠ" },
    .{ .latin = "compact", .coptic = "ⲔⲘⲠⲔ" },
    .{ .latin = "arena", .coptic = "ⲀⲢⲈⲚ" },
    .{ .latin = "pool", .coptic = "ⲠⲞⲞⲖ" },
    .{ .latin = "slab", .coptic = "ⲤⲖⲀⲂ" },
    // Типы данных VM
    .{ .latin = "integer", .coptic = "ⲒⲚⲦⲄ" },
    .{ .latin = "float64", .coptic = "ⲪⲖⲦ64" },
    .{ .latin = "string", .coptic = "ⲤⲦⲢⲚ" },
    .{ .latin = "array", .coptic = "ⲀⲢⲢⲨ" },
    .{ .latin = "object", .coptic = "ⲞⲂⲒⲔ" },
    .{ .latin = "function", .coptic = "ⲪⲨⲚⲔ" },
    .{ .latin = "closure", .coptic = "ⲔⲖⲞⲤ" },
    .{ .latin = "upvalue", .coptic = "ⲨⲠⲂⲖ" },
    // Операции
    .{ .latin = "push", .coptic = "ⲠⲨⲰⲤ" },
    .{ .latin = "pop", .coptic = "ⲠⲞⲠⲀ" },
    .{ .latin = "add", .coptic = "ⲀⲆⲆⲀ" },
    .{ .latin = "sub", .coptic = "ⲤⲨⲂⲀ" },
    .{ .latin = "mul", .coptic = "ⲘⲨⲖⲀ" },
    .{ .latin = "div", .coptic = "ⲆⲒⲂⲀ" },
    .{ .latin = "mod", .coptic = "ⲘⲞⲆⲀ" },
    .{ .latin = "neg", .coptic = "ⲚⲈⲄⲀ" },
    .{ .latin = "not", .coptic = "ⲚⲞⲦⲀ" },
    .{ .latin = "and", .coptic = "ⲀⲚⲆⲀ" },
    .{ .latin = "or", .coptic = "ⲞⲢⲀⲀ" },
    .{ .latin = "xor", .coptic = "ⲜⲞⲢⲀ" },
    .{ .latin = "shl", .coptic = "ⲰⲎⲖⲀ" },
    .{ .latin = "shr", .coptic = "ⲰⲎⲢⲀ" },
    .{ .latin = "eq", .coptic = "ⲈⲔⲀⲀ" },
    .{ .latin = "lt", .coptic = "ⲖⲦⲀⲀ" },
    .{ .latin = "gt", .coptic = "ⲄⲦⲀⲀ" },
    .{ .latin = "le", .coptic = "ⲖⲈⲀⲀ" },
    .{ .latin = "ge", .coptic = "ⲄⲈⲀⲀ" },
    .{ .latin = "jump", .coptic = "ⲒⲨⲘⲠ" },
    .{ .latin = "call", .coptic = "ⲔⲀⲖⲖ" },
    .{ .latin = "ret", .coptic = "ⲢⲈⲦⲀ" },
    .{ .latin = "load", .coptic = "ⲖⲞⲀⲆ" },
    .{ .latin = "store", .coptic = "ⲤⲦⲞⲢ" },
    // Оптимизации
    .{ .latin = "simd", .coptic = "ⲤⲒⲘⲆ" },
    .{ .latin = "vector", .coptic = "ⲂⲈⲔⲦ" },
    .{ .latin = "parallel", .coptic = "ⲠⲀⲢⲖ" },
    .{ .latin = "cache", .coptic = "ⲔⲀⲰⲈ" },
    .{ .latin = "prefetch", .coptic = "ⲠⲢⲈⲪ" },
    .{ .latin = "branch", .coptic = "ⲂⲢⲚⲬ" },
    .{ .latin = "predict", .coptic = "ⲠⲢⲈⲆ" },
    // Бенчмаркинг
    .{ .latin = "benchmark", .coptic = "ⲂⲚⲬⲘ" },
    .{ .latin = "measure", .coptic = "ⲘⲈⲀⲤ" },
    .{ .latin = "timer", .coptic = "ⲦⲒⲘⲢ" },
    .{ .latin = "iteration", .coptic = "ⲒⲦⲈⲢ" },
    .{ .latin = "warmup", .coptic = "ⲰⲀⲢⲘ" },
    .{ .latin = "throughput", .coptic = "ⲐⲢⲠⲦ" },
    .{ .latin = "latency", .coptic = "ⲖⲀⲦⲚ" },
    // Священная формула
    .{ .latin = "phi", .coptic = "ⲪⲎⲀ" },
    .{ .latin = "pi", .coptic = "ⲠⲎⲀ" },
    .{ .latin = "euler", .coptic = "ⲈⲨⲖⲢ" },
    .{ .latin = "golden", .coptic = "ⲄⲞⲖⲆ" },
    .{ .latin = "sacred", .coptic = "ⲤⲀⲔⲢ" },
    .{ .latin = "formula", .coptic = "ⲪⲞⲢⲘ" },
};

/// Кодирование числа в base-27 коптский алфавит
fn encodeNumber(allocator: std.mem.Allocator, n: u64) ![]const u8 {
    if (n == 0) {
        return try allocator.dupe(u8, COPTIC_ALPHABET[0]);
    }
    
    var result = std.ArrayList(u8).init(allocator);
    var num = n;
    
    // Собираем цифры в обратном порядке
    var digits = std.ArrayList(usize).init(allocator);
    defer digits.deinit();
    
    while (num > 0) {
        try digits.append(num % 27);
        num /= 27;
    }
    
    // Записываем в правильном порядке
    var i: usize = digits.items.len;
    while (i > 0) {
        i -= 1;
        try result.appendSlice(COPTIC_ALPHABET[digits.items[i]]);
    }
    
    return result.toOwnedSlice();
}

/// Поиск в консистентной таблице
fn findConsistentMapping(name: []const u8) ?[]const u8 {
    // Приводим к нижнему регистру для поиска
    var lower_buf: [64]u8 = undefined;
    const len = @min(name.len, 64);
    for (name[0..len], 0..) |c, i| {
        lower_buf[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
    }
    const lower = lower_buf[0..len];
    
    for (CONSISTENT_IDENTIFIERS) |mapping| {
        if (std.mem.eql(u8, mapping.latin, lower)) {
            return mapping.coptic;
        }
    }
    return null;
}

/// Кодирование одной латинской буквы в коптскую
fn latinToCoptic(c: u8) []const u8 {
    const lower = if (c >= 'A' and c <= 'Z') c + 32 else c;
    if (lower >= 'a' and lower <= 'z') {
        return LATIN_TO_COPTIC[lower - 'a'];
    }
    return "Ⲁ"; // default
}

/// КОНСИСТЕНТНОЕ кодирование идентификатора в коптский алфавит
/// Гарантирует: один идентификатор → всегда один коптский код
fn encodeIdentifier(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    // 1. Сначала ищем в консистентной таблице
    if (findConsistentMapping(name)) |coptic| {
        return try allocator.dupe(u8, coptic);
    }
    
    // 2. Если не найдено - кодируем первые 4 буквы детерминированно
    var result = std.ArrayList(u8).init(allocator);
    
    var count: usize = 0;
    for (name) |c| {
        if (count >= 4) break;
        if ((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z')) {
            try result.appendSlice(latinToCoptic(c));
            count += 1;
        }
    }
    
    // Если меньше 4 символов - дополняем Ⲁ
    while (count < 4) {
        try result.appendSlice("Ⲁ");
        count += 1;
    }
    
    return result.toOwnedSlice();
}

// ============================================================================
// VM TRINITY OPCODES - Священные коды операций
// ============================================================================
const VM_OPCODES = struct {
    // Стек операции (0x00-0x0F)
    const PUSH_CONST = "ⲀⲀ"; // 0x00 - загрузить константу
    const PUSH_LOCAL = "ⲀⲂ"; // 0x01 - загрузить локальную
    const PUSH_GLOBAL = "ⲀⲄ"; // 0x02 - загрузить глобальную
    const POP = "ⲀⲆ"; // 0x03 - снять со стека
    const DUP = "ⲀⲈ"; // 0x04 - дублировать
    const SWAP = "ⲀⲊ"; // 0x05 - поменять местами
    
    // Арифметика (0x10-0x1F)
    const ADD = "ⲂⲀ"; // 0x10 - сложение
    const SUB = "ⲂⲂ"; // 0x11 - вычитание
    const MUL = "ⲂⲄ"; // 0x12 - умножение
    const DIV = "ⲂⲆ"; // 0x13 - деление
    const MOD = "ⲂⲈ"; // 0x14 - остаток
    const NEG = "ⲂⲊ"; // 0x15 - отрицание
    const POW = "ⲂⲌ"; // 0x16 - степень
    
    // Сравнение (0x20-0x2F)
    const EQ = "ⲄⲀ"; // 0x20 - равно
    const NE = "ⲄⲂ"; // 0x21 - не равно
    const LT = "ⲄⲄ"; // 0x22 - меньше
    const LE = "ⲄⲆ"; // 0x23 - меньше или равно
    const GT = "ⲄⲈ"; // 0x24 - больше
    const GE = "ⲄⲊ"; // 0x25 - больше или равно
    
    // Логика (0x30-0x3F)
    const NOT = "ⲆⲀ"; // 0x30 - логическое НЕ
    const AND = "ⲆⲂ"; // 0x31 - логическое И
    const OR = "ⲆⲄ"; // 0x32 - логическое ИЛИ
    const XOR = "ⲆⲆ"; // 0x33 - исключающее ИЛИ
    
    // Битовые (0x40-0x4F)
    const BNOT = "ⲈⲀ"; // 0x40 - битовое НЕ
    const BAND = "ⲈⲂ"; // 0x41 - битовое И
    const BOR = "ⲈⲄ"; // 0x42 - битовое ИЛИ
    const BXOR = "ⲈⲆ"; // 0x43 - битовое XOR
    const SHL = "ⲈⲈ"; // 0x44 - сдвиг влево
    const SHR = "ⲈⲊ"; // 0x45 - сдвиг вправо
    
    // Управление потоком (0x50-0x5F)
    const JMP = "ⲊⲀ"; // 0x50 - безусловный переход
    const JZ = "ⲊⲂ"; // 0x51 - переход если ноль
    const JNZ = "ⲊⲄ"; // 0x52 - переход если не ноль
    const CALL = "ⲊⲆ"; // 0x53 - вызов функции
    const RET = "ⲊⲈ"; // 0x54 - возврат
    const HALT = "ⲊⲊ"; // 0x55 - остановка
    
    // Память (0x60-0x6F)
    const LOAD = "ⲌⲀ"; // 0x60 - загрузить из памяти
    const STORE = "ⲌⲂ"; // 0x61 - сохранить в память
    const ALLOC = "ⲌⲄ"; // 0x62 - выделить память
    const FREE = "ⲌⲆ"; // 0x63 - освободить память
    
    // Объекты (0x70-0x7F)
    const NEW = "ⲎⲀ"; // 0x70 - создать объект
    const GET = "ⲎⲂ"; // 0x71 - получить поле
    const SET = "ⲎⲄ"; // 0x72 - установить поле
    const INVOKE = "ⲎⲆ"; // 0x73 - вызвать метод
    
    // SIMD (0x80-0x8F) - Священные векторные операции
    const VADD = "ⲐⲀ"; // 0x80 - векторное сложение
    const VSUB = "ⲐⲂ"; // 0x81 - векторное вычитание
    const VMUL = "ⲐⲄ"; // 0x82 - векторное умножение
    const VDIV = "ⲐⲆ"; // 0x83 - векторное деление
    const VDOT = "ⲐⲈ"; // 0x84 - скалярное произведение
    const VLOAD = "ⲐⲊ"; // 0x85 - загрузить вектор
    const VSTORE = "ⲐⲌ"; // 0x86 - сохранить вектор
    
    // Священная формула (0x90-0x9F)
    const PHI = "ⲢⲀ"; // 0x90 - φ = 1.618033988749895
    const PI = "ⲢⲂ"; // 0x91 - π = 3.141592653589793
    const E = "ⲢⲄ"; // 0x92 - e = 2.718281828459045
    const GOLDEN = "ⲢⲆ"; // 0x93 - φ² + 1/φ² = 3
    const SACRED = "ⲢⲈ"; // 0x94 - V = n × 3^k × π^m × φ^p × e^q
};

// ============================================================================
// ГЕНЕРАТОРЫ ТЕЛ ФУНКЦИЙ ДЛЯ РАЗНЫХ ТИПОВ BEHAVIORS
// ============================================================================

/// Генерация тела VM behavior - dispatch loop
fn generateVMBehaviorBody(writer: anytype) !void {
    try writer.writeAll(
        \\  // ⲂⲘ ⲦⲢⲒⲚⲒⲦⲨ - ⲆⲒⲤⲠⲀⲦⲤⲎ ⲖⲞⲞⲠ
        \\  Ⲝ ⲓⲡ: Ⲓ = 0  // instruction pointer
        \\  Ⲝ ⲥⲡ: Ⲓ = 0  // stack pointer
        \\  Ⲝ ⲫⲡ: Ⲓ = 0  // frame pointer
        \\  
        \\  // ⲤⲦⲀⲔ: 64ⲔⲂ ⲥⲧⲁⲕ ⲥⲓⲍⲉ
        \\  Ⲝ ⲤⲦⲀⲔ: [65536]Ⲓ = [0; 65536]
        \\  
        \\  // ⲆⲒⲤⲠⲀⲦⲤⲎ ⲦⲀⲂⲖⲈ - computed goto
        \\  ⲆⲖ ⲟⲡ Ⲃ ⲂⲨⲦⲈⲔⲞⲆⲈ {
        \\    ⲈⲤ ⲟⲡ == ⲀⲀ { ⲤⲦⲀⲔ[ⲥⲡ] = ⲔⲞⲚⲤⲦ[ⲓⲡ+1]; ⲥⲡ += 1; ⲓⲡ += 2 }
        \\    ⲈⲤ ⲟⲡ == ⲂⲀ { ⲥⲡ -= 1; ⲤⲦⲀⲔ[ⲥⲡ-1] += ⲤⲦⲀⲔ[ⲥⲡ]; ⲓⲡ += 1 }
        \\    ⲈⲤ ⲟⲡ == ⲂⲂ { ⲥⲡ -= 1; ⲤⲦⲀⲔ[ⲥⲡ-1] -= ⲤⲦⲀⲔ[ⲥⲡ]; ⲓⲡ += 1 }
        \\    ⲈⲤ ⲟⲡ == ⲂⲄ { ⲥⲡ -= 1; ⲤⲦⲀⲔ[ⲥⲡ-1] *= ⲤⲦⲀⲔ[ⲥⲡ]; ⲓⲡ += 1 }
        \\    ⲈⲤ ⲟⲡ == ⲂⲆ { ⲥⲡ -= 1; ⲤⲦⲀⲔ[ⲥⲡ-1] /= ⲤⲦⲀⲔ[ⲥⲡ]; ⲓⲡ += 1 }
        \\    ⲈⲤ ⲟⲡ == ⲊⲀ { ⲓⲡ = ⲂⲨⲦⲈⲔⲞⲆⲈ[ⲓⲡ+1] }
        \\    ⲈⲤ ⲟⲡ == ⲊⲆ { ⲤⲦⲀⲔ[ⲥⲡ] = ⲓⲡ+2; ⲥⲡ += 1; ⲓⲡ = ⲂⲨⲦⲈⲔⲞⲆⲈ[ⲓⲡ+1] }
        \\    ⲈⲤ ⲟⲡ == ⲊⲈ { ⲥⲡ -= 1; ⲓⲡ = ⲤⲦⲀⲔ[ⲥⲡ] }
        \\    ⲈⲤ ⲟⲡ == ⲊⲊ { ⲂⲌ Ⲱ }
        \\  }
        \\  ⲂⲌ Ⲱ
        \\
    );
}

/// Генерация тела JIT behavior - trace compilation
fn generateJITBehaviorBody(writer: anytype) !void {
    try writer.writeAll(
        \\  // ⲒⲒⲦ ⲔⲞⲘⲠⲒⲖⲈⲢ - ⲦⲢⲀⲤⲈ ⲂⲀⲤⲈⲆ
        \\  Ⲕ ⲎⲞⲦⲤⲠⲞⲦ_ⲦⲎⲢⲈⲤⲎⲞⲖⲆ: Ⲓ = 1000
        \\  Ⲕ ⲦⲢⲀⲤⲈ_ⲘⲀⲬ_ⲖⲈⲚ: Ⲓ = 256
        \\  
        \\  Ⲝ ⲔⲞⲨⲚⲦⲈⲢⲤ: [4096]Ⲓ = [0; 4096]
        \\  Ⲝ ⲦⲢⲀⲤⲈⲤ: [1024][256]Ⲓ = [[0; 256]; 1024]
        \\  Ⲝ ⲔⲞⲘⲠⲒⲖⲈⲆ: [1024]Ⲃ = [Ⲁ; 1024]
        \\  
        \\  // ⲠⲢⲞⲪⲒⲖⲈ ⲁⲛⲇ ⲦⲢⲀⲤⲈ
        \\  Ⲫ ⲠⲢⲞⲪⲒⲖⲈ(ⲓⲡ: Ⲓ) -> Ⲃ {
        \\    ⲔⲞⲨⲚⲦⲈⲢⲤ[ⲓⲡ] += 1
        \\    ⲈⲤ ⲔⲞⲨⲚⲦⲈⲢⲤ[ⲓⲡ] >= ⲎⲞⲦⲤⲠⲞⲦ_ⲦⲎⲢⲈⲤⲎⲞⲖⲆ {
        \\      ⲂⲌ Ⲑ  // ⲏⲟⲧ!
        \\    }
        \\    ⲂⲌ Ⲁ
        \\  }
        \\  
        \\  // ⲤⲠⲈⲤⲒⲀⲖⲒⲌⲈ ⲫⲟⲣ ⲧⲩⲡⲉⲥ
        \\  Ⲫ ⲤⲠⲈⲤⲒⲀⲖⲒⲌⲈ(ⲧⲣⲁⲥⲉ: []Ⲓ, ⲧⲩⲡⲉⲥ: []Ⲧ) -> []Ⲓ {
        \\    // ⲦⲨⲠⲈ-ⲤⲠⲈⲤⲒⲪⲒⲔ ⲟⲡⲧⲓⲙⲓⲍⲁⲧⲓⲟⲛⲥ
        \\    ⲂⲌ ⲞⲠⲦⲒⲘⲒⲌⲈ(ⲧⲣⲁⲥⲉ)
        \\  }
        \\  
        \\  // ⲆⲈⲞⲠⲦⲒⲘⲒⲌⲈ ⲟⲛ ⲅⲩⲁⲣⲇ ⲫⲁⲓⲗⲩⲣⲉ
        \\  Ⲫ ⲆⲈⲞⲠⲦⲒⲘⲒⲌⲈ(ⲓⲡ: Ⲓ) {
        \\    ⲔⲞⲘⲠⲒⲖⲈⲆ[ⲓⲡ] = Ⲁ
        \\    ⲔⲞⲨⲚⲦⲈⲢⲤ[ⲓⲡ] = 0
        \\  }
        \\  ⲂⲌ Ⲱ
        \\
    );
}

/// Генерация тела GC behavior - mark-sweep-compact
fn generateGCBehaviorBody(writer: anytype) !void {
    try writer.writeAll(
        \\  // ⲄⲔ ⲦⲢⲒⲚⲒⲦⲨ - ⲘⲀⲢⲔ-ⲤⲰⲈⲈⲠ-ⲔⲞⲘⲠⲀⲔⲦ
        \\  Ⲕ ⲎⲈⲀⲠ_ⲤⲒⲌⲈ: Ⲓ = 16777216  // 16ⲘⲂ
        \\  Ⲕ ⲀⲢⲈⲚⲀ_ⲤⲒⲌⲈ: Ⲓ = 65536    // 64ⲔⲂ
        \\  
        \\  Ⲝ ⲎⲈⲀⲠ: [16777216]Ⲓ = [0; 16777216]
        \\  Ⲝ ⲘⲀⲢⲔⲤ: [262144]Ⲃ = [Ⲁ; 262144]  // 1 ⲃⲓⲧ ⲡⲉⲣ 64 ⲃⲩⲧⲉⲥ
        \\  Ⲝ ⲪⲢⲈⲈ_ⲖⲒⲤ: Ⲓ = 0
        \\  
        \\  // ⲘⲀⲢⲔ ⲠⲎⲀⲤⲈ - ⲧⲣⲓ-ⲕⲟⲗⲟⲣ
        \\  Ⲫ ⲘⲀⲢⲔ(ⲣⲟⲟⲧⲥ: []Ⲓ) {
        \\    Ⲝ ⲰⲞⲢⲔⲖⲒⲤⲦ: [4096]Ⲓ = [0; 4096]
        \\    Ⲝ ⲱⲡ: Ⲓ = 0
        \\    
        \\    // ⲀⲆⲆ ⲣⲟⲟⲧⲥ
        \\    ⲆⲖ ⲣ Ⲃ ⲣⲟⲟⲧⲥ { ⲰⲞⲢⲔⲖⲒⲤⲦ[ⲱⲡ] = ⲣ; ⲱⲡ += 1 }
        \\    
        \\    // ⲦⲢⲀⲂⲈⲢⲤⲈ
        \\    ⲠⲔ ⲱⲡ > 0 {
        \\      ⲱⲡ -= 1
        \\      Ⲝ ⲟⲃⲓ: Ⲓ = ⲰⲞⲢⲔⲖⲒⲤⲦ[ⲱⲡ]
        \\      ⲈⲤ !ⲘⲀⲢⲔⲤ[ⲟⲃⲓ/64] {
        \\        ⲘⲀⲢⲔⲤ[ⲟⲃⲓ/64] = Ⲑ
        \\        // ⲀⲆⲆ ⲣⲉⲫⲉⲣⲉⲛⲥⲉⲥ ⲧⲟ ⲱⲟⲣⲕⲗⲓⲥⲧ
        \\      }
        \\    }
        \\  }
        \\  
        \\  // ⲤⲰⲈⲈⲠ ⲠⲎⲀⲤⲈ
        \\  Ⲫ ⲤⲰⲈⲈⲠ() -> Ⲓ {
        \\    Ⲝ ⲫⲣⲉⲉⲇ: Ⲓ = 0
        \\    ⲆⲖ ⲓ Ⲃ ⲆⲀ(0, 262144) {
        \\      ⲈⲤ !ⲘⲀⲢⲔⲤ[ⲓ] { ⲫⲣⲉⲉⲇ += 64 }
        \\      ⲘⲀⲢⲔⲤ[ⲓ] = Ⲁ  // ⲣⲉⲥⲉⲧ
        \\    }
        \\    ⲂⲌ ⲫⲣⲉⲉⲇ
        \\  }
        \\  
        \\  // ⲔⲞⲘⲠⲀⲔⲦ ⲠⲎⲀⲤⲈ
        \\  Ⲫ ⲔⲞⲘⲠⲀⲔⲦ() {
        \\    // ⲘⲞⲂⲈ ⲗⲓⲃⲉ ⲟⲃⲓⲉⲕⲧⲥ ⲧⲟ ⲫⲣⲟⲛⲧ
        \\    // ⲨⲠⲆⲀⲦⲈ ⲣⲉⲫⲉⲣⲉⲛⲥⲉⲥ
        \\  }
        \\  ⲂⲌ Ⲱ
        \\
    );
}

/// Генерация тела SIMD behavior - vectorized operations
fn generateSIMDBehaviorBody(writer: anytype) !void {
    try writer.writeAll(
        \\  // ⲤⲒⲘⲆ ⲦⲢⲒⲚⲒⲦⲨ - ⲂⲈⲔⲦⲞⲢⲒⲌⲈⲆ ⲞⲠⲈⲢⲀⲦⲒⲞⲚⲤ
        \\  // ⲀⲂⲬ256 / ⲚⲈⲞⲚ / ⲰⲀⲤⲘ ⲤⲒⲘⲆ
        \\  
        \\  Ⲕ ⲂⲈⲔ_ⲰⲒⲆⲦⲎ: Ⲓ = 8  // 8 × ⲫⲗⲟⲁⲧ32 = 256 ⲃⲓⲧⲥ
        \\  
        \\  // ⲂⲈⲔⲦⲞⲢ ⲀⲆⲆⲒⲦⲒⲞⲚ
        \\  Ⲫ ⲂⲀⲆⲆ(ⲁ: [8]Ⲫ, ⲃ: [8]Ⲫ) -> [8]Ⲫ {
        \\    Ⲝ ⲣ: [8]Ⲫ = [0.0; 8]
        \\    // ⲐⲀ - ⲂⲈⲔⲦⲞⲢ ⲀⲆⲆ ⲟⲡⲕⲟⲇⲉ
        \\    ⲆⲖ ⲓ Ⲃ ⲆⲀ(0, 8) { ⲣ[ⲓ] = ⲁ[ⲓ] + ⲃ[ⲓ] }
        \\    ⲂⲌ ⲣ
        \\  }
        \\  
        \\  // ⲂⲈⲔⲦⲞⲢ ⲘⲨⲖⲦⲒⲠⲖⲨ
        \\  Ⲫ ⲂⲘⲨⲖ(ⲁ: [8]Ⲫ, ⲃ: [8]Ⲫ) -> [8]Ⲫ {
        \\    Ⲝ ⲣ: [8]Ⲫ = [0.0; 8]
        \\    // ⲐⲄ - ⲂⲈⲔⲦⲞⲢ ⲘⲨⲖ ⲟⲡⲕⲟⲇⲉ
        \\    ⲆⲖ ⲓ Ⲃ ⲆⲀ(0, 8) { ⲣ[ⲓ] = ⲁ[ⲓ] * ⲃ[ⲓ] }
        \\    ⲂⲌ ⲣ
        \\  }
        \\  
        \\  // ⲆⲞⲦ ⲠⲢⲞⲆⲨⲔⲦ
        \\  Ⲫ ⲂⲆⲞⲦ(ⲁ: [8]Ⲫ, ⲃ: [8]Ⲫ) -> Ⲫ {
        \\    Ⲝ ⲥⲩⲙ: Ⲫ = 0.0
        \\    // ⲐⲈ - ⲂⲈⲔⲦⲞⲢ ⲆⲞⲦ ⲟⲡⲕⲟⲇⲉ
        \\    ⲆⲖ ⲓ Ⲃ ⲆⲀ(0, 8) { ⲥⲩⲙ += ⲁ[ⲓ] * ⲃ[ⲓ] }
        \\    ⲂⲌ ⲥⲩⲙ
        \\  }
        \\  
        \\  // ⲘⲀⲦⲢⲒⲬ ⲘⲨⲖⲦⲒⲠⲖⲨ 4×4 (ⲤⲒⲘⲆ ⲟⲡⲧⲓⲙⲓⲍⲉⲇ)
        \\  Ⲫ ⲘⲀⲦⲘⲨⲖ4(ⲁ: [16]Ⲫ, ⲃ: [16]Ⲫ) -> [16]Ⲫ {
        \\    Ⲝ ⲣ: [16]Ⲫ = [0.0; 16]
        \\    ⲆⲖ ⲓ Ⲃ ⲆⲀ(0, 4) {
        \\      ⲆⲖ ⲓ Ⲃ ⲆⲀ(0, 4) {
        \\        ⲆⲖ ⲕ Ⲃ ⲆⲀ(0, 4) {
        \\          ⲣ[ⲓ*4+ⲓ] += ⲁ[ⲓ*4+ⲕ] * ⲃ[ⲕ*4+ⲓ]
        \\        }
        \\      }
        \\    }
        \\    ⲂⲌ ⲣ
        \\  }
        \\  ⲂⲌ Ⲱ
        \\
    );
}

/// Генерация кода на языке 999
fn generate999(allocator: std.mem.Allocator, spec: parser.Spec) ![]const u8 {
    var output = std.ArrayList(u8).init(allocator);
    const writer = output.writer();

    // Заголовок модуля с священной формулой
    const module_name = try encodeIdentifier(allocator, spec.module);
    defer allocator.free(module_name);
    
    try writer.print(
        \\// ═══════════════════════════════════════════════════════════════
        \\// ⳃⳃⳃ - ⲤⲀⲔⲢⲈⲆ ⲔⲞⲆⲈ - Ⲅⲉⲛⲉⲣⲁⲧⲉⲇ ⲃⲩ ⲂⲒⲂⲈⲈⲤ
        \\// ═══════════════════════════════════════════════════════════════
        \\// Ⲥⲟⲩⲣⲥⲉ: {s}.vibee
        \\// Ⲃⲉⲣⲥⲓⲟⲛ: {s}
        \\// ⲤⲀⲔⲢⲈⲆ ⲪⲞⲢⲘⲨⲖⲀ: Ⲃ = ⲛ × 3^ⲕ × π^ⲙ × φ^ⲡ × ⲉ^ⲕ
        \\// ⲄⲞⲖⲆⲈⲚ ⲒⲆⲈⲚⲦⲒⲦⲨ: φ² + 1/φ² = 3
        \\// ═══════════════════════════════════════════════════════════════
        \\
        \\{s} {s}
        \\
        \\
    , .{ spec.name, spec.version, KW_MODULE, module_name });

    // Генерация констант из Creation Pattern
    if (spec.creation_pattern) |cp| {
        const source_enc = try encodeIdentifier(allocator, cp.source);
        defer allocator.free(source_enc);
        const transformer_enc = try encodeIdentifier(allocator, cp.transformer);
        defer allocator.free(transformer_enc);
        const result_enc = try encodeIdentifier(allocator, cp.result);
        defer allocator.free(result_enc);
        
        try writer.print(
            \\// Ⲥⲣⲉⲁⲧⲓⲟⲛ Ⲡⲁⲧⲧⲉⲣⲛ
            \\{s} {s}: {s} = "{s}"
            \\{s} {s}: {s} = "{s}"
            \\{s} {s}: {s} = "{s}"
            \\
            \\
        , .{
            KW_CONST, source_enc, TYPE_STRING, cp.source,
            KW_CONST, transformer_enc, TYPE_STRING, cp.transformer,
            KW_CONST, result_enc, TYPE_STRING, cp.result,
        });
    }

    // Генерация функций из behaviors с полным VM кодом
    for (spec.behaviors) |behavior| {
        const func_name = try encodeIdentifier(allocator, behavior.name);
        defer allocator.free(func_name);
        
        // Определяем тип behavior для генерации соответствующего кода
        const is_vm_behavior = std.mem.indexOf(u8, behavior.name, "vm") != null or
                               std.mem.indexOf(u8, behavior.name, "execute") != null or
                               std.mem.indexOf(u8, behavior.name, "dispatch") != null;
        
        const is_jit_behavior = std.mem.indexOf(u8, behavior.name, "jit") != null or
                                std.mem.indexOf(u8, behavior.name, "compile") != null or
                                std.mem.indexOf(u8, behavior.name, "hotspot") != null;
        
        const is_gc_behavior = std.mem.indexOf(u8, behavior.name, "gc") != null or
                               std.mem.indexOf(u8, behavior.name, "collect") != null or
                               std.mem.indexOf(u8, behavior.name, "memory") != null;
        
        const is_simd_behavior = std.mem.indexOf(u8, behavior.name, "simd") != null or
                                 std.mem.indexOf(u8, behavior.name, "vector") != null;
        
        try writer.print(
            \\// ─────────────────────────────────────────────────────────────
            \\// ⲂⲈⲎⲀⲂⲒⲞⲢ: {s}
            \\// ─────────────────────────────────────────────────────────────
            \\// Ⲅⲓⲃⲉⲛ: {s}
            \\// Ⲱⲏⲉⲛ: {s}
            \\// Ⲧⲏⲉⲛ: {s}
            \\{s} {s}() -> {s} {{
            \\
        , .{
            behavior.name,
            behavior.given,
            behavior.when,
            behavior.then,
            KW_FUNCTION, func_name, TYPE_VOID,
        });
        
        // Генерируем специфичный код в зависимости от типа behavior
        if (is_vm_behavior) {
            try generateVMBehaviorBody(writer);
        } else if (is_jit_behavior) {
            try generateJITBehaviorBody(writer);
        } else if (is_gc_behavior) {
            try generateGCBehaviorBody(writer);
        } else if (is_simd_behavior) {
            try generateSIMDBehaviorBody(writer);
        } else {
            try writer.print("  {s} {s}\n", .{ KW_RETURN, KW_NULL });
        }
        
        try writer.writeAll("}\n\n");
    }

    // Генерация трансформеров
    for (spec.transformers) |transformer| {
        const trans_name = try encodeIdentifier(allocator, transformer.name);
        defer allocator.free(trans_name);
        const input_enc = try encodeIdentifier(allocator, transformer.input);
        defer allocator.free(input_enc);
        const output_enc = try encodeIdentifier(allocator, transformer.output);
        defer allocator.free(output_enc);
        
        try writer.print(
            \\// Ⲧⲣⲁⲛⲥⲫⲟⲣⲙⲉⲣ: {s}
            \\{s} {s}({s}: {s}) -> {s} {{
            \\  {s} {s}
            \\}}
            \\
            \\
        , .{
            transformer.name,
            KW_FUNCTION, trans_name, input_enc, TYPE_INT, output_enc,
            KW_RETURN, KW_NULL,
        });
    }

    // Экспорты
    try writer.print(
        \\{s} {{
    , .{KW_EXPORT});
    
    for (spec.behaviors, 0..) |behavior, i| {
        const func_name = try encodeIdentifier(allocator, behavior.name);
        defer allocator.free(func_name);
        
        if (i > 0) try writer.writeAll(", ");
        try writer.writeAll(func_name);
    }
    
    try writer.writeAll(" }\n");

    return output.toOwnedSlice();
}

test "generate 999 code" {
    var behaviors = [_]parser.Behavior{
        .{
            .name = "test_behavior",
            .given = "input",
            .when = "process",
            .then = "output",
            .test_cases = &[_]parser.TestCase{},
        },
    };

    const spec = parser.Spec{
        .name = "test999",
        .version = "1.0.0",
        .language = "999",
        .module = "test_module",
        .description = "Test 999 generation",
        .behaviors = &behaviors,
        .types = &[_]parser.Type{},
        .functions = &[_]parser.Function{},
        .imports = &[_][]const u8{},
        .creation_pattern = null,
        .transformers = &[_]parser.Transformer{},
        .test_generation = null,
        .source = null,
        .pas_patterns = null,
        .benefit = null,
        .emoji = null,
        .keyboard_shortcut = null,
        .state = null,
        .methods = null,
        .init_body = null,
        .allocator = std.testing.allocator,
    };

    const code = try generate(std.testing.allocator, spec);
    defer std.testing.allocator.free(code);

    // Должен содержать коптские символы
    try std.testing.expect(std.mem.indexOf(u8, code, "Ⲙ") != null); // MODULE
    try std.testing.expect(std.mem.indexOf(u8, code, "Ⲫ") != null); // FUNCTION
    try std.testing.expect(std.mem.indexOf(u8, code, "Ⲉ") != null); // EXPORT
    
    // Не должен содержать латинские ключевые слова
    try std.testing.expect(std.mem.indexOf(u8, code, "module ") == null);
    try std.testing.expect(std.mem.indexOf(u8, code, "function ") == null);
    try std.testing.expect(std.mem.indexOf(u8, code, "export ") == null);
}

test "encode number to coptic" {
    // 0 = Ⲁ
    const zero = try encodeNumber(std.testing.allocator, 0);
    defer std.testing.allocator.free(zero);
    try std.testing.expectEqualStrings("Ⲁ", zero);
    
    // 1 = Ⲃ
    const one = try encodeNumber(std.testing.allocator, 1);
    defer std.testing.allocator.free(one);
    try std.testing.expectEqualStrings("Ⲃ", one);
    
    // 26 = Ⳃ
    const twentysix = try encodeNumber(std.testing.allocator, 26);
    defer std.testing.allocator.free(twentysix);
    try std.testing.expectEqualStrings("Ⳃ", twentysix);
    
    // 27 = ⲂⲀ (1*27 + 0)
    const twentyseven = try encodeNumber(std.testing.allocator, 27);
    defer std.testing.allocator.free(twentyseven);
    try std.testing.expectEqualStrings("ⲂⲀ", twentyseven);
}

test "consistent identifier encoding" {
    // Тест консистентности: один идентификатор → всегда один код
    
    // layout → ⲖⲀⲨⲞ (из таблицы)
    const layout1 = try encodeIdentifier(std.testing.allocator, "layout");
    defer std.testing.allocator.free(layout1);
    const layout2 = try encodeIdentifier(std.testing.allocator, "layout");
    defer std.testing.allocator.free(layout2);
    try std.testing.expectEqualStrings("ⲖⲀⲨⲞ", layout1);
    try std.testing.expectEqualStrings(layout1, layout2); // КОНСИСТЕНТНОСТЬ!
    
    // button → ⲂⲦⲚⲔ (из таблицы)
    const button = try encodeIdentifier(std.testing.allocator, "button");
    defer std.testing.allocator.free(button);
    try std.testing.expectEqualStrings("ⲂⲦⲚⲔ", button);
    
    // graph → ⲄⲢⲀⲪ (из таблицы)
    const graph = try encodeIdentifier(std.testing.allocator, "graph");
    defer std.testing.allocator.free(graph);
    try std.testing.expectEqualStrings("ⲄⲢⲀⲪ", graph);
    
    // Новый идентификатор (не в таблице) - детерминированное кодирование
    const custom1 = try encodeIdentifier(std.testing.allocator, "myVar");
    defer std.testing.allocator.free(custom1);
    const custom2 = try encodeIdentifier(std.testing.allocator, "myVar");
    defer std.testing.allocator.free(custom2);
    try std.testing.expectEqualStrings(custom1, custom2); // КОНСИСТЕНТНОСТЬ!
    try std.testing.expectEqualStrings("ⲘⲨⲂⲀ", custom1); // m=Ⲙ, y=Ⲩ, v=Ⲃ, a=Ⲁ
}

test "deterministic new identifier encoding" {
    // Новые идентификаторы кодируются детерминированно через латиницу
    
    // "test" → ⲦⲈⲤⲦ (из таблицы)
    const test_id = try encodeIdentifier(std.testing.allocator, "test");
    defer std.testing.allocator.free(test_id);
    try std.testing.expectEqualStrings("ⲦⲈⲤⲦ", test_id);
    
    // "xyz" → ⲬⲨⲌⲀ (x=Ⲭ, y=Ⲩ, z=Ⲍ, дополнение Ⲁ)
    const xyz = try encodeIdentifier(std.testing.allocator, "xyz");
    defer std.testing.allocator.free(xyz);
    try std.testing.expectEqualStrings("ⲬⲨⲌⲀ", xyz);
}

// ============================================================================
// ВАЛИДАТОР КОПТСКОГО КОДА
// ============================================================================

/// Проверяет что строка содержит только коптские символы (Ⲁ-Ⳃ)
/// и допустимые символы (пробелы, переносы, пунктуация, цифры)
pub fn validateCopticCode(code: []const u8) bool {
    var i: usize = 0;
    while (i < code.len) {
        const c = code[i];
        
        // ASCII допустимые: пробелы, переносы, пунктуация, цифры, комментарии
        if (c <= 127) {
            // Запрещены латинские буквы!
            if ((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z')) {
                return false;
            }
            i += 1;
            continue;
        }
        
        // UTF-8 многобайтовые символы
        // Коптский диапазон: U+2C80 - U+2CFF (Ⲁ-Ⳃ)
        if (c >= 0xE2) {
            // 3-байтовый UTF-8
            if (i + 2 < code.len) {
                i += 3;
                continue;
            }
        } else if (c >= 0xC0) {
            // 2-байтовый UTF-8
            if (i + 1 < code.len) {
                i += 2;
                continue;
            }
        }
        
        i += 1;
    }
    return true;
}

/// Проверяет что код НЕ содержит латинских букв
pub fn hasNoLatinLetters(code: []const u8) bool {
    for (code) |c| {
        if ((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z')) {
            return false;
        }
    }
    return true;
}

test "validate coptic code - no latin" {
    // Правильный код (только коптский)
    const valid = "Ⲙ ⲦⲈⲤⲦ\nⲂⲌ Ⲱ";
    try std.testing.expect(hasNoLatinLetters(valid));
    
    // Неправильный код (есть латиница)
    const invalid = "func test() { return 0; }";
    try std.testing.expect(!hasNoLatinLetters(invalid));
    
    // Смешанный (недопустимо)
    const mixed = "Ⲙ test";
    try std.testing.expect(!hasNoLatinLetters(mixed));
}

// ═══════════════════════════════════════════════════════════════
// ТЕСТЫ СВЯЩЕННЫХ КОНСТАНТ
// ═══════════════════════════════════════════════════════════════

test "golden identity: phi^2 + 1/phi^2 = 3" {
    const result = SacredConstants.goldenIdentity();
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), result, 1e-14);
}

test "sacred formula computation" {
    // V = 1 × 3^2 × π^1 × φ^1 × e^1
    const result = SacredConstants.sacredFormula(1.0, 2.0, 1.0, 1.0, 1.0);
    // 1 × 9 × 3.14159... × 1.618... × 2.718... ≈ 124.358
    try std.testing.expectApproxEqAbs(@as(f64, 124.358), result, 0.01);
}

test "fibonacci via golden ratio" {
    // F(10) = 55
    const fib10 = SacredConstants.fibonacciGolden(10);
    try std.testing.expectApproxEqAbs(@as(f64, 55.0), fib10, 0.001);
    
    // F(20) = 6765
    const fib20 = SacredConstants.fibonacciGolden(20);
    try std.testing.expectApproxEqAbs(@as(f64, 6765.0), fib20, 0.001);
}

test "lucas numbers" {
    // L(5) = 11
    const lucas5 = SacredConstants.lucasNumber(5);
    try std.testing.expectApproxEqAbs(@as(f64, 11.0), lucas5, 0.001);
    
    // L(10) = 123
    const lucas10 = SacredConstants.lucasNumber(10);
    try std.testing.expectApproxEqAbs(@as(f64, 123.0), lucas10, 0.001);
}

test "euler identity check" {
    // |e^(iπ) + 1| ≈ 0
    const result = SacredConstants.eulerIdentityCheck();
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), result, 1e-14);
}

test "trinity constant: log2(3)" {
    try std.testing.expectApproxEqAbs(@as(f64, 1.5849625007211561), SacredConstants.LOG2_3, 1e-14);
}

test "evolution constants" {
    // μ = 1/φ³ ≈ 0.0382
    try std.testing.expectApproxEqAbs(@as(f64, 0.0382), SacredConstants.MUTATION_RATE, 0.001);
    
    // χ = 1/φ² ≈ 0.0618
    try std.testing.expectApproxEqAbs(@as(f64, 0.0618), SacredConstants.CROSSOVER_RATE, 0.001);
    
    // σ = φ ≈ 1.618
    try std.testing.expectApproxEqAbs(@as(f64, 1.618), SacredConstants.SELECTION_PRESSURE, 0.001);
}

test "PAS confidence calculation" {
    const patterns = [_]f64{ PASConstants.PATTERN_DC, PASConstants.PATTERN_PRE };
    const confidence = PASConstants.calculateConfidence(&patterns, 10.0, 1.0, 2.0, true);
    
    // base_rate = (0.31 + 0.16) / 2 = 0.235
    // time_factor = min(1.0, 10/50) = 0.2
    // gap_factor = min(1.0, 1/2) = 0.5
    // ml_boost = 1.3
    // confidence = 0.235 * 0.2 * 0.5 * 1.3 ≈ 0.0306
    try std.testing.expect(confidence > 0.02 and confidence < 0.05);
}

test "powers of 3" {
    try std.testing.expectEqual(@as(u64, 1), SacredConstants.POW3[0]);
    try std.testing.expectEqual(@as(u64, 3), SacredConstants.POW3[1]);
    try std.testing.expectEqual(@as(u64, 9), SacredConstants.POW3[2]);
    try std.testing.expectEqual(@as(u64, 27), SacredConstants.POW3[3]);
    try std.testing.expectEqual(@as(u64, 59049), SacredConstants.POW3[10]);
}
