# 🤖 SWE Agent на языке .vibee - План реализации

## 📋 Обзор

Это подробный план создания полнофункционального Software Engineering (SWE) агента на языке **VIBEE DSL** (.vibee). Агент будет способен автоматически:
- Анализировать задачи и разбивать их на подзадачи
- Писать и отлаживать код
- Проверять качество кода и безопасность
- Управлять версионированием и деплоем
- Взаимодействовать с репозиториями и CI/CD

---

## 🎯 Архитектура SWE Agent

```
┌─────────────────────────────────────────────────────────────────┐
│                     SWE Agent (Gleam/BEAM)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              VIBEE DSL Modules (.vibee)                    │  │
│  │  ┌──────────────────────────────────────────────────────┐ │  │
│  │  │ 1. Task Parser & Planner                            │ │  │
│  │  │    • Парсинг требований                             │ │  │
│  │  │    • Генерация плана реализации                      │ │  │
│  │  │    • Декомпозиция на подзадачи                      │ │  │
│  │  └──────────────────────────────────────────────────────┘ │  │
│  │                                                             │  │
│  │  ┌──────────────────────────────────────────────────────┐ │  │
│  │  │ 2. Code Intelligence Tools                          │ │  │
│  │  │    • Анализ существующего кода                      │ │  │
│  │  │    • Поиск и реферenciирование                      │ │  │
│  │  │    • Генерация кода                                 │ │  │
│  │  │    • Рефакторинг                                    │ │  │
│  │  └──────────────────────────────────────────────────────┘ │  │
│  │                                                             │  │
│  │  ┌──────────────────────────────────────────────────────┐ │  │
│  │  │ 3. Quality Assurance Tools                          │ │  │
│  │  │    • Статический анализ                             │ │  │
│  │  │    • Тестирование                                   │ │  │
│  │  │    • Проверка типов                                 │ │  │
│  │  │    • Безопасность                                   │ │  │
│  │  └──────────────────────────────────────────────────────┘ │  │
│  │                                                             │  │
│  │  ┌──────────────────────────────────────────────────────┐ │  │
│  │  │ 4. VCS & Deployment Tools                           │ │  │
│  │  │    • Git операции                                   │ │  │
│  │  │    • Pull Request управление                        │ │  │
│  │  │    • CI/CD интеграция                               │ │  │
│  │  │    • Деплой управление                              │ │  │
│  │  └──────────────────────────────────────────────────────┘ │  │
│  │                                                             │  │
│  │  ┌──────────────────────────────────────────────────────┐ │  │
│  │  │ 5. Documentation & Learning Tools                   │ │  │
│  │  │    • Генерация документации                          │ │  │
│  │  │    • Создание примеров                              │ │  │
│  │  │    • Обновление README                              │ │  │
│  │  │    • Knowledge base управление                      │ │  │
│  │  └──────────────────────────────────────────────────────┘ │  │
│  │                                                             │  │
│  │  ┌──────────────────────────────────────────────────────┐ │  │
│  │  │ 6. Orchestration & Decision Making                  │ │  │
│  │  │    • Task состояние                                 │ │  │
│  │  │    • Dependency resolution                          │ │  │
│  │  │    • Error handling & retry logic                   │ │  │
│  │  │    • Feedback loop & adaptation                     │ │  │
│  │  └──────────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │         Underlying Tools (Integration Layer)               │  │
│  │  • git_execute (shell commands)                            │  │
│  │  • file_read, file_write (FS operations)                   │  │
│  │  • gleam_compile, gleam_test (Build tools)                 │  │
│  │  • http_request (API calls)                                │  │
│  │  • llm_query (LLM integration)                             │  │
│  │  • db_query (Database operations)                          │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📂 Структура файлов

```
/workspaces/vibee/src/vibee/dsl/agent/
├── swe_agent.vibee                    # Главный SWE Agent
├── task_parser.vibee                  # Парсинг задач
├── code_intelligence.vibee            # Анализ и генерация кода
├── quality_assurance.vibee            # QA инструменты
├── vcs_tools.vibee                    # Git/VCS интеграция
├── deployment.vibee                   # Деплой управление
├── documentation.vibee                # Документация
├── orchestrator.vibee                 # Оркестратор
└── scenes/
    ├── analyze_code.vibee             # Сцена анализа
    ├── implement_feature.vibee        # Сцена реализации
    ├── fix_bug.vibee                  # Сцена исправления
    ├── refactor.vibee                 # Сцена рефакторинга
    ├── code_review.vibee              # Сцена ревью
    ├── test_coverage.vibee            # Сцена тестирования
    └── deploy.vibee                   # Сцена деплоя
