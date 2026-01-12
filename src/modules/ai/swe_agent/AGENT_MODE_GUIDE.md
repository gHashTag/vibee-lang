# 🤖 VIBEE SWE Agent - Agent Mode Guide

## 🎯 Два Режима Работы

### 💬 Chat Mode (Пассивный)
- Только отвечает на вопросы
- Не меняет код
- Не создаёт файлы
- Даёт советы и объяснения

**Примеры:**
```
"Explain how VIBEE DSL works"
"What are best practices for error handling?"
"How do I use pattern matching in VIBEE?"
```

### 🚀 Agent Mode (Активный)
- **Создаёт реальные проекты**
- **Пишет код в файлы**
- **Запускает команды**
- **Делает git commits**
- **Показывает результат**

**Примеры:**
```
"Create a todo app with React and Express"
"Build a REST API with TypeScript"
"Generate a Gleam project with tests"
```

---

## 🚀 Agent Mode - Как Это Работает

### Workflow

```
1. USER REQUEST
   "Create todo app with React"
   
2. AGENT ANALYZES
   - Determines project type
   - Creates execution plan
   - Shows plan to user
   
3. USER APPROVES
   [✓ Approve] [✗ Reject] [✎ Modify]
   
4. AGENT EXECUTES
   ├─ Creates project structure
   ├─ Generates all files
   ├─ Installs dependencies
   ├─ Runs tests
   ├─ Initializes git
   └─ Starts dev server
   
5. AGENT SHOWS RESULT
   ✅ Project created!
   📁 15 files created
   🧪 12/12 tests passing
   🚀 Running at http://localhost:3000
```

### Что Агент Создаёт

**React App:**
```
todo-app/
├── src/
│   ├── App.tsx
│   ├── components/
│   │   ├── TodoList.tsx
│   │   └── TodoItem.tsx
│   ├── hooks/
│   │   └── useTodos.ts
│   └── main.tsx
├── package.json
├── vite.config.ts
├── tsconfig.json
└── README.md
```

**Express API:**
```
api-project/
├── src/
│   ├── server.ts
│   ├── routes/
│   │   ├── users.ts
│   │   └── posts.ts
│   ├── controllers/
│   │   └── userController.ts
│   └── middleware/
│       ├── auth.ts
│       └── errorHandler.ts
├── package.json
├── tsconfig.json
└── README.md
```

**Gleam Project:**
```
gleam-project/
├── src/
│   └── main.gleam
├── test/
│   └── main_test.gleam
├── gleam.toml
└── README.md
```

---

## 📋 Примеры Использования

### 1. Create Todo App

**User:**
```
Create a todo app with React frontend and Express backend
```

**Agent Response:**
```
🚀 Agent Mode: Creating Real Project

# Creating project structure...
✅ Created: todo-app/
✅ Created: todo-app/frontend/
✅ Created: todo-app/backend/
✅ Created: todo-app/shared/

# Generating files...
✅ Created: frontend/src/App.tsx
✅ Created: frontend/src/components/TodoList.tsx
✅ Created: backend/src/server.ts
✅ Created: backend/src/routes/todos.ts
✅ Created: shared/types.ts

# Installing dependencies...
✅ npm install (frontend)
✅ npm install (backend)

# Running tests...
✅ 12/12 tests passing

# Starting dev servers...
✅ Frontend: http://localhost:5173
✅ Backend: http://localhost:3000

Project Created Successfully!
- 📁 15 files created
- 🧪 12 tests passing
- 🚀 Dev servers running
```

### 2. Build REST API

**User:**
```
Create a REST API with Express and TypeScript
```

**Agent Response:**
```
🚀 Agent Mode: Creating REST API

# Creating API structure...
✅ Created: api-project/
✅ Created: src/routes/
✅ Created: src/controllers/
✅ Created: src/middleware/

# Generating files...
✅ Created: src/server.ts
✅ Created: src/routes/users.ts
✅ Created: src/controllers/userController.ts
✅ Created: src/middleware/auth.ts

# Installing dependencies...
✅ npm install express typescript

# Running tests...
✅ 8/8 tests passing

# Starting server...
✅ Server running at http://localhost:3000

API Endpoints Created:
- GET /api/users
- POST /api/users
- GET /api/users/:id
- PUT /api/users/:id
- DELETE /api/users/:id
```

### 3. Generate Gleam Project

**User:**
```
Create a Gleam project with tests
```

**Agent Response:**
```
🚀 Agent Mode: Creating Gleam Project

# Creating project structure...
✅ Created: gleam-project/
✅ Created: src/
✅ Created: test/

# Generating files...
✅ Created: src/main.gleam
✅ Created: test/main_test.gleam
✅ Created: gleam.toml

# Installing dependencies...
✅ gleam deps download

# Running tests...
✅ gleam test
✅ 5/5 tests passing

Project Created Successfully!
- 📁 4 files created
- 🧪 5 tests passing
- 🚀 Ready to use
```

---

## 🎨 UI Features

### Mode Toggle

```
┌─────────────────────────────────────┐
│  [💬 Chat]  [🚀 Agent]  ● Online   │
└─────────────────────────────────────┘
```

