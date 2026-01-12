# 🤖 Real SWE Agent Best Practices

## Исследование Лучших Агентов (2024-2026)

### 1. Devin (Cognition AI)

**Что делает:**
- ✅ Создаёт реальные проекты с нуля
- ✅ Пишет код в файлы
- ✅ Запускает команды в терминале
- ✅ Читает документацию
- ✅ Дебажит ошибки
- ✅ Делает git commits
- ✅ Создаёт Pull Requests

**Режимы работы:**
1. **Project Mode** - создаёт новый проект
2. **Task Mode** - выполняет конкретную задачу
3. **Debug Mode** - исправляет баги
4. **Review Mode** - ревьюит код

**Workflow:**
```
User: "Create a REST API for todo app"
↓
Devin:
1. Creates project structure
2. Writes backend code (Express.js)
3. Writes tests
4. Runs tests
5. Creates README
6. Git commit & push
7. Shows working demo
```

### 2. Cursor (Anysphere)

**Что делает:**
- ✅ Редактирует существующие файлы
- ✅ Создаёт новые файлы
- ✅ Применяет изменения напрямую
- ✅ Показывает diff перед применением
- ✅ Работает с multi-file context
- ✅ Интегрирован в VS Code

**Режимы работы:**
1. **Chat Mode** - обсуждение
2. **Composer Mode** - создание файлов
3. **Inline Edit** - редактирование на месте
4. **Terminal Mode** - выполнение команд

**Workflow:**
```
User: "Add authentication to this API"
↓
Cursor:
1. Analyzes existing code
2. Shows plan with file changes
3. Creates auth.ts
4. Modifies server.ts
5. Updates package.json
6. Shows diff
7. User approves
8. Applies changes
```

### 3. Aider (Paul Gauthier)

**Что делает:**
- ✅ Работает через CLI
- ✅ Редактирует файлы напрямую
- ✅ Делает git commits автоматически
- ✅ Работает с любым редактором
- ✅ Поддерживает разные LLM
- ✅ Показывает diff перед изменениями

**Режимы работы:**
1. **Whole Mode** - переписывает весь файл
2. **Diff Mode** - показывает только изменения
3. **Ask Mode** - только отвечает, не меняет код
4. **Architect Mode** - планирует изменения

**Workflow:**
```bash
$ aider src/app.py

User: "Add error handling"
↓
Aider:
1. Reads src/app.py
2. Generates changes
3. Shows diff:
   + try:
   +     result = process()
   + except Exception as e:
   +     logger.error(e)
4. Applies changes
5. Git commit "Add error handling"
```

### 4. GitHub Copilot Workspace

**Что делает:**
- ✅ Создаёт план изменений
- ✅ Редактирует multiple files
- ✅ Запускает тесты
- ✅ Создаёт PR
- ✅ Интегрирован с GitHub

**Режимы работы:**
1. **Plan Mode** - создаёт план
2. **Implement Mode** - реализует план
3. **Test Mode** - тестирует изменения
4. **Review Mode** - создаёт PR

### 5. Sweep AI

**Что делает:**
- ✅ Работает через GitHub Issues
- ✅ Создаёт PR автоматически
- ✅ Исправляет баги
- ✅ Добавляет фичи
- ✅ Пишет тесты

**Workflow:**
```
GitHub Issue: "Add user authentication"
↓
Sweep:
1. Analyzes codebase
2. Creates branch
3. Writes code
4. Writes tests
5. Creates PR
6. Responds to review comments
```

---

## Ключевые Паттерны

### 1. Режимы Работы

**Chat Mode** (пассивный)
- Только отвечает на вопросы
- Не меняет код
- Даёт советы

**Agent Mode** (активный)
- Создаёт файлы
- Меняет код
- Запускает команды
- Делает commits

**Architect Mode** (планирование)
- Создаёт план
- Показывает структуру
- Не пишет код сразу

### 2. Workflow Паттерны

**Pattern 1: Plan → Implement → Test**
```
1. User request
2. Agent creates plan
3. User approves plan
4. Agent implements
5. Agent runs tests
6. Agent shows results
```

**Pattern 2: Iterative Development**
```
1. Create basic structure
2. Show to user
3. User gives feedback
4. Agent improves
5. Repeat until done
```

