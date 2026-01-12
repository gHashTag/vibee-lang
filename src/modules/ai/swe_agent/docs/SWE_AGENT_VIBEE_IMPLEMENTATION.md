# 🎯 VIBEE SWE Agent - Примеры реализации и синтаксис

## 🚀 НОВОЕ: Level 1 - Task Planning ЗАВЕРШЕНО! ✅

**Дата:** 4 января 2026 | **Статус:** Production Ready

Реализована первая система улучшений - **Task Planning** для умного разложения пользовательских задач на структурированные планы выполнения.

### ✨ Что добавилось:

- **task_planning.gleam** (426 строк) - модуль анализа и разложения задач
- **16 тестов** - полное покрытие всех типов задач  
- **Интеграция в agent_loop** - автоматическое планирование перед выполнением
- **6 типов задач** - Testing, Debugging, Refactoring, Implementation, Deployment, Documentation
- **Приоритеты и зависимости** - оптимальный порядок выполнения

### 📊 Результат:

```
Input: "Write unit tests for auth module"

Output:
📋 Task Plan:
🎯 Goal: Write unit tests for auth module
📊 Complexity: Complex
⏱️  Estimated time: 13s
🔄 Estimated turns: 3

Steps to complete:
🔴 [1] Analyze code structure
🔴 [2] Identify test cases (depends on: 1)
🟡 [3] Write test file (depends on: 2)
🟡 [4] Run tests (depends on: 3)
🟢 [5] Fix failing tests (depends on: 4)
🟢 [6] Check coverage (depends on: 5)
```

### 📖 Документация:

- [LEVEL_1_QUICK_SUMMARY.md](LEVEL_1_QUICK_SUMMARY.md) - быстрое резюме
- [LEVEL_1_COMPLETION.md](LEVEL_1_COMPLETION.md) - полный отчет о реализации
- [TASK_PLANNING_DEMO.md](TASK_PLANNING_DEMO.md) - примеры и демонстрация

### 🔄 Готово к Level 2:
**Tool Selection Intelligence** - умный выбор инструментов для каждой подзадачи

---

## Обзор

Этот документ содержит практические примеры того, как реализовать SWE Agent на языке VIBEE DSL с использованием новых возможностей (Фаза 1 boilerplate reduction).

---

## 📐 Структура .vibee файла

```vibee
// 1. Декларация дефолтов модуля
@module_defaults(
  log: "module_name",
  auth_required: true,
  error_handler: "default"
)

// 2. Импорты типов (если нужны)
USE types::{Task, CodeFile, TestSuite}

// 3. Определение типов (если не импортированы)
TYPE TaskStatus = PENDING | RUNNING | SUCCESS | FAILED | CANCELLED

// 4. Определение TOOL'ов
TOOL some_tool
  @spec: str -> str
  description: "Описание инструмента"
  
  input:
    param1: str! @body "Обязательный параметр"
    param2: int? @query = 10 "Опциональный параметр"
  
  output:
    result: str @text

// 5. Определение SCENE'ов
SCENE my_scene
  @spec: str -> bool
  description: "Описание сцены"
  
  STEP step1
    TOOL call some_tool
      ...

// 6. HTTP Endpoints (используя @auth вместо явной session_id)
POST /api/v1/endpoint "Описание"
  @auth                              // Вместо session_id: str! @session
  param1: str! @body
  param2: str? @body = "default"
```

---

## 1️⃣ Task Parser - Примеры

### 1.1 Базовый парсер задач

**Файл**: `src/vibee/dsl/agent/task_parser.vibee`