```

---

## 🔧 Фаза 1: Парсинг и планирование задач

### 1.1 Task Parser

**Файл**: `task_parser.vibee`

```vibee
// Task структура
TYPE Task {
  id: str
  title: str
  description: str
  priority: Priority  // HIGH, MEDIUM, LOW
  complexity: Complexity  // SIMPLE, MODERATE, COMPLEX
  estimated_hours: int
  dependencies: List(str)  // Другие task IDs
  subtasks: List(Task)
  acceptance_criteria: List(str)
  technologies: List(str)  // Используемые технологии
  affected_files: List(str)
}

TYPE Priority = HIGH | MEDIUM | LOW
TYPE Complexity = SIMPLE | MODERATE | COMPLEX

// Tool: Парсинг текстового описания задачи в структурированный Task
TOOL parse_task_description
  @spec: str -> Task
  description: "Парсит текстовое описание в структурированный Task"
  
  input:
    task_description: str!  @body "Описание задачи"
  
  output:
    task: Task              @json "Структурированная задача"

// Tool: Декомпозиция задачи на подзадачи
TOOL decompose_task
  @spec: Task -> List(Task)
  description: "Разбивает задачу на подзадачи"
  
  input:
    task: Task!  @body
    max_depth: int? = 3  @query
  
  output:
    subtasks: List(Task)  @json

// Tool: Приоритизация и оценка задач
TOOL prioritize_tasks
  @spec: List(Task) -> List(Task)
  description: "Приоритизирует и оценивает список задач"
  
  input:
    tasks: List(Task)!  @body
  
  output:
    prioritized: List(Task)  @json

// Tool: Определение зависимостей между задачами
TOOL analyze_dependencies
  @spec: List(Task) -> DependencyGraph
  description: "Анализирует зависимости между задачами"
  
  input:
    tasks: List(Task)!  @body
  
  output:
    graph: DependencyGraph  @json

// Tool: Генерация плана реализации
TOOL generate_implementation_plan
  @spec: Task -> ImplementationPlan
  description: "Генерирует детальный план реализации"
  
  input:
    task: Task!  @body
  
  output:
    plan: ImplementationPlan  @json
```

---

## 📖 Фаза 2: Анализ кода (Code Intelligence)

### 2.1 Code Analysis Tools

**Файл**: `code_intelligence.vibee`

```vibee
// Code структуры
TYPE CodeFile {
  path: str
  language: str  // gleam, rust, typescript, etc.
  content: str
  imports: List(str)
  exports: List(str)
  functions: List(FunctionSignature)
  types: List(TypeDefinition)
  size_lines: int
}

TYPE FunctionSignature {
  name: str
  module: str
  params: List(Parameter)
  return_type: str
  docstring: str?
  specs: List(str)
}

TYPE TypeDefinition {
  name: str
  kind: str  // type, record, enum, etc.
  fields: List(Field)
  docstring: str?
}

// Tool: Анализ структуры кода
TOOL analyze_code_structure
  @spec: str -> CodeFile
  description: "Анализирует структуру файла кода"
  
  input:
    file_path: str!  @query "Путь к файлу"
  
  output:
    structure: CodeFile  @json

// Tool: Поиск функций и типов
TOOL find_symbol
  @spec: (str, str) -> List(CodeFile)
  description: "Ищет определения символа в кодовой базе"
  
  input:
    symbol: str!  @query "Имя функции/типа"
    directory: str? @query "Директория для поиска"
  
  output:
    results: List(CodeFile)  @json

// Tool: Анализ зависимостей между модулями
TOOL analyze_module_dependencies
  @spec: str -> DependencyGraph
  description: "Анализирует зависимости модулей"
  
  input:
    directory: str!  @query "Директория проекта"
  
  output:
    graph: DependencyGraph  @json

// Tool: Поиск антипаттернов и техдолга
TOOL detect_code_smells
  @spec: str -> List(CodeSmell)
  description: "Обнаруживает антипаттерны и техдолг"
  
  input:
    file_path: str!  @query
  
  output:
    smells: List(CodeSmell)  @json

// Tool: Генерация кода на основе примеров
TOOL generate_code
  @spec: CodeGenerationRequest -> str
  description: "Генерирует код для функции"
  
  input:
    prompt: str!  @body "Описание функции"
    language: str? @body = "gleam"
    context_files: List(str)?  @body "Файлы контекста"
  
  output:
    code: str  @text

// Tool: Рефакторинг существующего кода
TOOL refactor_code
  @spec: (str, RefactoringType) -> str
  description: "Рефакторит код"
  
  input:
    code: str!  @body
    refactoring_type: str!  @body  // extract_function, inline, rename, etc.
    target_name: str?  @body
  
  output:
    refactored_code: str  @text

// Tool: Объяснение кода
TOOL explain_code
  @spec: str -> str
  description: "Объясняет логику кода"
  
  input:
    code: str!  @body
    depth: str? @query = "medium"  // brief, medium, detailed
  
  output:
    explanation: str  @text