**Pattern 3: Autonomous Execution**
```
1. User gives high-level goal
2. Agent breaks into tasks
3. Agent executes all tasks
4. Agent shows final result
```

### 3. File Operations

**Create File:**
```typescript
interface CreateFileOperation {
  path: string;
  content: string;
  mode?: 'create' | 'overwrite';
}
```

**Modify File:**
```typescript
interface ModifyFileOperation {
  path: string;
  changes: Array<{
    type: 'insert' | 'delete' | 'replace';
    line: number;
    content: string;
  }>;
}
```

**Apply Changes:**
```typescript
interface ApplyChanges {
  files: FileOperation[];
  preview: boolean;  // Show diff first
  autoCommit: boolean;
  commitMessage?: string;
}
```

### 4. Safety Mechanisms

**Preview Before Apply:**
```
Agent: "I will make these changes:"
  
  src/app.ts:
  + import { auth } from './auth'
  + app.use(auth.middleware)
  
  src/auth.ts:
  + export const auth = { ... }

User: [Approve] [Reject] [Modify]
```

**Undo Support:**
```
Agent: "Changes applied. Type 'undo' to revert."
User: "undo"
Agent: "Reverted changes."
```

**Sandbox Mode:**
```
Agent: "Running in sandbox mode. Changes won't affect real files."
```

---

## Что Должен Уметь VIBEE SWE Agent

### Must Have (Критично)

1. **Project Creation**
   ```
   User: "Create todo app with React + Express"
   Agent:
   - Creates project structure
   - Writes all files
   - Installs dependencies
   - Shows working app
   ```

2. **File Operations**
   - Create new files
   - Modify existing files
   - Delete files
   - Show diff before applying

3. **Command Execution**
   - Run npm/yarn commands
   - Run tests
   - Run build
   - Run dev server

4. **Git Operations**
   - Init repo
   - Create commits
   - Create branches
   - Push to GitHub

5. **Preview & Approval**
   - Show plan before execution
   - Show diff before applying
   - Allow user to approve/reject
   - Support undo

### Should Have (Важно)

6. **Multi-file Context**
   - Understand project structure
   - Maintain consistency across files
   - Update related files automatically

7. **Error Handling**
   - Catch errors during execution
   - Show clear error messages
   - Suggest fixes
   - Retry with fixes

8. **Testing**
   - Generate tests automatically
   - Run tests after changes
   - Show test results
   - Fix failing tests

9. **Documentation**
   - Generate README
   - Add code comments
   - Create API docs
   - Update changelog

10. **Deployment**
    - Deploy to Vercel/Netlify/Fly
    - Set up CI/CD
    - Configure environment variables

### Nice to Have (Бонус)

11. **Code Review**
    - Review existing code
    - Suggest improvements
    - Find bugs
    - Optimize performance

12. **Refactoring**
    - Refactor code automatically
    - Extract functions
    - Rename variables
    - Improve structure

13. **Learning**
    - Learn from user feedback
    - Improve over time
    - Remember preferences

---

## Архитектура VIBEE Agent

### Режимы Работы

```typescript
enum AgentMode {
  CHAT = 'chat',           // Только отвечает
  AGENT = 'agent',         // Создаёт проекты
  ARCHITECT = 'architect', // Планирует
  DEBUG = 'debug',         // Исправляет баги
  REVIEW = 'review',       // Ревьюит код
}
```

### Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                    VIBEE SWE AGENT                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. USER REQUEST                                            │
│     "Create todo app with React"                            │
│                                                             │
│  2. AGENT ANALYZES                                          │
│     - Determines mode (AGENT)                               │
│     - Creates plan                                          │
│     - Shows plan to user                                    │
│                                                             │
│  3. USER APPROVES                                           │
│     [✓ Approve] [✗ Reject] [✎ Modify]                      │
│                                                             │
│  4. AGENT EXECUTES                                          │
│     ├─ Create project structure                             │
│     ├─ Write files (React components, Express server)       │
│     ├─ Install dependencies (npm install)                   │
│     ├─ Run tests (npm test)                                 │
│     ├─ Start dev server (npm run dev)                       │
│     └─ Git commit & push                                    │
│                                                             │
│  5. AGENT SHOWS RESULT                                      │
│     "✅ Todo app created!"                                  │
│     "📁 Files: 15 created"                                  │
│     "🧪 Tests: 8/8 passing"                                 │
│     "🚀 Running at: http://localhost:3000"                  │
│     "📦 Git: Committed & pushed"                            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### File Operations API