```vibee
@module_defaults(
  log: "task_parser",
  auth_required: false,
  error_handler: "default"
)

// ============================================================
// ТИПЫ
// ============================================================

TYPE Task {
  id: str
  title: str
  description: str
  priority: Priority
  complexity: Complexity
  estimated_hours: int
  dependencies: List(str)
  acceptance_criteria: List(str)
  affected_files: List(str)
  tags: List(str)
}

TYPE Priority = HIGH | MEDIUM | LOW

TYPE Complexity = SIMPLE | MODERATE | COMPLEX

TYPE TaskDecomposition {
  main_task: Task
  subtasks: List(Task)
  dependencies: List(Dependency)
}

TYPE Dependency {
  from_task_id: str
  to_task_id: str
  dependency_type: str  // BLOCKS, DEPENDS_ON, RELATED_TO
}

// ============================================================
// TOOL: Парсинг описания задачи
// ============================================================

TOOL parse_task_description
  @spec: str -> Task
  description: "Парсит текстовое описание в структурированный Task"
  
  input:
    description: str!  @body "Текстовое описание задачи"
    language: str? @body = "en" "Язык описания (en, ru)"
  
  output:
    task: Task @json

  // Имплементация (в реальном коде будет обработка через LLM)
  @implementation
    """
    1. Отправить описание в LLM с промптом
    2. Распарсить JSON ответ в Task
    3. Валидировать обязательные поля
    4. Возвернуть результат
    """

// ============================================================
// TOOL: Разбиение задачи на подзадачи
// ============================================================

TOOL decompose_task
  @spec: Task -> TaskDecomposition
  description: "Разбивает комплексную задачу на подзадачи"
  
  input:
    task: Task! @body
    max_depth: int? @query = 3 "Максимальная глубина разбиения"
    language: str? @body = "en"
  
  output:
    decomposition: TaskDecomposition @json
  
  @spec "Decomposition valid":
    input.task != null ->
    output.decomposition.subtasks.count >= 1 ->
    output.decomposition.subtasks.all(fn(s) { s.complexity != COMPLEX })

// ============================================================
// TOOL: Анализ приоритета и оценка сложности
// ============================================================

TOOL analyze_task_complexity
  @spec: Task -> ComplexityAnalysis
  description: "Анализирует сложность и приоритет задачи"
  
  input:
    task: Task! @body
  
  output:
    analysis: ComplexityAnalysis @json {
      estimated_hours: int
      required_skills: List(str)
      risk_level: str      // LOW, MEDIUM, HIGH
      dependencies_count: int
      affected_files_count: int
    }

// ============================================================
// TOOL: Определение порядка выполнения
// ============================================================

TOOL resolve_task_order
  @spec: List(Task) -> List(Task)
  description: "Определяет оптимальный порядок выполнения задач"
  
  input:
    tasks: List(Task)! @body "Список задач"
  
  output:
    ordered_tasks: List(Task) @json
  
  @validation
    input.tasks.count > 0 -> "Tasks list cannot be empty"
    output.ordered_tasks.count == input.tasks.count -> "All tasks must be in output"

// ============================================================
// TOOL: Генерация плана реализации (новый!)
// ============================================================

TOOL generate_implementation_plan
  @spec: Task -> ImplementationPlan
  description: "Генерирует детальный план с шагами, сроками и зависимостями"
  
  input:
    task: Task! @body
    include_milestones: bool? @body = true
  
  output:
    plan: ImplementationPlan @json {
      phases: List({
        name: str
        description: str
        duration_hours: int
        tasks: List(str)
        deliverables: List(str)
      }),
      timeline: str
      risks: List(str)
      mitigation: List(str)
    }

// ============================================================
// API ENDPOINT: Парсер задач
// ============================================================

POST /api/v1/swe/parse-task "Распарсить описание задачи"
  @spec "Task parsed": description != null -> result.id != null
  
  description: str! @body "Описание задачи"
  project_context: str? @body "Контекст проекта для улучшения парсинга"
  
  // Обработка:
  // 1. Вызвать parse_task_description
  // 2. Вызвать analyze_task_complexity
  // 3. Вернуть результат

POST /api/v1/swe/decompose-task "Разбить задачу на подзадачи"
  task: Task! @body
  
  // Вызвать decompose_task

POST /api/v1/swe/analyze-complexity "Анализ сложности и приоритета"
  task: Task! @body
  
  // Вызвать analyze_task_complexity

POST /api/v1/swe/generate-plan "Генерация плана реализации"
  task: Task! @body
  
  // Вызвать generate_implementation_plan
```

---

## 2️⃣ Code Intelligence Tools

### 2.1 Анализ и генерация кода

**Файл**: `src/vibee/dsl/agent/code_intelligence.vibee`