```

---

## ✅ Фаза 3: Quality Assurance

### 3.1 QA Tools

**Файл**: `quality_assurance.vibee`

```vibee
// QA структуры
TYPE TestSuite {
  name: str
  language: str
  tests: List(TestCase)
  coverage: float  // 0.0 - 1.0
  pass_count: int
  fail_count: int
  skip_count: int
}

TYPE TestCase {
  name: str
  description: str
  status: TestStatus  // PASS, FAIL, SKIP, PENDING
  duration_ms: int
  error_message: str?
}

TYPE SecurityVulnerability {
  id: str
  severity: Severity  // CRITICAL, HIGH, MEDIUM, LOW
  description: str
  location: CodeLocation
  remediation: str
}

// Tool: Запуск тестов
TOOL run_tests
  @spec: str -> TestSuite
  description: "Запускает тесты для проекта"
  
  input:
    directory: str!  @query
    test_pattern: str? @query = "*_test.gleam"
    filter: str? @query "Фильтр тестов"
  
  output:
    suite: TestSuite  @json

// Tool: Генерация тестов
TOOL generate_tests
  @spec: str -> str
  description: "Генерирует тест-кейсы для функции"
  
  input:
    code: str!  @body "Исходный код"
    test_type: str? @body = "unit"  // unit, integration, e2e
  
  output:
    test_code: str  @text

// Tool: Анализ покрытия кода
TOOL analyze_coverage
  @spec: str -> CoverageReport
  description: "Анализирует покрытие тестами"
  
  input:
    directory: str!  @query
  
  output:
    report: CoverageReport  @json

// Tool: Проверка типов (для Gleam)
TOOL check_types
  @spec: str -> TypeCheckResult
  description: "Проверяет типы в коде"
  
  input:
    directory: str!  @query
  
  output:
    result: TypeCheckResult  @json

// Tool: Статический анализ
TOOL static_analysis
  @spec: str -> List(Issue)
  description: "Запускает статический анализ"
  
  input:
    directory: str!  @query
    rules: List(str)? @body "Какие правила применять"
  
  output:
    issues: List(Issue)  @json

// Tool: Проверка безопасности (SAST)
TOOL security_scan
  @spec: str -> List(SecurityVulnerability)
  description: "Сканирует код на уязвимости"
  
  input:
    directory: str!  @query
  
  output:
    vulnerabilities: List(SecurityVulnerability)  @json

// Tool: Проверка производительности
TOOL performance_check
  @spec: str -> PerformanceReport
  description: "Проверяет производительность кода"
  
  input:
    directory: str!  @query
    profile: str? @query = "default"
  
  output:
    report: PerformanceReport  @json
```

---

## 🚀 Фаза 4: VCS и Deployment

### 4.1 VCS Tools

**Файл**: `vcs_tools.vibee`

```vibee
// VCS структуры
TYPE GitDiff {
  file: str
  additions: int
  deletions: int
  changes: List(Change)
}

TYPE Change {
  type: ChangeType  // ADD, MODIFY, DELETE
  before: str?
  after: str?
}

TYPE PullRequest {
  id: str
  title: str
  description: str
  author: str
  branch: str
  status: PRStatus  // DRAFT, OPEN, APPROVED, MERGED, CLOSED
  reviews: List(Review)
}

TYPE Commit {
  hash: str
  message: str
  author: str
  timestamp: str
  files_changed: int
  insertions: int
  deletions: int
}

// Tool: Создание ветки
TOOL git_create_branch
  @spec: (str, str) -> Commit
  description: "Создает новую git ветку"
  
  input:
    branch_name: str!  @body
    from_branch: str? @body = "main"
  
  output:
    commit: Commit  @json

// Tool: Коммит изменений
TOOL git_commit
  @spec: (str, List(str)) -> Commit
  description: "Коммитит изменения"
  
  input:
    message: str!  @body
    files: List(str)?  @body "Файлы для коммита (все если не указано)"
  
  output:
    commit: Commit  @json

// Tool: Просмотр diff
TOOL git_diff
  @spec: () -> List(GitDiff)
  description: "Показывает diff между веткой и main"
  
  output:
    diffs: List(GitDiff)  @json

// Tool: Создание Pull Request
TOOL create_pull_request
  @spec: PullRequestRequest -> PullRequest
  description: "Создает Pull Request"
  
  input:
    title: str!  @body
    description: str!  @body
    from_branch: str!  @body
    to_branch: str? @body = "main"
    reviewers: List(str)? @body
  
  output:
    pr: PullRequest  @json

// Tool: Запрос ревью
TOOL request_review
  @spec: (str, List(str)) -> str
  description: "Запрашивает ревью у разработчиков"
  
  input:
    pr_id: str!  @body
    reviewers: List(str)!  @body
  
  output:
    status: str  @json