```typescript
interface FileOperations {
  // Create
  createFile(path: string, content: string): Promise<void>;
  createDirectory(path: string): Promise<void>;
  
  // Read
  readFile(path: string): Promise<string>;
  listFiles(path: string): Promise<string[]>;
  
  // Update
  modifyFile(path: string, changes: Change[]): Promise<void>;
  replaceFile(path: string, content: string): Promise<void>;
  
  // Delete
  deleteFile(path: string): Promise<void>;
  deleteDirectory(path: string): Promise<void>;
  
  // Preview
  previewChanges(operations: FileOperation[]): Diff[];
  applyChanges(operations: FileOperation[]): Promise<void>;
  
  // Undo
  undo(): Promise<void>;
  getHistory(): FileOperation[];
}
```

### Command Execution API

```typescript
interface CommandExecutor {
  // Execute
  exec(command: string, cwd?: string): Promise<ExecResult>;
  execStream(command: string, onOutput: (data: string) => void): Promise<void>;
  
  // Common commands
  npm: {
    install(): Promise<void>;
    run(script: string): Promise<void>;
    test(): Promise<TestResult>;
  };
  
  git: {
    init(): Promise<void>;
    add(files: string[]): Promise<void>;
    commit(message: string): Promise<void>;
    push(): Promise<void>;
  };
}
```

---

## Implementation Plan

### Phase 1: Basic Agent Mode (Week 1)

- [ ] Add agent mode toggle
- [ ] Implement file creation
- [ ] Implement file modification
- [ ] Add preview/approval flow
- [ ] Basic command execution

### Phase 2: Project Scaffolding (Week 2)

- [ ] Project templates (React, Express, etc.)
- [ ] Dependency management
- [ ] Git integration
- [ ] Test generation

### Phase 3: Advanced Features (Week 3)

- [ ] Multi-file context
- [ ] Error handling & retry
- [ ] Undo/redo support
- [ ] Deployment integration

### Phase 4: Polish (Week 4)

- [ ] UI improvements
- [ ] Documentation
- [ ] Testing
- [ ] Performance optimization

---

## Example: Create Todo App

```typescript
// User request
"Create a todo app with React frontend and Express backend"

// Agent plan
{
  mode: 'agent',
  project: 'todo-app',
  structure: {
    'frontend/': ['React app with Vite'],
    'backend/': ['Express API'],
    'shared/': ['TypeScript types']
  },
  steps: [
    'Create project structure',
    'Setup frontend (React + Vite)',
    'Setup backend (Express + TypeScript)',
    'Create shared types',
    'Write frontend components',
    'Write backend API',
    'Write tests',
    'Setup dev environment',
    'Create README'
  ]
}

// Agent execution
1. mkdir todo-app && cd todo-app
2. npm create vite@latest frontend -- --template react-ts
3. mkdir backend && cd backend && npm init -y
4. npm install express typescript @types/express
5. Write files:
   - frontend/src/App.tsx
   - frontend/src/components/TodoList.tsx
   - backend/src/server.ts
   - backend/src/routes/todos.ts
   - shared/types.ts
6. npm install (both frontend & backend)
7. npm test (both)
8. git init && git add . && git commit -m "Initial commit"
9. Start dev servers

// Agent result
"✅ Todo app created successfully!
 📁 15 files created
 🧪 12 tests passing
 🚀 Frontend: http://localhost:5173
 🚀 Backend: http://localhost:3000
 📦 Git: Initialized and committed"
```

---

## Conclusion

**VIBEE SWE Agent должен:**

1. ✅ **Создавать реальные проекты** - не просто болтать
2. ✅ **Писать код в файлы** - не показывать в чате
3. ✅ **Запускать команды** - npm, git, tests
4. ✅ **Показывать preview** - перед применением
5. ✅ **Поддерживать undo** - если что-то пошло не так
6. ✅ **Работать автономно** - от идеи до деплоя

**Следующий шаг**: Реализовать Agent Mode с реальным созданием проектов!