```vibee
@module_defaults(
  log: "code_intelligence",
  auth_required: false
)

// ============================================================
// ТИПЫ
// ============================================================

TYPE CodeFile {
  path: str
  language: str
  content: str
  imports: List(str)
  functions: List(FunctionMeta)
  types: List(TypeMeta)
  line_count: int
  cyclomatic_complexity: float
}

TYPE FunctionMeta {
  name: str
  module: str?
  params: List(Parameter)
  return_type: str
  is_public: bool
  is_recursive: bool
  cyclomatic_complexity: int
  lines: int
  has_tests: bool
}

TYPE Parameter {
  name: str
  type: str
  is_optional: bool
}

TYPE TypeMeta {
  name: str
  kind: str  // type, record, enum, interface
  fields: List({name: str, type: str})
}

// ============================================================
// TOOL: Анализ структуры файла
// ============================================================

TOOL analyze_code_structure
  @spec: str -> CodeFile
  description: "Анализирует структуру файла кода"
  
  input:
    file_path: str! @query "Путь к файлу"
  
  output:
    structure: CodeFile @json
  
  @spec "Analysis valid":
    input.file_path != null ->
    output.structure.functions.count >= 0 ->
    output.structure.line_count > 0

// ============================================================
// TOOL: Поиск функций и символов
// ============================================================

TOOL find_symbol_definition
  @spec: (str, str?) -> List(CodeFile)
  description: "Ищет определение символа в кодовой базе"
  
  input:
    symbol_name: str! @query "Имя функции, типа или переменной"
    directory: str? @query "Директория для поиска (по умолчанию текущая)"
  
  output:
    results: List(CodeFile) @json

// ============================================================
// TOOL: Поиск использования символа
// ============================================================

TOOL find_symbol_usages
  @spec: (str, str?) -> List({file: str, line: int, context: str})
  description: "Ищет все использования символа"
  
  input:
    symbol_name: str! @query
    directory: str? @query
  
  output:
    usages: List({
      file: str
      line: int
      column: int
      context: str
    }) @json

// ============================================================
// TOOL: Анализ зависимостей модулей
// ============================================================

TOOL analyze_module_dependencies
  @spec: str -> DependencyGraph
  description: "Анализирует граф зависимостей между модулями"
  
  input:
    directory: str! @query
  
  output:
    graph: DependencyGraph @json {
      modules: List(str)
      dependencies: List({from: str, to: str, type: str})
      circular_dependencies: List(List(str))
      import_count: int
    }

// ============================================================
// TOOL: Обнаружение код-смеллов
// ============================================================

TOOL detect_code_smells
  @spec: str -> List(CodeSmell)
  description: "Обнаруживает антипаттерны и код-смеллы"
  
  input:
    file_path: str! @query
  
  output:
    smells: List({
      type: str              // LONG_METHOD, DUPLICATED_CODE, etc.
      location: {line: int, column: int}
      severity: str          // LOW, MEDIUM, HIGH
      description: str
      remediation: str
    }) @json

// ============================================================
// TOOL: Генерация кода
// ============================================================

TOOL generate_code
  @spec: (str, str?) -> str
  description: "Генерирует код функции на основе описания"
  
  input:
    prompt: str! @body "Описание функции/класса"
    language: str? @body = "gleam" "Язык программирования"
    context_files: List(str)? @body "Файлы контекста"
    style_guide: str? @body "Гайдлайны стиля"
  
  output:
    code: str @text
  
  @spec "Generated code valid":
    input.prompt != null ->
    output.code != null ->
    output.code.length > 0

// ============================================================
// TOOL: Рефакторинг кода
// ============================================================

TOOL refactor_code
  @spec: (str, str) -> str
  description: "Рефакторит код используя различные техники"
  
  input:
    code: str! @body "Исходный код"
    refactoring: str! @body "Тип рефакторинга"
    target_name: str? @body "Имя для новой функции/переменной"
  
  output:
    refactored: str @text
  
  // Тип рефакторинга:
  // - extract_method: вынуть метод
  // - extract_class: вынуть класс
  // - inline_method: встроить метод
  // - rename: переименовать
  // - simplify: упростить логику
  // - remove_duplication: убрать дублирование

// ============================================================
// TOOL: Объяснение кода
// ============================================================

TOOL explain_code
  @spec: str -> str
  description: "Объясняет логику и назначение кода"
  
  input:
    code: str! @body "Код для объяснения"
    depth: str? @body = "medium" "Уровень детализации"
  
  output:
    explanation: str @text
  
  // depth: brief (1-2 предложения), medium (параграф), detailed (несколько параграфов)

// ============================================================
// TOOL: Анализ производительности кода
// ============================================================

TOOL analyze_performance
  @spec: str -> PerformanceReport
  description: "Анализирует потенциальные проблемы производительности"
  
  input:
    file_path: str! @query
  
  output:
    report: PerformanceReport @json {
      issues: List({
        location: {line: int}
        severity: str
        description: str
        impact: str         // LOW, MEDIUM, HIGH
        suggestion: str
      }),
      estimated_improvement: str
    }

// ============================================================
// API ENDPOINTS
// ============================================================

POST /api/v1/swe/analyze-file "Анализировать структуру файла"
  file_path: str! @body

GET /api/v1/swe/find-symbol/:symbol "Найти определение символа"
  symbol: str!
  directory: str? @query

GET /api/v1/swe/find-usages/:symbol "Найти использование символа"
  symbol: str!
  directory: str? @query

POST /api/v1/swe/generate-code "Генерировать код"
  prompt: str! @body
  language: str? @body = "gleam"
  context_files: List(str)? @body

POST /api/v1/swe/refactor "Рефакторить код"
  code: str! @body
  refactoring: str! @body
```

---

## 3️⃣ Quality Assurance Tools

### 3.1 Тестирование и контроль качества

**Файл**: `src/vibee/dsl/agent/quality_assurance.vibee`