// Tool: Merge Pull Request
TOOL merge_pull_request
  @spec: str -> Commit
  description: "Мерджит Pull Request"
  
  input:
    pr_id: str!  @body
  
  output:
    merge_commit: Commit  @json

// Tool: История коммитов
TOOL git_log
  @spec: (str?, int) -> List(Commit)
  description: "Получает историю коммитов"
  
  input:
    branch: str? @query
    limit: int? @query = 10
  
  output:
    commits: List(Commit)  @json
```

### 4.2 Deployment Tools

**Файл**: `deployment.vibee`

```vibee
// Deployment структуры
TYPE DeploymentTask {
  id: str
  service: str  // gleam, telegram-bridge, remotion
  environment: str  // dev, staging, prod
  status: DeploymentStatus  // PENDING, RUNNING, SUCCESS, FAILED
  start_time: str
  end_time: str?
  logs: List(str)
  error_message: str?
}

TYPE HealthCheck {
  service: str
  endpoint: str
  status: HealthStatus  // HEALTHY, DEGRADED, UNHEALTHY
  response_time_ms: int
  last_check: str
}

// Tool: Сборка проекта
TOOL build_project
  @spec: str -> BuildResult
  description: "Собирает проект"
  
  input:
    directory: str!  @query
    target: str? @query = "default"
  
  output:
    result: BuildResult  @json

// Tool: Деплой на Fly.io
TOOL deploy_fly
  @spec: (str, str, str) -> DeploymentTask
  description: "Деплоит на Fly.io"
  
  input:
    app_name: str!  @body  // vibee-mcp, vibee-telegram-bridge
    environment: str? @body = "prod"
    force: bool? @body = false
  
  output:
    deployment: DeploymentTask  @json

// Tool: Установка секретов
TOOL set_fly_secret
  @spec: (str, str, str) -> str
  description: "Устанавливает секрет на Fly.io"
  
  input:
    app_name: str!  @body
    secret_name: str!  @body
    secret_value: str!  @body
  
  output:
    status: str  @json

// Tool: Проверка здоровья
TOOL health_check
  @spec: str -> HealthCheck
  description: "Проверяет здоровье сервиса"
  
  input:
    service_url: str!  @query
  
  output:
    check: HealthCheck  @json

// Tool: Откат деплоя
TOOL rollback_deployment
  @spec: (str, str) -> DeploymentTask
  description: "Откатывает последний деплой"
  
  input:
    app_name: str!  @body
    to_version: str? @body "Версия для отката"
  
  output:
    deployment: DeploymentTask  @json

// Tool: Просмотр логов
TOOL view_logs
  @spec: (str, int) -> List(str)
  description: "Просматривает логи приложения"
  
  input:
    app_name: str!  @query
    lines: int? @query = 100
  
  output:
    logs: List(str)  @json
```

---

## 📚 Фаза 5: Документация

### 5.1 Documentation Tools

**Файл**: `documentation.vibee`

```vibee
// Documentation структуры
TYPE DocumentationPage {
  title: str
  path: str
  content: str
  sections: List(Section)
  examples: List(Example)
  related_pages: List(str)
}

TYPE Section {
  heading: str
  content: str
  level: int  // 1-6
}

// Tool: Генерация README
TOOL generate_readme
  @spec: str -> str
  description: "Генерирует README файл"
  
  input:
    directory: str!  @query
    template: str? @query = "default"
  
  output:
    readme: str  @text

// Tool: Генерация API документации
TOOL generate_api_docs
  @spec: str -> str
  description: "Генерирует документацию API"
  
  input:
    directory: str!  @query
    output_format: str? @query = "markdown"
  
  output:
    docs: str  @text

// Tool: Создание примеров кода
TOOL create_code_examples
  @spec: str -> List(Example)
  description: "Создает примеры использования функций"
  
  input:
    code: str!  @body
    example_count: int? @body = 3
  
  output:
    examples: List(Example)  @json

// Tool: Обновление документации
TOOL update_documentation
  @spec: (str, str, str) -> str
  description: "Обновляет раздел документации"
  
  input:
    doc_path: str!  @body
    section: str!  @body
    new_content: str!  @body
  
  output:
    updated_path: str  @text

// Tool: Генерация CHANGELOG
TOOL generate_changelog
  @spec: (str, int) -> str
  description: "Генерирует CHANGELOG"
  
  input:
    directory: str!  @query
    last_commits: int? @query = 50
  
  output:
    changelog: str  @text
```

---

## 🎭 Фаза 6: Оркестратор и сцены

### 6.1 Главный SWE Agent

**Файл**: `swe_agent.vibee`

```vibee
@module_defaults(
  log: "swe_agent",
  auth_required: true,
  error_handler: "default"
)