- Click **Chat** for passive mode
- Click **Agent** for active mode
- Green dot shows connection status

### Example Prompts

**Chat Mode:**
- "Explain VIBEE DSL"
- "Best practices"

**Agent Mode:**
- "Create todo app with React"
- "Build REST API"

### Loading Indicators

**Chat Mode:**
```
● ● ● Agent is thinking...
```

**Agent Mode:**
```
● ● ● Agent is creating project...
```

---

## 🔧 Configuration

### Agent Config

```typescript
interface AgentConfig {
  mode: 'chat' | 'agent';
  auto_approve: boolean;      // Auto-apply changes
  show_preview: boolean;      // Show preview first
  auto_commit: boolean;       // Auto git commit
  workspace_path: string;     // Project directory
}
```

### Default Settings

```typescript
{
  mode: 'agent',
  auto_approve: false,        // User must approve
  show_preview: true,         // Show plan first
  auto_commit: true,          // Auto commit
  workspace_path: './projects'
}
```

---

## 🛡️ Safety Features

### 1. Preview Before Apply

```
Agent: "I will create these files:"
  
  src/App.tsx
  src/components/TodoList.tsx
  package.json
  
User: [✓ Approve] [✗ Reject] [✎ Modify]
```

### 2. Undo Support

```
Agent: "Changes applied. Type 'undo' to revert."
User: "undo"
Agent: "✅ Reverted all changes."
```

### 3. Sandbox Mode

```
Agent: "Running in sandbox mode."
Agent: "Changes won't affect real files."
```

---

## 🚀 Quick Start

### 1. Start Chatbot

```bash
cd swe_agent/chatbot
npm install
npm run dev
```

### 2. Toggle to Agent Mode

Click **🚀 Agent** button in header

### 3. Create Project

Type: `Create a todo app with React`

### 4. Approve Plan

Click **✓ Approve** when plan is shown

### 5. Wait for Completion

Agent will:
- Create files
- Install dependencies
- Run tests
- Start dev server

### 6. Open Project

```bash
cd projects/todo-app
npm run dev
```

---

## 📊 Comparison

| Feature | Chat Mode | Agent Mode |
|---------|-----------|------------|
| Answers questions | ✅ | ✅ |
| Creates files | ❌ | ✅ |
| Runs commands | ❌ | ✅ |
| Git operations | ❌ | ✅ |
| Shows code | ✅ | ✅ |
| Applies changes | ❌ | ✅ |
| Preview | N/A | ✅ |
| Undo | N/A | ✅ |

---

## 🎯 Best Practices

### When to Use Chat Mode

- ✅ Learning about VIBEE DSL
- ✅ Asking for explanations
- ✅ Getting code examples
- ✅ Understanding concepts

### When to Use Agent Mode

- ✅ Creating new projects
- ✅ Scaffolding applications
- ✅ Generating boilerplate
- ✅ Setting up infrastructure

### Tips for Agent Mode

1. **Be specific**: "Create React app with TypeScript and TailwindCSS"
2. **Mention tech stack**: "Use Express, PostgreSQL, and JWT"
3. **Specify features**: "Include authentication and user management"
4. **Review plan**: Always check the plan before approving
5. **Use undo**: If something goes wrong, type "undo"

---

## 🔮 Future Features

### Coming Soon

- [ ] Multi-step projects
- [ ] Interactive refinement
- [ ] Deployment integration
- [ ] CI/CD setup
- [ ] Database migrations
- [ ] Docker configuration
- [ ] Environment variables
- [ ] API documentation

### Planned Improvements

- [ ] Better error handling
- [ ] Faster execution
- [ ] More templates
- [ ] Custom templates
- [ ] Team collaboration
- [ ] Version control
- [ ] Rollback support

---

## 🐛 Troubleshooting

### Agent Not Creating Files

**Problem**: Agent shows plan but doesn't create files

**Solution**:
1. Check workspace_path is correct
2. Ensure write permissions
3. Verify disk space
4. Check logs for errors

### Dependencies Not Installing

**Problem**: npm install fails

**Solution**:
1. Check internet connection
2. Verify npm is installed
3. Clear npm cache: `npm cache clean --force`
4. Try manual install

### Tests Failing

**Problem**: Generated tests don't pass

**Solution**:
1. Review test output
2. Check generated code
3. Ask agent to fix: "Fix failing tests"
4. Manual fix if needed

---

## 📚 Resources

- [VIBEE DSL Documentation](../docs/)
- [Agent Architecture](./REAL_SWE_AGENT_PRACTICES.md)
- [Chatbot UI Guide](./chatbot/README.md)
- [Best Practices](./chatbot/CHATBOT_BEST_PRACTICES.md)

---

## 🎉 Conclusion

**Agent Mode** превращает VIBEE SWE Agent из простого чат-бота в **реального помощника**, который:

- ✅ Создаёт проекты с нуля
- ✅ Пишет код в файлы
- ✅ Запускает команды
- ✅ Делает commits
- ✅ Показывает результат

**Попробуйте прямо сейчас!** 🚀
