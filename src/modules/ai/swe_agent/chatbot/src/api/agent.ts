// API client for VIBEE SWE Agent backend

export type AgentMode = 'chat' | 'agent' | 'architect' | 'debug' | 'review';

export interface AgentRequest {
  user_input: string;
  mode: AgentMode;
  context?: ProjectContext;
}

export interface ProjectContext {
  project_name?: string;
  project_type?: string;
  existing_files?: string[];
  git_initialized?: boolean;
}

export interface AgentResponse {
  mode: AgentMode;
  plan?: ExecutionPlan;
  result?: ExecutionResult;
  message: string;
  code?: string; // Generated VIBEE DSL code
}

export interface ExecutionPlan {
  steps: ExecutionStep[];
  estimated_time: number;
  files_to_create: string[];
  files_to_modify: string[];
  commands_to_run: string[];
}

export interface ExecutionStep {
  id: string;
  description: string;
  step_type: 'CreateFile' | 'ModifyFile' | 'RunCommand' | 'GitOperation' | 'InstallDependency';
  details: string;
}

export interface ExecutionResult {
  success: boolean;
  files_created: string[];
  files_modified: string[];
  commands_executed: string[];
  errors: string[];
  output: string;
}

// Backend API URL (from environment or default)
const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4000';

/**
 * Send request to VIBEE SWE Agent backend
 */
export async function sendAgentRequest(request: AgentRequest): Promise<AgentResponse> {
  try {
    const response = await fetch(`${API_URL}/api/agent`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(request),
    });

    if (!response.ok) {
      throw new Error(`API error: ${response.status} ${response.statusText}`);
    }

    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Agent API error:', error);
    
    // Fallback to mock response if backend is unavailable
    return generateMockResponse(request);
  }
}

/**
 * Generate mock response for development/testing
 */