```vibee
@module_defaults(
  log: "quality_assurance",
  auth_required: false
)

// ============================================================
// ТИПЫ
// ============================================================

TYPE TestSuite {
  name: str
  language: str
  total_tests: int
  passed: int
  failed: int
  skipped: int
  duration_ms: int
  coverage_percent: float
  success: bool
}

TYPE TestCase {
  name: str
  status: str      // PASS, FAIL, SKIP, ERROR
  duration_ms: int
  error: str?
  assertion: str?
}

// ============================================================
// TOOL: Запуск тестов
// ============================================================

TOOL run_tests
  @spec: str -> TestSuite
  description: "Запускает тесты для проекта"
  
  input:
    directory: str! @query "Директория с тестами"
    pattern: str? @query = "**/*_test.gleam" "Паттерн поиска тестов"
    filter: str? @query "Фильтр по названию теста"
    verbose: bool? @query = false "Подробный вывод"
  
  output:
    suite: TestSuite @json
  
  @spec "Tests valid":
    input.directory != null ->
    output.suite.total_tests >= 0 ->
    output.suite.passed + output.suite.failed + output.suite.skipped == output.suite.total_tests

// ============================================================
// TOOL: Генерация тестов
// ============================================================

TOOL generate_tests
  @spec: str -> str
  description: "Генерирует тест-кейсы для функции"
  
  input:
    code: str! @body "Исходный код функции"
    test_type: str? @body = "unit" "Тип теста: unit, integration, e2e"
    coverage_type: str? @body = "branch" "Охват: line, branch, path"
  
  output:
    test_code: str @text
  
  @spec "Generated tests valid":
    input.code != null ->
    output.test_code.contains("test_") || output.test_code.contains("pub fn") ->
    output.test_code.length > 50

// ============================================================
// TOOL: Анализ покрытия кода
// ============================================================

TOOL analyze_code_coverage
  @spec: str -> CoverageReport
  description: "Анализирует покрытие кода тестами"
  
  input:
    directory: str! @query "Директория для анализа"
    threshold: int? @query = 0 "Минимальный процент покрытия"
  
  output:
    report: CoverageReport @json {
      total_coverage: float
      file_coverage: List({
        file: str
        coverage: float
        lines_covered: int
        lines_total: int
      }),
      functions_uncovered: List(str)
      files_below_threshold: List(str)
    }

// ============================================================
// TOOL: Проверка типов
// ============================================================

TOOL check_types
  @spec: str -> TypeCheckResult
  description: "Проверяет типы в коде (gleam check)"
  
  input:
    directory: str! @query
  
  output:
    result: TypeCheckResult @json {
      success: bool
      errors: List({
        file: str
        line: int
        column: int
        message: str
        severity: str
      }),
      warnings: List({...}),
      error_count: int
    }

// ============================================================
// TOOL: Статический анализ
// ============================================================

TOOL static_analysis
  @spec: str -> List(Issue)
  description: "Запускает статический анализ кода"
  
  input:
    directory: str! @query
    rules: List(str)? @body "Какие правила применять"
  
  output:
    issues: List({
      file: str
      line: int
      column: int
      rule: str
      severity: str  // INFO, WARNING, ERROR
      message: str
      suggestion: str?
    }) @json

// ============================================================
// TOOL: Сканирование безопасности (SAST)
// ============================================================

TOOL security_scan
  @spec: str -> List(Vulnerability)
  description: "Сканирует код на уязвимости безопасности"
  
  input:
    directory: str! @query
  
  output:
    vulnerabilities: List({
      id: str
      severity: str      // CRITICAL, HIGH, MEDIUM, LOW
      type: str          // SQL_INJECTION, XSS, etc.
      file: str
      line: int
      description: str
      remediation: str
    }) @json

// ============================================================
// TOOL: Проверка лицензий зависимостей
// ============================================================

TOOL check_dependencies_licenses
  @spec: str -> DependencyReport
  description: "Проверяет лицензии всех зависимостей"
  
  input:
    directory: str! @query
  
  output:
    report: DependencyReport @json {
      total_dependencies: int
      problematic_licenses: List({
        package: str
        version: str
        license: str
        issue: str
      }),
      all_compliant: bool
    }

// ============================================================
// API ENDPOINTS
// ============================================================

POST /api/v1/swe/run-tests "Запустить тесты"
  directory: str! @body
  filter: str? @body

POST /api/v1/swe/generate-tests "Генерировать тесты"
  code: str! @body
  test_type: str? @body = "unit"

GET /api/v1/swe/coverage "Анализ покрытия"
  directory: str! @query

POST /api/v1/swe/check-types "Проверка типов"
  directory: str! @body

POST /api/v1/swe/security-scan "Сканирование безопасности"
  directory: str! @body
```

---

## 4️⃣ VCS Tools

### 4.1 Git операции

**Файл**: `src/vibee/dsl/agent/vcs_tools.vibee`

