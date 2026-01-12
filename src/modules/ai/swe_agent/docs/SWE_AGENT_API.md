# 🌐 SWE Agent API - Справочник запросов

## 📚 Содержание

1. [Основные endpoints](#основные-endpoints)
2. [Создание задачи](#создание-задачи)
3. [Получение статуса](#получение-статуса)
4. [Потоковые обновления](#потоковые-обновления)
5. [Примеры реальных запросов](#примеры-реальных-запросов)
6. [Обработка ошибок](#обработка-ошибок)

---

## 📍 Основные endpoints

| Метод | Путь | Описание |
|-------|------|---------|
| `POST` | `/api/v1/swe/task` | Создать новую задачу |
| `GET` | `/api/v1/swe/task/:id` | Получить статус задачи |
| `GET` | `/api/v1/swe/task/:id/results` | Получить результаты |
| `GET` | `/api/v1/swe/task/:id/logs` | История логов |
| `WS` | `/api/v1/swe/task/:id/stream` | WebSocket для live обновлений |
| `DELETE` | `/api/v1/swe/task/:id` | Отменить задачу |
| `POST` | `/api/v1/swe/task/:id/approve` | Одобрить результаты |

---

## ✨ Создание задачи

### Запрос

```bash
curl -X POST http://localhost:4000/api/v1/swe/task \
  -H "Content-Type: application/json" \
  -d '{
    "task": "Add pagination to the /api/users endpoint",
    "description": "Users should be able to paginate through users list. Use limit=10, offset=0 as defaults",
    "repository": "https://github.com/user/myapp",
    "branch": "main",
    "scenario": "implement_feature"
  }'
```

### Структура запроса

```typescript
interface CreateTaskRequest {
  task: string;                    // Короткое описание (1 строка)
  description?: string;            // Подробное описание (несколько строк)
  repository: string;              // URL репозитория (https://...)
  branch?: string;                 // Целевая ветка (default: main)
  scenario: "implement_feature" |   // Тип задачи
            "fix_bug" |
            "code_review";
  
  // Опциональные параметры
  priority?: "low" | "medium" | "high";
  complexity?: "simple" | "moderate" | "complex";
  labels?: string[];               // GitHub labels
  milestone?: string;              // GitHub milestone
  assignees?: string[];            // GitHub assignees
  
  // Конфигурация поведения
  auto_merge?: boolean;            // Auto-merge PR после approval
  run_tests?: boolean;             // Запустить тесты (default: true)
  create_pr?: boolean;             // Создать PR (default: true)
  update_docs?: boolean;           // Обновить документацию
  
  // LLM конфигурация
  llm_model?: string;              // Модель (default: gemini-2.0-flash-exp)
  temperature?: number;            // 0.0-1.0 (default: 0.7)
  max_tokens?: number;             // Max output (default: 4000)
}
```

### Ответ 200 OK

```json
{
  "task_id": "task_e7a3f942",
  "status": "pending",
  "created_at": "2026-01-04T10:30:45.123Z",
  "estimated_duration": 720,
  "links": {
    "self": "http://localhost:4000/api/v1/swe/task/task_e7a3f942",
    "results": "http://localhost:4000/api/v1/swe/task/task_e7a3f942/results",
    "stream": "ws://localhost:4000/api/v1/swe/task/task_e7a3f942/stream"
  }
}
```

---

## 📊 Получение статуса

### Запрос

```bash
curl http://localhost:4000/api/v1/swe/task/task_e7a3f942 \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Ответ 200 OK

```json
{
  "task_id": "task_e7a3f942",
  "task": "Add pagination to the /api/users endpoint",
  "status": "in_progress",
  "progress": {
    "current_step": 4,
    "total_steps": 10,
    "percentage": 40
  },
  "current_phase": "generate_code",
  "phases": {
    "parse_task": {
      "status": "completed",
      "started_at": "2026-01-04T10:30:45Z",
      "completed_at": "2026-01-04T10:31:15Z",
      "duration_ms": 30000
    },
    "analyze_codebase": {
      "status": "completed",
      "started_at": "2026-01-04T10:31:15Z",
      "completed_at": "2026-01-04T10:32:45Z",
      "duration_ms": 90000
    },
    "generate_plan": {
      "status": "completed",
      "started_at": "2026-01-04T10:32:45Z",
      "completed_at": "2026-01-04T10:34:00Z",
      "duration_ms": 75000
    },
    "generate_code": {
      "status": "in_progress",
      "started_at": "2026-01-04T10:34:00Z",
      "progress": 45
    }
  },
  "metrics": {
    "llm_calls": 3,
    "tool_executions": 15,
    "cache_hits": 8,
    "tokens_used": {
      "input": 45230,
      "output": 12450
    }
  },
  "estimated_completion": "2026-01-04T10:42:15Z",
  "can_cancel": true
}
```

---

## 🎬 Потоковые обновления

### WebSocket подключение

```javascript
const ws = new WebSocket('ws://localhost:4000/api/v1/swe/task/task_e7a3f942/stream');

ws.onopen = () => {
  console.log('Connected to task stream');
};

ws.onmessage = (event) => {
  const update = JSON.parse(event.data);
  console.log('Update:', update);
};

ws.onerror = (error) => {
  console.error('Stream error:', error);
};

ws.onclose = () => {
  console.log('Stream closed');
};
```

### Примеры сообщений

#### Сообщение: Phase started

```json
{
  "type": "phase_started",
  "phase": "generate_code",
  "timestamp": "2026-01-04T10:34:00.000Z",
  "message": "Starting code generation phase..."
}
```

#### Сообщение: Tool execution

```json
{
  "type": "tool_execution",
  "tool": "swe_write",
  "input": {
    "path": "src/api/pagination.gleam",
    "content": "pub fn paginate(...) {"
  },
  "timestamp": "2026-01-04T10:34:15.000Z",
  "duration_ms": 245
}
```

#### Сообщение: Test result

```json
{
  "type": "test_result",
  "test_file": "test/api/users_test.gleam",
  "passed": 15,
  "failed": 0,
  "skipped": 2,
  "duration_ms": 3400,
  "coverage": 87,
  "timestamp": "2026-01-04T10:37:30.000Z"
}
```

#### Сообщение: PR created

```json
{
  "type": "pr_created",
  "pr_number": 42,
  "pr_url": "https://github.com/user/myapp/pull/42",
  "title": "feat: add pagination to /api/users endpoint",
  "timestamp": "2026-01-04T10:39:00.000Z"
}
```

#### Сообщение: Task completed

```json
{
  "type": "task_completed",
  "status": "success",
  "summary": "✅ Task completed successfully",
  "results": {
    "files_modified": 3,
    "tests_written": 15,
    "tests_passed": 15,
    "test_coverage": 87,
    "pr_created": true,
    "pr_number": 42
  },
  "timestamp": "2026-01-04T10:42:15.000Z"
}
```

---

## 📝 Примеры реальных запросов

### Пример 1: Добавить фичу в TypeScript API

```bash
curl -X POST http://localhost:4000/api/v1/swe/task \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "task": "Add user authentication with JWT",
    "description": "Implement JWT-based authentication for the REST API. Should include:\n1. Login endpoint\n2. Token refresh mechanism\n3. Protected routes\n4. Token validation middleware",
    "repository": "https://github.com/acme/api-server",
    "branch": "main",
    "scenario": "implement_feature",
    "priority": "high",
    "complexity": "moderate",
    "labels": ["authentication", "security", "backend"],
    "run_tests": true,
    "create_pr": true
  }'
```

### Пример 2: Исправить баг в Gleam

```bash
curl -X POST http://localhost:4000/api/v1/swe/task \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "task": "Fix memory leak in WebSocket handler",
    "description": "Memory usage grows unbounded when WebSocket connections are not properly cleaned up. Issue #143.",
    "repository": "https://github.com/acme/gleam-websocket",
    "branch": "develop",
    "scenario": "fix_bug",
    "priority": "critical",
    "complexity": "complex",
    "llm_model": "claude-3-sonnet"
  }'
```

### Пример 3: Code review

```bash
curl -X POST http://localhost:4000/api/v1/swe/task \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "task": "Review PR #35: Add database migration system",
    "description": "Please review the database migration PR and provide feedback on:\n- Code quality\n- Performance implications\n- Security considerations\n- Test coverage",
    "repository": "https://github.com/acme/db-service",
    "branch": "main",
    "scenario": "code_review"
  }'
```

---

## 🎯 Получение результатов

### Запрос

```bash
curl http://localhost:4000/api/v1/swe/task/task_e7a3f942/results \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Ответ 200 OK

```json
{
  "task_id": "task_e7a3f942",
  "task": "Add pagination to the /api/users endpoint",
  "scenario": "implement_feature",
  "status": "completed",
  "result": "success",
  "summary": "✅ Successfully implemented pagination for /api/users endpoint",
  "completed_at": "2026-01-04T10:42:15.123Z",
  "total_duration_ms": 720000,
  
  "implementation": {
    "files_modified": 3,
    "files_created": 1,
    "files": [
      {
        "path": "src/api/pagination.gleam",
        "status": "created",
        "changes": 127
      },
      {
        "path": "src/api/users.gleam",
        "status": "modified",
        "changes": 42
      },
      {
        "path": "src/types.gleam",
        "status": "modified",
        "changes": 18
      }
    ]
  },
  
  "testing": {
    "tests_written": 15,
    "tests_passed": 15,
    "tests_failed": 0,
    "test_coverage": 87,
    "test_file": "test/api/pagination_test.gleam"
  },
  
  "quality": {
    "type_checking": "✅ passed",
    "code_smells": 0,
    "security_issues": 0,
    "style_warnings": 2,
    "style_warning_details": [
      "Function 'paginate' exceeds 50 lines (now 52)",
      "Parameter 'limit' should have range documentation"
    ]
  },
  
  "vcs": {
    "branch_created": "feature/pagination",
    "commits": [
      {
        "hash": "a3f7b2c",
        "message": "feat: implement pagination struct and helpers",
        "files_changed": 2
      },
      {
        "hash": "b8e4c1d",
        "message": "feat: add pagination handlers to /api/users",
        "files_changed": 1
      },
      {
        "hash": "c9f5d2e",
        "message": "test: comprehensive pagination tests",
        "files_changed": 1
      }
    ],
    "pr_created": true,
    "pr_number": 42,
    "pr_url": "https://github.com/user/myapp/pull/42",
    "pr_status": "ready_for_review"
  },
  
  "documentation": {
    "api_docs_updated": true,
    "readme_updated": true,
    "examples_added": true,
    "changelog_updated": true
  },
  
  "metrics": {
    "total_llm_calls": 8,
    "total_tool_executions": 47,
    "cache_hit_rate": 0.72,
    "tokens_used": {
      "input": 45230,
      "output": 12450,
      "total": 57680
    },
    "estimated_cost": 0.42
  },
  
  "next_steps": [
    "Review the PR at https://github.com/user/myapp/pull/42",
    "Approve and merge when ready",
    "Deploy to staging for testing",
    "Merge to main after staging approval"
  ]
}
```

---

## 🗂️ Получение логов

### Запрос

```bash
curl 'http://localhost:4000/api/v1/swe/task/task_e7a3f942/logs?limit=50&offset=0' \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Ответ 200 OK

```json
{
  "task_id": "task_e7a3f942",
  "logs": [
    {
      "timestamp": "2026-01-04T10:30:45.000Z",
      "level": "INFO",
      "component": "orchestrator",
      "message": "Task created and started"
    },
    {
      "timestamp": "2026-01-04T10:30:50.000Z",
      "level": "INFO",
      "component": "task_parser",
      "message": "Task parsed successfully",
      "data": {
        "title": "Add pagination",
        "priority": "MEDIUM",
        "complexity": "MODERATE",
        "estimated_effort_hours": 2
      }
    },
    {
      "timestamp": "2026-01-04T10:31:45.000Z",
      "level": "INFO",
      "component": "code_intelligence",
      "message": "Codebase analyzed",
      "data": {
        "files_scanned": 234,
        "language": "gleam",
        "key_modules": ["api", "types", "handlers"]
      }
    },
    {
      "timestamp": "2026-01-04T10:34:00.000Z",
      "level": "INFO",
      "component": "llm_integration",
      "message": "LLM call successful",
      "data": {
        "model": "gemini-2.0-flash-exp",
        "input_tokens": 5230,
        "output_tokens": 1450,
        "duration_ms": 2400
      }
    },
    {
      "timestamp": "2026-01-04T10:34:20.000Z",
      "level": "INFO",
      "component": "code_generation",
      "message": "Code files generated",
      "data": {
        "files": ["src/api/pagination.gleam"],
        "total_lines": 127
      }
    },
    {
      "timestamp": "2026-01-04T10:37:30.000Z",
      "level": "INFO",
      "component": "quality_assurance",
      "message": "Tests executed",
      "data": {
        "tests_passed": 15,
        "coverage": 87
      }
    },
    {
      "timestamp": "2026-01-04T10:39:00.000Z",
      "level": "INFO",
      "component": "vcs_tools",
      "message": "PR created",
      "data": {
        "pr_number": 42,
        "url": "https://github.com/user/myapp/pull/42"
      }
    },
    {
      "timestamp": "2026-01-04T10:42:15.000Z",
      "level": "INFO",
      "component": "orchestrator",
      "message": "Task completed",
      "data": {
        "result": "success",
        "duration_minutes": 12
      }
    }
  ],
  "total": 8,
  "has_more": false
}
```

---

## ❌ Обработка ошибок

### Ошибка: Invalid repository

**Статус**: 400 Bad Request

```json
{
  "error": {
    "code": "INVALID_REPOSITORY",
    "message": "Repository URL is invalid or not accessible",
    "details": {
      "url": "invalid-url",
      "reason": "URL must start with https://"
    }
  }
}
```

### Ошибка: Repository not found

**Статус**: 404 Not Found

```json
{
  "error": {
    "code": "REPOSITORY_NOT_FOUND",
    "message": "Repository could not be cloned",
    "details": {
      "repository": "https://github.com/nonexistent/repo",
      "reason": "404 Not Found"
    }
  }
}
```

### Ошибка: Task not found

**Статус**: 404 Not Found

```json
{
  "error": {
    "code": "TASK_NOT_FOUND",
    "message": "Task with ID 'task_invalid' does not exist",
    "details": {
      "task_id": "task_invalid"
    }
  }
}
```

### Ошибка: Task cancelled

**Статус**: 200 OK (но status = cancelled)

```json
{
  "task_id": "task_e7a3f942",
  "status": "cancelled",
  "result": "cancelled_by_user",
  "cancelled_at": "2026-01-04T10:35:00.000Z",
  "message": "Task was cancelled by user",
  "partial_results": {
    "completed_phases": ["parse_task", "analyze_codebase"],
    "files_modified": 0
  }
}
```

### Ошибка: LLM API failure

**Статус**: 503 Service Unavailable

```json
{
  "error": {
    "code": "LLM_API_ERROR",
    "message": "Failed to call LLM after 3 retries",
    "details": {
      "llm_provider": "openrouter",
      "model": "gemini-2.0-flash-exp",
      "last_error": "503 Service Unavailable",
      "retry_count": 3
    }
  }
}
```

---

## 🔐 Аутентификация

### Bearer Token

```bash
curl http://localhost:4000/api/v1/swe/task \
  -H "Authorization: Bearer YOUR_LONG_TOKEN_HERE"
```

### Получение токена

```bash
# Через админ панель
https://localhost:4000/admin/api-tokens

# Или через CLI (если доступно)
vibee-cli auth:token --user john@example.com --expires 30d
```

---

## 💡 Полезные примеры

### JavaScript/Node.js

```javascript
const axios = require('axios');

async function createAndMonitorTask(taskDescription) {
  try {
    // 1. Создать задачу
    const createResponse = await axios.post(
      'http://localhost:4000/api/v1/swe/task',
      {
        task: taskDescription,
        repository: 'https://github.com/user/myapp',
        scenario: 'implement_feature'
      },
      {
        headers: {
          'Authorization': `Bearer ${process.env.SWE_AGENT_TOKEN}`
        }
      }
    );

    const taskId = createResponse.data.task_id;
    console.log(`Task created: ${taskId}`);

    // 2. Подписаться на обновления через WebSocket
    const ws = new WebSocket(
      `ws://localhost:4000/api/v1/swe/task/${taskId}/stream`
    );

    ws.onmessage = (event) => {
      const update = JSON.parse(event.data);
      console.log(`[${update.type}] ${update.message}`);
    };

    // 3. Дождаться завершения
    await new Promise((resolve) => {
      ws.onmessage = (event) => {
        const update = JSON.parse(event.data);
        if (update.type === 'task_completed') {
          resolve(update);
        }
      };
    });

    // 4. Получить результаты
    const resultsResponse = await axios.get(
      `http://localhost:4000/api/v1/swe/task/${taskId}/results`,
      {
        headers: {
          'Authorization': `Bearer ${process.env.SWE_AGENT_TOKEN}`
        }
      }
    );

    return resultsResponse.data;
  } catch (error) {
    console.error('Error:', error.response?.data || error.message);
  }
}

// Использование
createAndMonitorTask('Add caching to API endpoints').then(results => {
  console.log('Results:', results);
});
```

### Python

```python
import requests
import json

class SWEAgentClient:
    def __init__(self, base_url, token):
        self.base_url = base_url
        self.headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        }
    
    def create_task(self, task_desc, repo_url, scenario='implement_feature'):
        """Create a new SWE Agent task"""
        response = requests.post(
            f'{self.base_url}/api/v1/swe/task',
            headers=self.headers,
            json={
                'task': task_desc,
                'repository': repo_url,
                'scenario': scenario
            }
        )
        return response.json()
    
    def get_task_status(self, task_id):
        """Get current task status"""
        response = requests.get(
            f'{self.base_url}/api/v1/swe/task/{task_id}',
            headers=self.headers
        )
        return response.json()
    
    def get_results(self, task_id):
        """Get task results"""
        response = requests.get(
            f'{self.base_url}/api/v1/swe/task/{task_id}/results',
            headers=self.headers
        )
        return response.json()
    
    def stream_logs(self, task_id):
        """Stream task logs"""
        response = requests.get(
            f'{self.base_url}/api/v1/swe/task/{task_id}/logs',
            headers=self.headers,
            stream=True
        )
        for line in response.iter_lines():
            if line:
                yield json.loads(line)

# Использование
client = SWEAgentClient('http://localhost:4000', 'YOUR_TOKEN')

# Создать задачу
task = client.create_task(
    'Add error handling to API',
    'https://github.com/user/myapp'
)
print(f"Task ID: {task['task_id']}")

# Получить статус
status = client.get_task_status(task['task_id'])
print(f"Status: {status['status']}")

# Получить результаты
results = client.get_results(task['task_id'])
print(f"PR Created: {results['vcs']['pr_url']}")
```

---

**Создано**: 4 января 2026
**Версия**: 1.0
**Статус**: ✅ Production Ready