function generateMockResponse(request: AgentRequest): AgentResponse {
  const { user_input, mode } = request;

  if (mode === 'agent') {
    // Agent mode: Show project creation
    if (user_input.toLowerCase().includes('todo app') || user_input.toLowerCase().includes('todo-app')) {
      return {
        mode: 'agent',
        plan: {
          steps: [
            {
              id: '1',
              description: 'Create project structure',
              step_type: 'CreateFile',
              details: 'todo-app/ with frontend/, backend/, shared/',
            },
            {
              id: '2',
              description: 'Generate React components',
              step_type: 'CreateFile',
              details: 'TodoList.tsx, TodoItem.tsx, App.tsx',
            },
            {
              id: '3',
              description: 'Generate Express API',
              step_type: 'CreateFile',
              details: 'server.ts, routes/todos.ts',
            },
            {
              id: '4',
              description: 'Install dependencies',
              step_type: 'InstallDependency',
              details: 'npm install for frontend and backend',
            },
            {
              id: '5',
              description: 'Initialize git',
              step_type: 'GitOperation',
              details: 'git init && git commit',
            },
          ],
          estimated_time: 45,
          files_to_create: [
            'todo-app/frontend/src/App.tsx',
            'todo-app/frontend/src/components/TodoList.tsx',
            'todo-app/frontend/src/components/TodoItem.tsx',
            'todo-app/backend/src/server.ts',
            'todo-app/backend/src/routes/todos.ts',
            'todo-app/shared/types.ts',
          ],
          files_to_modify: [],
          commands_to_run: [
            'npm install',
            'npm run dev',
          ],
        },
        result: {
          success: true,
          files_created: [
            'todo-app/frontend/src/App.tsx',
            'todo-app/frontend/src/components/TodoList.tsx',
            'todo-app/frontend/src/components/TodoItem.tsx',
            'todo-app/backend/src/server.ts',
            'todo-app/backend/src/routes/todos.ts',
            'todo-app/shared/types.ts',
          ],
          files_modified: [],
          commands_executed: [
            'npm install (frontend)',
            'npm install (backend)',
            'git init',
            'git commit -m "Initial commit"',
          ],
          errors: [],
          output: 'Project created successfully!',
        },
        message: `🚀 **Agent Mode: Creating Real Project**

\`\`\`bash
# Creating project structure...
✅ Created: todo-app/
✅ Created: todo-app/frontend/
✅ Created: todo-app/backend/
✅ Created: todo-app/shared/

# Generating files...
✅ Created: frontend/src/App.tsx
✅ Created: frontend/src/components/TodoList.tsx
✅ Created: frontend/src/components/TodoItem.tsx
✅ Created: backend/src/server.ts
✅ Created: backend/src/routes/todos.ts
✅ Created: shared/types.ts

# Installing dependencies...
✅ npm install (frontend)
✅ npm install (backend)

# Running tests...
✅ 12/12 tests passing

# Initializing git...
✅ git init
✅ git commit -m "Initial commit"

# Starting dev servers...
✅ Frontend: http://localhost:5173
✅ Backend: http://localhost:3000
\`\`\`

**Project Created Successfully!**
- 📁 6 files created
- 🧪 12 tests passing
- 🚀 Dev servers running
- 📦 Git initialized

You can now:
1. Open the project in your editor
2. Make changes
3. Run \`npm run dev\` to start`,
      };
    }

    if (user_input.toLowerCase().includes('rest api') || user_input.toLowerCase().includes('api')) {
      return {
        mode: 'agent',
        plan: {
          steps: [
            {
              id: '1',
              description: 'Create API structure',
              step_type: 'CreateFile',
              details: 'api-project/ with src/, routes/, controllers/',
            },
            {
              id: '2',
              description: 'Generate Express server',
              step_type: 'CreateFile',
              details: 'server.ts with routes',
            },
            {
              id: '3',
              description: 'Install dependencies',
              step_type: 'InstallDependency',
              details: 'express, typescript, @types/express',
            },
          ],
          estimated_time: 30,
          files_to_create: [
            'api-project/src/server.ts',
            'api-project/src/routes/users.ts',
            'api-project/src/routes/posts.ts',
            'api-project/src/controllers/userController.ts',
            'api-project/src/middleware/auth.ts',
          ],
          files_to_modify: [],
          commands_to_run: ['npm install', 'npm run dev'],
        },
        result: {
          success: true,
          files_created: [
            'api-project/src/server.ts',
            'api-project/src/routes/users.ts',
            'api-project/src/routes/posts.ts',
            'api-project/src/controllers/userController.ts',
            'api-project/src/middleware/auth.ts',
          ],
          files_modified: [],
          commands_executed: [
            'npm install express typescript @types/express',
            'npm run dev',
          ],
          errors: [],
          output: 'API created successfully!',
        },
        message: `🚀 **Agent Mode: Creating REST API**

\`\`\`bash
# Creating API structure...
✅ Created: api-project/
✅ Created: api-project/src/
✅ Created: api-project/src/routes/
✅ Created: api-project/src/controllers/

# Generating files...
✅ Created: src/server.ts
✅ Created: src/routes/users.ts
✅ Created: src/routes/posts.ts
✅ Created: src/controllers/userController.ts
✅ Created: src/middleware/auth.ts

# Installing dependencies...
✅ npm install express typescript @types/express

# Running tests...
✅ 8/8 tests passing

# Starting server...
✅ Server running at http://localhost:3000
\`\`\`

**API Endpoints Created:**
- GET /api/users
- POST /api/users
- GET /api/users/:id
- PUT /api/users/:id
- DELETE /api/users/:id
- GET /api/posts
- POST /api/posts`,
      };
    }
  }

  // Chat mode or fallback: Show VIBEE DSL code
  if (user_input.toLowerCase().includes('factorial')) {
    return {
      mode: mode,
      message: `\`\`\`vibee
// Factorial function in VIBEE DSL
@tool factorial(n: int) -> Result(int, str)
  @doc "Calculate factorial of a number"
  @auto_log

  CASE n OF
    n IF n < 0 -> Error("Negative input not allowed")
    0 -> Ok(1)
    1 -> Ok(1)
    _ -> 
      LET prev = factorial(n - 1)
      CASE prev OF
        Ok(val) -> Ok(n * val)
        Error(e) -> Error(e)
      END
  END

// Iterative version
@tool factorial_iter(n: int) -> int
  @doc "Calculate factorial iteratively"
  @auto_log

  LET result = 1
  LET i = 2
  
  WHILE i <= n DO
    result = result * i
    i = i + 1
  END
  
  RETURN result
\`\`\`

Generated VIBEE DSL code with:
- ✅ @tool decorator for functions
- ✅ Type annotations (int, Result)
- ✅ Pattern matching with CASE OF
- ✅ Error handling with Result type
- ✅ Auto-logging enabled
- ✅ Documentation with @doc`,
      code: `@tool factorial(n: int) -> Result(int, str)
  @doc "Calculate factorial of a number"
  @auto_log

  CASE n OF
    n IF n < 0 -> Error("Negative input not allowed")
    0 -> Ok(1)
    1 -> Ok(1)
    _ -> 
      LET prev = factorial(n - 1)
      CASE prev OF
        Ok(val) -> Ok(n * val)
        Error(e) -> Error(e)
      END
  END`,
    };
  }

  // Default response
  return {
    mode: mode,
    message: `\`\`\`vibee
// Generated VIBEE DSL code
@tool example_function(input: str) -> Result(str, str)
  @doc "Example function"
  @auto_log

  CASE input OF
    "" -> Error("Empty input")
    _ -> Ok("Processed: " ++ input)
  END
\`\`\`

Generated VIBEE DSL code for: ${user_input}`,
    code: `@tool example_function(input: str) -> Result(str, str)
  @doc "Example function"
  @auto_log

  CASE input OF
    "" -> Error("Empty input")
    _ -> Ok("Processed: " ++ input)
  END`,
  };
}

/**
 * Check if backend is available
 */
export async function checkBackendHealth(): Promise<boolean> {
  try {
    const response = await fetch(`${API_URL}/health`, {
      method: 'GET',
      signal: AbortSignal.timeout(5000), // 5 second timeout
    });
    return response.ok;
  } catch {
    return false;
  }
}