```vibee
@module_defaults(
  log: "vcs_tools",
  auth_required: true   // Требует авторизации для git операций
)

// ============================================================
// ТИПЫ
// ============================================================

TYPE GitCommit {
  hash: str
  message: str
  author: str
  timestamp: str
  files_changed: int
  insertions: int
  deletions: int
}

TYPE GitDiff {
  file: str
  status: str        // ADDED, MODIFIED, DELETED, RENAMED
  additions: int
  deletions: int
  changes_percent: float
  hunks: List({before: int, after: int})
}

TYPE PullRequest {
  id: str
  title: str
  description: str
  author: str
  branch: str
  base_branch: str
  status: str        // DRAFT, OPEN, APPROVED, MERGED, CLOSED
  created_at: str
  updated_at: str
}

// ============================================================
// TOOL: Создание ветки
// ============================================================

TOOL git_create_branch
  @spec: (str, str) -> GitCommit
  description: "Создает новую git ветку"
  
  input:
    branch_name: str! @body "Имя новой ветки"
    from_branch: str? @body = "main" "Ветка-источник"
  
  output:
    head_commit: GitCommit @json

// ============================================================
// TOOL: Коммит изменений
// ============================================================

TOOL git_commit
  @spec: (str, List(str)?) -> GitCommit
  description: "Коммитит изменения"
  
  input:
    message: str! @body "Сообщение коммита"
    files: List(str)? @body "Файлы (все если не указано)"
  
  output:
    commit: GitCommit @json
  
  @spec "Commit created":
    input.message.length > 0 ->
    output.commit.hash.length == 40 || output.commit.hash.length == 7

// ============================================================
// TOOL: Просмотр diff
// ============================================================

TOOL git_diff
  @spec: (str?) -> List(GitDiff)
  description: "Показывает diff между текущей веткой и другой"
  
  input:
    compare_to_branch: str? @query = "main" "Ветка для сравнения"
  
  output:
    diffs: List(GitDiff) @json

// ============================================================
// TOOL: История коммитов
// ============================================================

TOOL git_log
  @spec: (str?, int) -> List(GitCommit)
  description: "Получает историю коммитов"
  
  input:
    branch: str? @query "Ветка для просмотра"
    limit: int? @query = 10 "Количество коммитов"
  
  output:
    commits: List(GitCommit) @json

// ============================================================
// TOOL: Создание Pull Request
// ============================================================

TOOL create_pull_request
  @spec: (str, str, str) -> PullRequest
  description: "Создает Pull Request"
  
  input:
    title: str! @body "Заголовок PR"
    description: str! @body "Описание PR"
    from_branch: str! @body "Ветка с изменениями"
    to_branch: str? @body = "main" "Целевая ветка"
    reviewers: List(str)? @body "GitHub юзернеймы ревьюеров"
    labels: List(str)? @body "Лейблы для PR"
  
  output:
    pr: PullRequest @json
  
  @spec "PR created":
    input.title.length > 0 ->
    input.description.length > 0 ->
    output.pr.id != null

// ============================================================
// TOOL: Запрос ревью
// ============================================================

TOOL request_code_review
  @spec: (str, List(str)) -> str
  description: "Запрашивает code review у разработчиков"
  
  input:
    pr_id: str! @body "ID Pull Request"
    reviewers: List(str)! @body "GitHub юзернеймы"
  
  output:
    status: str @json

// ============================================================
// TOOL: Merge Pull Request
// ============================================================

TOOL merge_pull_request
  @spec: str -> GitCommit
  description: "Мерджит Pull Request"
  
  input:
    pr_id: str! @body
  
  output:
    merge_commit: GitCommit @json

// ============================================================
// TOOL: Переключение ветки
// ============================================================

TOOL git_checkout
  @spec: (str, bool) -> GitCommit
  description: "Переключается на указанную ветку"
  
  input:
    branch: str! @body
    create_if_missing: bool? @body = false
  
  output:
    current_commit: GitCommit @json

// ============================================================
// API ENDPOINTS
// ============================================================

POST /api/v1/swe/git/branch "Создать ветку"
  branch_name: str! @body
  from_branch: str? @body

POST /api/v1/swe/git/commit "Сделать коммит"
  message: str! @body
  files: List(str)? @body

GET /api/v1/swe/git/diff "Получить diff"
  compare_to_branch: str? @query

GET /api/v1/swe/git/log "История коммитов"
  branch: str? @query
  limit: int? @query

POST /api/v1/swe/git/pr "Создать Pull Request"
  title: str! @body
  description: str! @body
  from_branch: str! @body
```

---

## 5️⃣ Orchestrator и Scenes

### 5.1 Главный SWE Agent

**Файл**: `src/vibee/dsl/agent/swe_agent.vibee`