// Главный API для запуска SWE Agent
POST /api/v1/swe/task "Запустить SWE задачу"
  @spec "Task started": valid_session(session_id) -> task_id != null
  
  session_id: str! @session
  task_description: str! @body "Описание задачи"
  repository: str! @body "URL репозитория"
  branch: str? @body = "develop" "Ветка для работы"
  auto_commit: bool? @body = true "Автоматически коммитить изменения"
  create_pr: bool? @body = true "Создать Pull Request"
  
// Получить статус задачи
GET /api/v1/swe/task/:task_id "Получить статус задачи"
  @spec "Returns task": task_exists(task_id) -> status != null
  
  task_id: str!

// Получить результаты работы
GET /api/v1/swe/task/:task_id/results "Получить результаты"
  @spec "Returns results": task_complete(task_id) -> result != null
  
  task_id: str!

// Отменить задачу
POST /api/v1/swe/task/:task_id/cancel "Отменить задачу"
  @spec "Task cancelled": task_running(task_id) -> status == CANCELLED
  
  session_id: str! @session
  task_id: str!
  reason: str? @body
```

### 6.2 Сцены (Scenes)

**Файл**: `scenes/implement_feature.vibee`

```vibee
// Сцена: реализация новой фичи
SCENE implement_feature
  @log("scenes.implement_feature")
  @spec "Feature implemented": 
    valid_task(task) -> 
    code_written() -> 
    tests_passing() -> 
    pr_created() -> 
    result == SUCCESS

  // Шаг 1: Парсинг задачи
  STEP parse_task
    @log("step.parse_task")
    input:
      task_description: str
    output:
      task: Task
    
    TOOL call parse_task_description
      input: task_description
      output: task

  // Шаг 2: Анализ кодовой базы
  STEP analyze_codebase
    @log("step.analyze_codebase")
    input:
      repository: str
      task: Task
    output:
      code_structure: CodeStructure
      relevant_files: List(str)
    
    TOOL call analyze_module_dependencies
      input: repository
      output: code_structure
    
    TOOL call find_symbol
      input: task.affected_files[0]
      output: relevant_files

  // Шаг 3: Генерация кода
  STEP generate_code
    @log("step.generate_code")
    input:
      task: Task
      context: CodeStructure
    output:
      code: str
      files_to_create: List(str)
    
    TOOL call generate_code
      input: {
        prompt: task.description,
        context_files: task.affected_files
      }
      output: code

  // Шаг 4: Написание тестов
  STEP write_tests
    @log("step.write_tests")
    input:
      code: str
      task: Task
    output:
      test_code: str
    
    TOOL call generate_tests
      input: code
      output: test_code

  // Шаг 5: Запуск тестов
  STEP run_tests
    @log("step.run_tests")
    input:
      directory: str
    output:
      suite: TestSuite
    
    TOOL call run_tests
      input: directory
      output: suite
    
    // Проверка результатов
    CONDITION suite.fail_count == 0
      true: continue
      false: -> ERROR "Tests failed"

  // Шаг 6: Проверка качества
  STEP quality_checks
    @log("step.quality_checks")
    input:
      directory: str
    output:
      issues: List(Issue)
    
    TOOL call static_analysis
      input: directory
      output: issues
    
    TOOL call security_scan
      input: directory
      output: vulnerabilities

  // Шаг 7: Git операции
  STEP git_workflow
    @log("step.git_workflow")
    input:
      code: str
      task: Task
    output:
      pr_id: str
    
    TOOL call git_create_branch
      input: "feature/#{task.id}"
      output: branch
    
    TOOL call git_commit
      input: "Implement: #{task.title}"
      output: commit
    
    TOOL call create_pull_request
      input: {
        title: "Implement: #{task.title}",
        description: task.description
      }
      output: pr

  // Шаг 8: Документирование
  STEP update_documentation
    @log("step.update_documentation")
    input:
      code: str
      task: Task
    output:
      docs_updated: bool
    
    TOOL call generate_api_docs
      input: directory
      output: docs

  // Финальный шаг: Результаты
  STEP finalize
    output:
      result: TaskResult {
        status: "SUCCESS",
        code_files: files_to_create,
        test_files: [test_code],
        pr_id: pr_id,
        code_quality: {
          coverage: suite.coverage,
          issues_found: issues.length,
          vulnerabilities: vulnerabilities.length
        }
      }
