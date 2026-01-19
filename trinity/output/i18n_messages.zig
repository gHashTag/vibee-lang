// ═══════════════════════════════════════════════════════════════════════════════
// I18N MESSAGES - Internationalization for VIBEE
// ═══════════════════════════════════════════════════════════════════════════════
// PAS: PRE + HSH | φ² + 1/φ² = 3
// Languages: EN, RU, ZH, JA, ES, DE, FR, KO, PT, IT
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const mem = std.mem;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const PHOENIX: u32 = 999;

// ═══════════════════════════════════════════════════════════════════════════════
// LOCALE
// ═══════════════════════════════════════════════════════════════════════════════

pub const Locale = enum {
    en, // English
    ru, // Russian
    zh, // Chinese
    ja, // Japanese
    es, // Spanish
    de, // German
    fr, // French
    ko, // Korean
    pt, // Portuguese
    it, // Italian

    pub fn code(self: Locale) []const u8 {
        return switch (self) {
            .en => "en",
            .ru => "ru",
            .zh => "zh",
            .ja => "ja",
            .es => "es",
            .de => "de",
            .fr => "fr",
            .ko => "ko",
            .pt => "pt",
            .it => "it",
        };
    }

    pub fn name(self: Locale) []const u8 {
        return switch (self) {
            .en => "English",
            .ru => "Русский",
            .zh => "中文",
            .ja => "日本語",
            .es => "Español",
            .de => "Deutsch",
            .fr => "Français",
            .ko => "한국어",
            .pt => "Português",
            .it => "Italiano",
        };
    }

    pub fn fromCode(code_str: []const u8) ?Locale {
        if (mem.eql(u8, code_str, "en")) return .en;
        if (mem.eql(u8, code_str, "ru")) return .ru;
        if (mem.eql(u8, code_str, "zh")) return .zh;
        if (mem.eql(u8, code_str, "ja")) return .ja;
        if (mem.eql(u8, code_str, "es")) return .es;
        if (mem.eql(u8, code_str, "de")) return .de;
        if (mem.eql(u8, code_str, "fr")) return .fr;
        if (mem.eql(u8, code_str, "ko")) return .ko;
        if (mem.eql(u8, code_str, "pt")) return .pt;
        if (mem.eql(u8, code_str, "it")) return .it;
        return null;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MESSAGE KEYS
// ═══════════════════════════════════════════════════════════════════════════════

pub const MessageKey = enum {
    welcome,
    help,
    error_generic,
    success,
    goodbye,
    agent_ready,
    no_api_key,
    file_created,
    tests_passed,
    sacred_formula,
    golden_identity,
};

// ═══════════════════════════════════════════════════════════════════════════════
// MESSAGES DATABASE
// ═══════════════════════════════════════════════════════════════════════════════

pub const Messages = struct {
    pub fn get(key: MessageKey, locale: Locale) []const u8 {
        return switch (key) {
            .welcome => switch (locale) {
                .en => "Welcome to VIBEE Agent",
                .ru => "Добро пожаловать в VIBEE Agent",
                .zh => "欢迎使用 VIBEE Agent",
                .ja => "VIBEE Agentへようこそ",
                .es => "Bienvenido a VIBEE Agent",
                .de => "Willkommen bei VIBEE Agent",
                .fr => "Bienvenue dans VIBEE Agent",
                .ko => "VIBEE Agent에 오신 것을 환영합니다",
                .pt => "Bem-vindo ao VIBEE Agent",
                .it => "Benvenuto in VIBEE Agent",
            },
            .help => switch (locale) {
                .en => "Type /help for commands",
                .ru => "Введите /help для списка команд",
                .zh => "输入 /help 查看命令",
                .ja => "/help でコマンド一覧",
                .es => "Escribe /help para comandos",
                .de => "Gib /help für Befehle ein",
                .fr => "Tapez /help pour les commandes",
                .ko => "/help를 입력하여 명령어 확인",
                .pt => "Digite /help para comandos",
                .it => "Digita /help per i comandi",
            },
            .error_generic => switch (locale) {
                .en => "An error occurred",
                .ru => "Произошла ошибка",
                .zh => "发生错误",
                .ja => "エラーが発生しました",
                .es => "Ocurrió un error",
                .de => "Ein Fehler ist aufgetreten",
                .fr => "Une erreur s'est produite",
                .ko => "오류가 발생했습니다",
                .pt => "Ocorreu um erro",
                .it => "Si è verificato un errore",
            },
            .success => switch (locale) {
                .en => "Success!",
                .ru => "Успешно!",
                .zh => "成功！",
                .ja => "成功！",
                .es => "¡Éxito!",
                .de => "Erfolg!",
                .fr => "Succès !",
                .ko => "성공!",
                .pt => "Sucesso!",
                .it => "Successo!",
            },
            .goodbye => switch (locale) {
                .en => "Goodbye! φ² + 1/φ² = 3",
                .ru => "До свидания! φ² + 1/φ² = 3",
                .zh => "再见！φ² + 1/φ² = 3",
                .ja => "さようなら！φ² + 1/φ² = 3",
                .es => "¡Adiós! φ² + 1/φ² = 3",
                .de => "Auf Wiedersehen! φ² + 1/φ² = 3",
                .fr => "Au revoir ! φ² + 1/φ² = 3",
                .ko => "안녕히 가세요! φ² + 1/φ² = 3",
                .pt => "Adeus! φ² + 1/φ² = 3",
                .it => "Arrivederci! φ² + 1/φ² = 3",
            },
            .agent_ready => switch (locale) {
                .en => "Agent ready",
                .ru => "Агент готов",
                .zh => "代理已就绪",
                .ja => "エージェント準備完了",
                .es => "Agente listo",
                .de => "Agent bereit",
                .fr => "Agent prêt",
                .ko => "에이전트 준비 완료",
                .pt => "Agente pronto",
                .it => "Agente pronto",
            },
            .no_api_key => switch (locale) {
                .en => "No API key configured",
                .ru => "API ключ не настроен",
                .zh => "未配置 API 密钥",
                .ja => "APIキーが設定されていません",
                .es => "Clave API no configurada",
                .de => "Kein API-Schlüssel konfiguriert",
                .fr => "Clé API non configurée",
                .ko => "API 키가 구성되지 않음",
                .pt => "Chave API não configurada",
                .it => "Chiave API non configurata",
            },
            .file_created => switch (locale) {
                .en => "File created",
                .ru => "Файл создан",
                .zh => "文件已创建",
                .ja => "ファイルが作成されました",
                .es => "Archivo creado",
                .de => "Datei erstellt",
                .fr => "Fichier créé",
                .ko => "파일 생성됨",
                .pt => "Arquivo criado",
                .it => "File creato",
            },
            .tests_passed => switch (locale) {
                .en => "All tests passed",
                .ru => "Все тесты пройдены",
                .zh => "所有测试通过",
                .ja => "全テスト合格",
                .es => "Todas las pruebas pasaron",
                .de => "Alle Tests bestanden",
                .fr => "Tous les tests réussis",
                .ko => "모든 테스트 통과",
                .pt => "Todos os testes passaram",
                .it => "Tutti i test superati",
            },
            .sacred_formula => switch (locale) {
                .en => "Sacred Formula: V = n × 3^k × π^m × φ^p × e^q",
                .ru => "Священная Формула: V = n × 3^k × π^m × φ^p × e^q",
                .zh => "神圣公式：V = n × 3^k × π^m × φ^p × e^q",
                .ja => "神聖な公式：V = n × 3^k × π^m × φ^p × e^q",
                else => "Sacred Formula: V = n × 3^k × π^m × φ^p × e^q",
            },
            .golden_identity => switch (locale) {
                .en => "Golden Identity: φ² + 1/φ² = 3",
                .ru => "Золотая Идентичность: φ² + 1/φ² = 3",
                .zh => "黄金恒等式：φ² + 1/φ² = 3",
                .ja => "黄金恒等式：φ² + 1/φ² = 3",
                else => "Golden Identity: φ² + 1/φ² = 3",
            },
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// I18N RESOLVER
// ═══════════════════════════════════════════════════════════════════════════════

pub const I18n = struct {
    locale: Locale,

    const Self = @This();

    pub fn init(locale: Locale) Self {
        return Self{ .locale = locale };
    }

    pub fn initFromEnv() Self {
        // Try to detect from LANG environment variable
        if (std.posix.getenv("LANG")) |lang| {
            if (lang.len >= 2) {
                if (Locale.fromCode(lang[0..2])) |loc| {
                    return Self{ .locale = loc };
                }
            }
        }
        return Self{ .locale = .en };
    }

    pub fn get(self: *const Self, key: MessageKey) []const u8 {
        return Messages.get(key, self.locale);
    }

    pub fn setLocale(self: *Self, locale: Locale) void {
        self.locale = locale;
    }

    pub fn getLocaleName(self: *const Self) []const u8 {
        return self.locale.name();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Locale codes" {
    try std.testing.expectEqualStrings("en", Locale.en.code());
    try std.testing.expectEqualStrings("ru", Locale.ru.code());
    try std.testing.expectEqualStrings("zh", Locale.zh.code());
    try std.testing.expectEqualStrings("ja", Locale.ja.code());
}

test "Locale names" {
    try std.testing.expectEqualStrings("English", Locale.en.name());
    try std.testing.expectEqualStrings("Русский", Locale.ru.name());
    try std.testing.expectEqualStrings("中文", Locale.zh.name());
}

test "Locale fromCode" {
    try std.testing.expectEqual(Locale.en, Locale.fromCode("en").?);
    try std.testing.expectEqual(Locale.ru, Locale.fromCode("ru").?);
    try std.testing.expect(Locale.fromCode("xx") == null);
}

test "Messages welcome" {
    try std.testing.expectEqualStrings("Welcome to VIBEE Agent", Messages.get(.welcome, .en));
    try std.testing.expectEqualStrings("Добро пожаловать в VIBEE Agent", Messages.get(.welcome, .ru));
}

test "Messages goodbye" {
    const en_msg = Messages.get(.goodbye, .en);
    try std.testing.expect(mem.indexOf(u8, en_msg, "φ²") != null);
}

test "I18n init" {
    const i18n = I18n.init(.ru);
    try std.testing.expectEqualStrings("Русский", i18n.getLocaleName());
}

test "I18n get message" {
    const i18n = I18n.init(.ja);
    const msg = i18n.get(.success);
    try std.testing.expectEqualStrings("成功！", msg);
}

test "Supported locales count" {
    // 10 locales supported
    const locales = [_]Locale{ .en, .ru, .zh, .ja, .es, .de, .fr, .ko, .pt, .it };
    try std.testing.expectEqual(@as(usize, 10), locales.len);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(TRINITY, result, 0.0001);
}