```vibee
@module_defaults(
  log: "swe_agent",
  auth_required: true,
  error_handler: "graceful"
)

// ============================================================
// Главный API для SWE Agent
// ============================================================

// Запустить новую задачу
POST /api/v1/swe/task "Запустить SWE задачу"
  @spec "Task created": 
    session_id != null -> 
    description.length > 0 -> 
    result.id != null
  
  description: str! @body "Описание задачи"
  repository: str! @body "URL репозитория (GitHub/GitLab)"
  branch: str? @body = "develop" "Ветка для работы"
  auto_commit: bool? @body = true "Авто-коммитить"
  create_pr: bool? @body = true "Создать PR автоматически"
  
  // Результат: {id: str, status: "PENDING", ...}

// Получить статус задачи
GET /api/v1/swe/task/:task_id "Статус задачи"
  @spec "Task found": task_id != null -> result.id != null
  
  // Результат: Task с текущим статусом и прогрессом

// Получить результаты
GET /api/v1/swe/task/:task_id/results "Результаты выполнения"
  @spec "Results available": status == SUCCESS -> result != null
  
  // Результат: {
  //   pr_url, code_files, test_files, documentation,
  //   quality_metrics, deployment_status
  // }

// Отменить задачу
POST /api/v1/swe/task/:task_id/cancel "Отменить задачу"
  reason: str? @body
  
  // Результат: {status: "CANCELLED"}

// Получить логи
GET /api/v1/swe/task/:task_id/logs "Логи выполнения"
  level: str? @query = "info" "Уровень логирования"
  limit: int? @query = 100 "Количество строк"
  
  // Результат: List(LogEntry)

// WebSocket для live updates
WS /api/v1/swe/task/:task_id/stream "Live обновления"
  // События: step_started, step_completed, error, progress, completed
```

### 5.2 Сцена: Реализация фичи

**Файл**: `src/vibee/dsl/agent/scenes/implement_feature.vibee`

```vibee
SCENE implement_feature
  @log("scene.implement_feature")
  @spec "Feature implemented":
    task != null ->
    code_written() && tests_passing() ->
    pr_created() ->
    result == SUCCESS

  description: "Полный цикл реализации новой функциональности"
  
  // ====== ШАГ 1: Парсинг задачи ======
  STEP parse_task
    @log("implement_feature.parse_task")
    description: "Преобразование текстового описания в структурированный Task"
    
    input:
      task_description: str
    output:
      task: Task
    
    TOOL call parse_task_description
      input: {description: task_description}
      output: task
    
    // Валидация
    @assert task.id != null
    @assert task.title.length > 0
  
  // ====== ШАГ 2: Анализ кодовой базы ======
  STEP analyze_codebase
    @log("implement_feature.analyze_codebase")
    description: "Анализ существующей архитектуры и зависимостей"
    
    input:
      repository: str
      task: Task
    output:
      code_structure: CodeStructure
      relevant_files: List(str)
      affected_modules: List(str)
    
    TOOL call analyze_module_dependencies
      input: {directory: repository}
      output: code_structure
    
    TOOL call find_symbol_usages
      input: {symbol_name: task.title}
      output: relevant_files
  
  // ====== ШАГ 3: Генерация плана ======
  STEP generate_plan
    @log("implement_feature.generate_plan")
    description: "Создание детального плана реализации"
    
    input:
      task: Task
      context: CodeStructure
    output:
      plan: ImplementationPlan
      estimated_time: int
    
    TOOL call generate_implementation_plan
      input: {task: task}
      output: plan
  
  // ====== ШАГ 4: Генерация кода ======
  STEP generate_code
    @log("implement_feature.generate_code")
    description: "Написание кода функций/модулей"
    
    input:
      task: Task
      plan: ImplementationPlan
    output:
      code_files: Map(str, str)  // path -> content
    
    FOR_EACH step IN plan.phases:
      TOOL call generate_code
        input: {
          prompt: step.description,
          context_files: task.affected_files
        }
        output: generated_code
      
      // Сохранить код в файлы
      @action write_files: generated_code
  
  // ====== ШАГ 5: Написание тестов ======
  STEP write_tests
    @log("implement_feature.write_tests")
    description: "Создание тест-кейсов"
    
    input:
      code_files: Map(str, str)
      task: Task
    output:
      test_files: Map(str, str)
    
    FOR_EACH path, code IN code_files:
      TOOL call generate_tests
        input: {code: code, test_type: "unit"}
        output: test_code
      
      @action write_file: {path: "#{path}_test.gleam", content: test_code}
  
  // ====== ШАГ 6: Запуск тестов ======
  STEP run_tests
    @log("implement_feature.run_tests")
    description: "Проверка что все тесты проходят"
    
    input:
      directory: str
    output:
      test_suite: TestSuite
    
    TOOL call run_tests
      input: {directory: directory}
      output: test_suite
    
    // Критическая проверка!
    @assert test_suite.success == true
      @on_fail: "Tests failed! #{test_suite.failed} failures out of #{test_suite.total_tests}"
  
  // ====== ШАГ 7: Статический анализ ======
  STEP quality_checks
    @log("implement_feature.quality_checks")
    description: "Проверка качества кода"
    
    input:
      directory: str
    output:
      issues: List(Issue)
      passed: bool
    
    TOOL call static_analysis
      input: {directory: directory}
      output: static_issues
    
    TOOL call security_scan
      input: {directory: directory}
      output: security_issues
    
    // Предупреждение если есть проблемы
    IF static_issues.count > 0:
      @log "Warning: #{static_issues.count} static issues found"
    
    // Критично для безопасности
    @assert security_issues.filter(|i| i.severity == "CRITICAL").count == 0
      @on_fail: "Critical security issues found!"
  
  // ====== ШАГ 8: Покрытие тестами ======
  STEP analyze_coverage
    @log("implement_feature.analyze_coverage")
    description: "Проверка покрытия кода тестами"
    
    input:
      directory: str
    output:
      coverage: CoverageReport
    
    TOOL call analyze_code_coverage
      input: {directory: directory, threshold: 80}
      output: coverage
    
    IF coverage.total_coverage < 80:
      @log "Warning: Coverage is #{coverage.total_coverage}%, target is 80%"
  
  // ====== ШАГ 9: Документация ======
  STEP update_documentation
    @log("implement_feature.update_documentation")
    description: "Создание/обновление документации"
    
    input:
      code_files: Map(str, str)
      task: Task
    output:
      docs_updated: bool
    
    TOOL call generate_api_docs
      input: {directory: repository}
      output: api_docs
    
    // Обновить README если нужно
    IF task.title.contains("API"):
      @action write_file: {path: "docs/api.md", content: api_docs}
  
  // ====== ШАГ 10: Git операции ======
  STEP git_workflow
    @log("implement_feature.git_workflow")
    description: "Создание ветки, коммиты, PR"
    
    input:
      code: Map(str, str)
      task: Task
    output:
      pr_id: str
      pr_url: str
    
    // Создать ветку
    TOOL call git_create_branch
      input: {branch_name: "feature/#{task.id}"}
      output: branch_commit
    
    // Переключиться на ветку
    TOOL call git_checkout
      input: {branch: "feature/#{task.id}"}
      output: current_commit
    
    // Коммитить всё
    TOOL call git_commit
      input: {message: "feat: Implement #{task.title}"}
      output: commit
    
    // Создать PR
    TOOL call create_pull_request
      input: {
        title: "Feature: #{task.title}",
        description: task.description,
        from_branch: "feature/#{task.id}",
        to_branch: "develop",
        labels: ["feature", "auto-generated"]
      }
      output: pr
  
  // ====== ФИНАЛЬНЫЙ РЕЗУЛЬТАТ ======
  RESULT
    status: SUCCESS
    summary: {
      title: task.title,
      description: task.description,
      pr_id: pr.id,
      pr_url: pr.html_url,
      branch: "feature/#{task.id}",
      files_created: code_files.keys().count(),
      test_coverage: coverage.total_coverage,
      quality_issues: issues.count(),
      security_issues: security_issues.count()
    }
```