```

**Файл**: `scenes/fix_bug.vibee`

```vibee
SCENE fix_bug
  @log("scenes.fix_bug")
  @spec "Bug fixed": bug_reproduced() -> fix_applied() -> tests_passing() -> result == SUCCESS

  // Шаг 1: Получить информацию о баге
  STEP analyze_bug
    input:
      bug_id: str
      bug_description: str
    output:
      bug_analysis: BugAnalysis

  // Шаг 2: Найти причину
  STEP locate_bug
    input:
      codebase: str
      bug_analysis: BugAnalysis
    output:
      affected_files: List(str)
      root_cause: str

  // Шаг 3: Написать воспроизводящий тест
  STEP create_repro_test
    input:
      bug_analysis: BugAnalysis
    output:
      test_code: str

  // Шаг 4: Применить исправление
  STEP apply_fix
    input:
      affected_files: List(str)
      root_cause: str
    output:
      fixed_code: str

  // Шаг 5: Запустить тесты
  STEP verify_fix
    input:
      directory: str
    output:
      test_result: TestSuite

  // Шаг 6: Регрессионное тестирование
  STEP regression_tests
    input:
      directory: str
    output:
      regression_result: TestSuite

  // Шаг 7: Создать PR с исправлением
  STEP create_fix_pr
    input:
      fixed_code: str
      bug_id: str
    output:
      pr_id: str
```

**Файл**: `scenes/code_review.vibee`

```vibee
SCENE code_review
  @log("scenes.code_review")
  @spec "Code reviewed": pr_found() -> automated_checks() -> recommendation() -> result == SUCCESS

  // Шаг 1: Получить PR
  STEP fetch_pr
    input:
      pr_id: str
    output:
      pr: PullRequest
      diff: List(GitDiff)

  // Шаг 2: Анализ кода
  STEP analyze_code_changes
    input:
      diff: List(GitDiff)
    output:
      code_smells: List(CodeSmell)
      complexity_metrics: ComplexityMetrics

  // Шаг 3: Проверка типов и стиля
  STEP check_code_quality
    input:
      files: List(str)
    output:
      issues: List(Issue)
      style_violations: List(Violation)

  // Шаг 4: Безопасность
  STEP security_review
    input:
      files: List(str)
    output:
      vulnerabilities: List(SecurityVulnerability)

  // Шаг 5: Тесты
  STEP test_coverage_review
    input:
      pr_id: str
    output:
      coverage_report: CoverageReport

  // Шаг 6: Документация
  STEP docs_review
    input:
      diff: List(GitDiff)
    output:
      missing_docs: List(str)
      doc_quality: int

  // Шаг 7: Генерация отчета
  STEP generate_review_report
    input:
      all_findings: ReviewFindings
    output:
      review: CodeReview
      recommendation: str  // APPROVE, REQUEST_CHANGES, COMMENT
```

---

## 📊 Фаза 7: Оркестратор и управление состоянием

**Файл**: `orchestrator.vibee`

```vibee
@module_defaults(
  log: "orchestrator",
  auth_required: true
)

TYPE TaskState {
  id: str
  status: TaskStatus  // PENDING, RUNNING, PAUSED, SUCCESS, FAILED, CANCELLED
  created_at: str
  started_at: str?
  completed_at: str?
  current_step: str?
  progress: float  // 0.0 - 1.0
  error: str?
  results: TaskResult?
  metadata: Map(str, str)
}

// Запуск задачи с оркестратором
TOOL execute_task_with_orchestration
  @spec: Task -> TaskState
  description: "Запускает задачу с полным оркестратором"
  
  input:
    task: Task! @body
  
  output:
    state: TaskState @json

// Получить состояние задачи
TOOL get_task_state
  @spec: str -> TaskState
  description: "Получает текущее состояние задачи"
  
  input:
    task_id: str! @query
  
  output:
    state: TaskState @json

// Отследить прогресс
TOOL track_progress
  @spec: str -> ProgressEvent
  description: "Отслеживает прогресс выполнения"
  
  input:
    task_id: str! @query
  
  output:
    event: ProgressEvent @json @stream

// Обработка ошибок и retry
TOOL handle_task_error
  @spec: (str, str) -> TaskState
  description: "Обрабатывает ошибку и пытается повторить"
  
  input:
    task_id: str! @body
    error: str! @body
  
  output:
    state: TaskState @json

// Откат при ошибке
TOOL rollback_task
  @spec: str -> TaskState
  description: "Откатывает изменения при ошибке"
  
  input:
    task_id: str! @body
  
  output:
    state: TaskState @json
```

---

## 🎯 Фаза 8: Интеграция с LLM

### 8.1 LLM Integration

**Файл**: `llm_integration.vibee`

```vibee
@module_defaults(
  log: "llm_integration"
)

TYPE LLMModel {
  name: str
  provider: str  // openai, anthropic, google, local
  context_size: int
  cost_per_token: float?
  speed: str  // fast, medium, slow
}

TYPE LLMRequest {
  prompt: str
  context: str?
  model: LLMModel
  temperature: float? = 0.7
  max_tokens: int? = 4000
}

// Tool: Запрос к LLM для анализа
TOOL llm_analyze_code
  @spec: str -> str
  description: "Анализирует код с помощью LLM"
  
  input:
    code: str! @body
    question: str! @body
  
  output:
    analysis: str @text