### 5.3 Сцена: Исправление бага

**Файл**: `src/vibee/dsl/agent/scenes/fix_bug.vibee`

```vibee
SCENE fix_bug
  @log("scene.fix_bug")
  @spec "Bug fixed": bug_found() -> fix_applied() -> tests_pass() -> result == SUCCESS
  
  description: "Автоматическое обнаружение и исправление bagов"
  
  // ====== ШАГ 1: Анализ бага ======
  STEP analyze_bug
    @log("fix_bug.analyze_bug")
    
    input:
      bug_id: str
      bug_description: str
      error_trace: str?
    output:
      bug_analysis: BugAnalysis
    
    // Парсить описание и анализировать
    TOOL call parse_task_description
      input: {description: bug_description}
      output: task
    
    // Найти затронутые файлы
    TOOL call find_symbol_definition
      input: {symbol_name: task.title}
      output: affected_files
  
  // ====== ШАГ 2: Локализация бага ======
  STEP locate_bug
    @log("fix_bug.locate_bug")
    
    input:
      codebase: str
      bug_analysis: BugAnalysis
    output:
      affected_files: List(str)
      suspected_location: {file: str, line: int}
      root_cause: str
    
    // Анализировать код
    TOOL call detect_code_smells
      input: {file_path: bug_analysis.initial_file}
      output: code_issues
    
    // Найти проблему
    @action analyze_error_trace
  
  // ====== ШАГ 3: Воспроизведение бага ======
  STEP create_failing_test
    @log("fix_bug.create_failing_test")
    
    input:
      bug_analysis: BugAnalysis
      location: {file: str, line: int}
    output:
      test_code: str
    
    TOOL call generate_tests
      input: {code: bug_code, test_type: "unit"}
      output: test_code
    
    // Тест должен failнуть
    @assert run_test(test_code) == FAIL
  
  // ====== ШАГ 4: Применение исправления ======
  STEP apply_fix
    @log("fix_bug.apply_fix")
    
    input:
      affected_files: List(str)
      root_cause: str
      bug_location: {file: str, line: int}
    output:
      fixed_code: str
    
    TOOL call generate_code
      input: {
        prompt: "Fix: #{root_cause}",
        context_files: affected_files
      }
      output: fixed_code
    
    // Применить исправление
    @action write_file: {path: bug_location.file, content: fixed_code}
  
  // ====== ШАГ 5: Проверка исправления ======
  STEP verify_fix
    @log("fix_bug.verify_fix")
    
    input:
      directory: str
      test_code: str
    output:
      test_result: TestSuite
    
    TOOL call run_tests
      input: {directory: directory}
      output: test_result
    
    // Тест должен теперь пассить
    @assert test_result.success == true
      @on_fail: "Fix didn't work! Tests still failing"
  
  // ====== ШАГ 6: Регрессионное тестирование ======
  STEP regression_tests
    @log("fix_bug.regression_tests")
    
    input:
      directory: str
    output:
      regression_result: TestSuite
    
    TOOL call run_tests
      input: {
        directory: directory,
        pattern: "**/*_test.gleam"  // Все тесты
      }
      output: regression_result
    
    @assert regression_result.success == true
      @on_fail: "Regression detected! New failures introduced"
  
  // ====== ШАГ 7: Git операции ======
  STEP create_fix_pr
    @log("fix_bug.create_fix_pr")
    
    input:
      fixed_code: str
      bug_id: str
    output:
      pr_id: str
    
    // Создать ветку
    TOOL call git_create_branch
      input: {branch_name: "fix/bug-#{bug_id}"}
      output: branch
    
    // Коммитить
    TOOL call git_commit
      input: {message: "fix: Resolve #{bug_id} - #{bug_description}"}
      output: commit
    
    // Создать PR
    TOOL call create_pull_request
      input: {
        title: "Fix: #{bug_id}",
        description: bug_description,
        from_branch: "fix/bug-#{bug_id}",
        labels: ["bug-fix", "auto-generated"]
      }
      output: pr
  
  // ====== РЕЗУЛЬТАТ ======
  RESULT
    status: SUCCESS
    summary: {
      bug_id: bug_id,
      fixed_at: current_time(),
      pr_id: pr.id,
      test_coverage: regression_result.coverage,
      tests_fixed: test_result.passed,
      regressions: 0
    }
```

---

## 📝 Примеры использования API

### Пример 1: Простая реализация фичи

```bash
curl -X POST http://localhost:8080/api/v1/swe/task \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "description": "Add pagination to user list API endpoint",
    "repository": "https://github.com/myorg/myapp",
    "branch": "develop",
    "auto_commit": true,
    "create_pr": true
  }'

# Результат:
# {
#   "task_id": "task_123456",
#   "status": "PENDING",
#   "created_at": "2024-01-04T10:00:00Z"
# }
```

### Пример 2: Отслеживание прогресса

```bash
# Получить статус
curl http://localhost:8080/api/v1/swe/task/task_123456 \
  -H "Authorization: Bearer YOUR_TOKEN"

# Результат:
# {
#   "task_id": "task_123456",
#   "status": "RUNNING",
#   "current_step": "run_tests",
#   "progress": 0.75,
#   "started_at": "2024-01-04T10:00:00Z"
# }
```

### Пример 3: Получение результатов

```bash
curl http://localhost:8080/api/v1/swe/task/task_123456/results \
  -H "Authorization: Bearer YOUR_TOKEN"

# Результат:
# {
#   "status": "SUCCESS",
#   "pr_url": "https://github.com/myorg/myapp/pull/42",
#   "files_created": 3,
#   "test_coverage": 85.5,
#   "quality_issues": 2,
#   "deployment_status": "ready_for_review"
# }
```

---

## 🔧 Синтаксические особенности VIBEE

### Использование @auth вместо явной session_id

**Раньше (85 строк)**:
```vibee
POST /api/v1/task "Create task"
  @log("tasks")
  @auth_required
  
  session_id: str! @session          // <- Явно указывать
  title: str! @body
  description: str! @body

// Повторять для каждого эндпоинта
```

**Сейчас (46 строк, -46%)**:
```vibee
@module_defaults(
  log: "tasks",
  auth_required: true
)

POST /api/v1/task "Create task"
  @auth                              // <- Неявно
  
  title: str! @body
  description: str! @body

// Не нужно повторять!
```

### @spec для спецификаций

```vibee
TOOL my_tool
  @spec: (str, int) -> bool
  description: "My tool"
  
  input:
    name: str!
    count: int!
  
  output:
    result: bool
  
  // Спецификация: когда это работает
  @spec "Valid result": 
    name.length > 0 ->
    count >= 0 ->
    result != null
  
  // Спецификация для ошибок
  @on_error: "Tool failed"
```

---

## 🚀 Следующие шаги

1. **Начать с Task Parser** - это основа всего
2. **Реализовать Orchestrator** - управление состоянием
3. **Добавить LLM интеграцию** - логика решений
4. **Создать первую сцену** - implement_feature
5. **Тестировать на реальных задачах** - итерировать
6. **Деплоить на production** - доступно всем

---

**Автор**: SWE Agent Implementation Guide
**Дата**: 2026-01-04
**Версия**: 1.0