// Tool: Генерация кода через LLM
TOOL llm_generate_code
  @spec: str -> str
  description: "Генерирует код через LLM"
  
  input:
    prompt: str! @body
    context: str? @body
    language: str? @body = "gleam"
  
  output:
    code: str @text

// Tool: Выбор оптимальной стратегии
TOOL llm_choose_strategy
  @spec: Task -> str
  description: "LLM выбирает оптимальную стратегию решения"
  
  input:
    task: Task! @body
  
  output:
    strategy: str @text
```

---

## 🔄 Интеграционные сценарии

### Пример 1: Полный workflow реализации фичи

```
1. Пользователь запрашивает: "Добавить API эндпоинт для получения статистики"
2. Task Parser преобразует в структурированный Task
3. Orchestrator запускает scene: implement_feature
4. Code Intelligence анализирует существующий API
5. LLM генерирует код нового эндпоинта
6. QA Tools: генерируют и запускают тесты
7. VCS Tools: создают ветку, коммитят, создают PR
8. Documentation: обновляет API docs
9. Deployment: опционально деплоит на dev
10. Результат: PR готов для review
```

### Пример 2: Автоматическое исправление bagов

```
1. Получен bug report с лог-ом ошибки
2. Task Parser преобразует в structured Task
3. Code Intelligence находит место ошибки
4. LLM анализирует root cause
5. Scene fix_bug: создает воспроизводящий тест
6. Применяет исправление
7. QA: запускает тесты + регрессию
8. VCS: создает PR с исправлением
9. Результат: PR готов для быстрого merge
```

### Пример 3: Code Review с AI

```
1. PR создан разработчиком
2. Webhooks запускают scene: code_review
3. Analyze: комплексный анализ изменений
4. Quality Checks: типы, стиль, безопасность
5. LLM: дает рекомендации по улучшению
6. Documentation: проверяет наличие docs
7. Coverage: анализирует тесты
8. Результат: автоматический комментарий в PR с рекомендациями
```

---

## 📋 План реализации по фазам

### ✅ Фаза 1: Базовая инфраструктура (Неделя 1)
- [ ] Создать структуру файлов `.vibee`
- [ ] Реализовать Task Parser
- [ ] Реализовать Orchestrator базовый
- [ ] Тесты для парсера

### ⏳ Фаза 2: Code Intelligence (Неделя 2)
- [ ] Code Analysis Tools
- [ ] LLM Integration базовая
- [ ] Тесты анализа

### ⏳ Фаза 3: QA Tools (Неделя 3)
- [ ] Test Generation
- [ ] Coverage Analysis
- [ ] Security Scanning

### ⏳ Фаза 4: VCS & Deployment (Неделя 4)
- [ ] Git Tools
- [ ] Fly.io Deployment
- [ ] Health Checks

### ⏳ Фаза 5: Scenes (Неделя 5)
- [ ] implement_feature scene
- [ ] fix_bug scene
- [ ] code_review scene

### ⏳ Фаза 6: Интеграция (Неделя 6)
- [ ] Полная интеграция всех компонентов
- [ ] E2E тестирование
- [ ] Оптимизация производительности

### ⏳ Фаза 7: Документация & Деплой (Неделя 7)
- [ ] Полная документация
- [ ] Примеры использования
- [ ] Деплой на production

---

## 🎓 Ключевые особенности реализации

### 1. **Dogfooding на VIBEE DSL**
- Весь SWE Agent код пишется на .vibee
- Это доказывает что язык готов для production
- Находим улучшения языка через реальное использование

### 2. **Модульная архитектура**
- Каждый модуль независим
- Tools можно использовать отдельно
- Легко расширять и модифицировать

### 3. **Полное покрытие @spec**
- Каждый tool имеет @spec блок
- Каждая сцена имеет @spec блок
- Спецификации помогают LLM лучше понимать

### 4. **Гибридное LLM управление**
- Локальные модели (быстро, бесплатно)
- Fallback на free API (gemini-2.0-flash-exp)
- Опция платных моделей для сложных задач

### 5. **Оркестрация с состояниями**
- Tracking прогресса
- Graceful error handling
- Automatic retry logic
- Rollback на ошибки

### 6. **Integration с существующими инструментами**
- Git/GitHub API
- Fly.io API
- Telegram MTProto
- PostgreSQL for persistence

---

## 💾 Хранение данных

### PostgreSQL Schema

```sql
-- Таблица задач
CREATE TABLE swe_tasks (
  id UUID PRIMARY KEY,
  user_id BIGINT NOT NULL,
  title VARCHAR NOT NULL,
  description TEXT NOT NULL,
  status VARCHAR NOT NULL,
  priority VARCHAR NOT NULL,
  complexity VARCHAR NOT NULL,
  created_at TIMESTAMP NOT NULL,
  started_at TIMESTAMP,
  completed_at TIMESTAMP,
  estimated_hours INT,
  actual_hours INT,
  repository_url VARCHAR,
  branch VARCHAR,
  pr_id VARCHAR,
  results JSONB,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Таблица шагов выполнения
CREATE TABLE swe_task_steps (
  id UUID PRIMARY KEY,
  task_id UUID NOT NULL,
  step_name VARCHAR NOT NULL,
  status VARCHAR NOT NULL,
  started_at TIMESTAMP,
  completed_at TIMESTAMP,
  output JSONB,
  error_message TEXT,
  FOREIGN KEY (task_id) REFERENCES swe_tasks(id)
);

-- Таблица логов
CREATE TABLE swe_task_logs (
  id UUID PRIMARY KEY,
  task_id UUID NOT NULL,
  timestamp TIMESTAMP NOT NULL,
  level VARCHAR NOT NULL,
  message TEXT NOT NULL,
  context JSONB,
  FOREIGN KEY (task_id) REFERENCES swe_tasks(id)
);

-- Таблица успешных решений (Knowledge Base)
CREATE TABLE swe_solutions (
  id UUID PRIMARY KEY,
  task_pattern VARCHAR NOT NULL,
  solution TEXT NOT NULL,
  effectiveness_score FLOAT,
  used_count INT DEFAULT 0,
  created_at TIMESTAMP NOT NULL
);
```

---

## 🧪 Тестирование

### Unit Tests

```gleam
// tests/swe_agent_test.gleam
import gleam/list
import swe_agent/task_parser

pub fn test_parse_simple_task() {
  let description = "Add API endpoint for user statistics"
  
  let task = task_parser.parse(description)
  
  assert task.title == "Add API endpoint for user statistics"
  assert task.priority == High
  assert list.length(task.subtasks) > 0
}

pub fn test_decompose_complex_task() {
  let task = Task(
    title: "Implement authentication system",
    complexity: Complex,
    ..
  )
  
  let subtasks = orchestrator.decompose_task(task)
  
  assert list.length(subtasks) >= 5
  assert subtasks
    |> list.every(fn(t) { t.complexity != Complex })
}
```

### Integration Tests

```bash
# Запуск полного workflow
vibee test --scene implement_feature --sample-task

# Проверка end-to-end
vibee test --e2e
```

---

## 🚀 Метрики успеха

| Метрика | Целевое значение |
|---------|-----------------|
| Успешных таск автоматизировано | >70% |
| Время на реализацию фичи | -60% |
| Покрытие тестами | >85% |
| Среднее время на bug fix | <30 мин |
| PR approval rate (auto) | >80% |
| Успешные деплои | 100% |

---

## 📞 Точки интеграции

### Telegram Bot
- Команда `/code` запускает SWE Agent
- `/code task "Описание"` - запустить задачу
- `/code status {task_id}` - статус
- `/code results {task_id}` - результаты

### MCP Protocol
- Tool `swe_execute_task` - запустить
- Tool `swe_get_status` - статус
- Tool `swe_get_results` - результаты
- Tool `swe_list_tasks` - список задач

### HTTP API
- POST `/api/v1/swe/task` - новая задача
- GET `/api/v1/swe/task/:id` - статус
- GET `/api/v1/swe/task/:id/results` - результаты
- WebSocket `/api/v1/swe/task/:id/stream` - live updates

---

## 🔐 Безопасность

### Правила
- [ ] Все операции git/ssh через авторизованные ключи
- [ ] Коды не попадают в логи (маскировка)
- [ ] Доступ только к разрешенным репозиториям
- [ ] API ключи только в Fly.io secrets
- [ ] RBAC: admin, developer, reviewer roles
- [ ] Audit логи всех операций
- [ ] SAST scanning перед коммитом

---

## 📚 Документация для пользователей

### Getting Started Guide
```markdown
# SWE Agent on VIBEE - Getting Started

## Installation
...

## Quick Start
...

## Use Cases
1. Автоматическая реализация фич
2. Быстрое исправление bagов
3. Автоматический code review
4. Генерация документации
...

## Advanced Usage
...
```

---

## ⚡ Следующие шаги

1. **Создать базовую структуру файлов** и начать с Task Parser
2. **Реализовать Orchestrator** для управления состоянием
3. **Интегрировать с LLM** (начать с free models)
4. **Написать первую сцену** (implement_feature)
5. **Протестировать** на реальных задачах
6. **Итеративно улучшать** на основе результатов

---

## 📞 Ресурсы

- VIBEE DSL документация: `/docs/VIBEE_DSL.md`
- MCP Protocol: `/docs/MCP_PROTOCOL.md`
- Gleam документация: https://gleam.run
- BEAM best practices: https://learnyousomeerlang.com

---

**Автор**: SWE Agent Planning
**Дата**: 2026-01-04
**Версия**: 1.0
**Статус**: 📋 In Planning

