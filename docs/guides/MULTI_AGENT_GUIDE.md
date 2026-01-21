# Multi-Agent Systems Guide

**VIBEE v2014-v2030 | Collaborative AI Architectures**

---

## Overview

Multi-agent systems enable complex task completion through agent collaboration, role specialization, and emergent collective behavior.

---

## 1. Architecture Patterns

### Hub-and-Spoke (Orchestrator)
```
                    ┌─────────────┐
                    │ Orchestrator│
                    │   Agent     │
                    └──────┬──────┘
           ┌───────────────┼───────────────┐
           │               │               │
           ▼               ▼               ▼
    ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
    │   Worker    │ │   Worker    │ │   Worker    │
    │   Agent 1   │ │   Agent 2   │ │   Agent 3   │
    └─────────────┘ └─────────────┘ └─────────────┘
```

### Peer-to-Peer (Decentralized)
```
    ┌─────────────┐         ┌─────────────┐
    │   Agent A   │◀───────▶│   Agent B   │
    └──────┬──────┘         └──────┬──────┘
           │                       │
           │    ┌─────────────┐    │
           └───▶│   Agent C   │◀───┘
                └─────────────┘
```

### Hierarchical (Team Structure)
```
                    ┌─────────────┐
                    │   Manager   │
                    └──────┬──────┘
           ┌───────────────┴───────────────┐
           ▼                               ▼
    ┌─────────────┐                 ┌─────────────┐
    │ Team Lead A │                 │ Team Lead B │
    └──────┬──────┘                 └──────┬──────┘
     ┌─────┴─────┐                   ┌─────┴─────┐
     ▼           ▼                   ▼           ▼
┌────────┐ ┌────────┐           ┌────────┐ ┌────────┐
│Worker 1│ │Worker 2│           │Worker 3│ │Worker 4│
└────────┘ └────────┘           └────────┘ └────────┘
```

---

## 2. Framework Comparison

| Framework | Pattern | Strengths | Use Case |
|-----------|---------|-----------|----------|
| AutoGen (v2017) | Conversational | Flexible dialogue | Research, prototyping |
| CrewAI (v2018) | Role-based | Easy setup | Business workflows |
| LangGraph (v2019) | Graph-based | State management | Complex pipelines |
| MetaGPT (v2021) | SOP-driven | Software dev | Code generation |
| Magentic-One (v2024) | Generalist | Web tasks | Automation |

---

## 3. VIBEE Implementation

### Multi-Agent Core (v2014)

```vibee
# specs/tri/multi_agent_v2014.vibee
name: multi_agent_v2014
version: "1.0.0"
language: zig
module: multi_agent_v2014

types:
  Agent:
    fields:
      id: String
      role: String
      capabilities: String
      memory: String

  Message:
    fields:
      sender: String
      receiver: String
      content: String
      message_type: String

  AgentTeam:
    fields:
      agents: String
      topology: String
      shared_memory: String

behaviors:
  - name: send_message
    given: "Agent with message to send"
    when: "Communication initiated"
    then: "Message delivered to recipient"

  - name: process_message
    given: "Agent receives message"
    when: "Message processing triggered"
    then: "Response or action generated"

  - name: coordinate_task
    given: "Team with complex task"
    when: "Task decomposition needed"
    then: "Subtasks assigned to agents"
```

### AutoGen Pattern (v2017)

```vibee
# specs/tri/autogen_v2017.vibee
name: autogen_v2017
version: "1.0.0"
language: zig
module: autogen_v2017

types:
  ConversableAgent:
    fields:
      name: String
      system_message: String
      llm_config: String
      human_input_mode: String

  GroupChat:
    fields:
      agents: String
      max_round: Int
      speaker_selection: String

behaviors:
  - name: initiate_chat
    given: "Initiator agent with message"
    when: "Chat started"
    then: "Conversation loop begins"

  - name: generate_reply
    given: "Agent receives message in context"
    when: "Reply generation triggered"
    then: "LLM-generated response returned"

  - name: select_speaker
    given: "Group chat state"
    when: "Next speaker needed"
    then: "Appropriate agent selected"
```

### CrewAI Pattern (v2018)

```vibee
# specs/tri/crewai_v2018.vibee
name: crewai_v2018
version: "1.0.0"
language: zig
module: crewai_v2018

types:
  CrewAgent:
    fields:
      role: String
      goal: String
      backstory: String
      tools: String

  Task:
    fields:
      description: String
      agent: String
      expected_output: String
      context: String

  Crew:
    fields:
      agents: String
      tasks: String
      process: String

behaviors:
  - name: kickoff
    given: "Crew with defined tasks"
    when: "Execution started"
    then: "Tasks executed in sequence/parallel"

  - name: delegate_task
    given: "Agent with subtask"
    when: "Delegation needed"
    then: "Task assigned to appropriate agent"
```

---

## 4. Coding Agents (v2025-v2030)

### SWE-Agent Pattern (v2026)

```
┌─────────────────────────────────────────────────────────┐
│                    SWE-AGENT LOOP                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. Receive Issue                                       │
│     └─▶ Parse problem description                       │
│                                                         │
│  2. Explore Codebase                                    │
│     └─▶ find_file, search_dir, open_file               │
│                                                         │
│  3. Localize Bug/Feature                                │
│     └─▶ Identify relevant files and functions          │
│                                                         │
│  4. Generate Patch                                      │
│     └─▶ edit_file with proposed changes                │
│                                                         │
│  5. Test & Validate                                     │
│     └─▶ Run tests, check for regressions               │
│                                                         │
│  6. Submit Solution                                     │
│     └─▶ Create PR or patch file                        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Agent-Computer Interface (ACI)

```vibee
# specs/tri/swe_agent_v2026.vibee
types:
  ACICommand:
    fields:
      command_type: String
      arguments: String
      working_dir: String

  FileOperation:
    fields:
      operation: String
      path: String
      content: String
      line_range: String

behaviors:
  - name: execute_command
    given: "ACI command specification"
    when: "Command execution requested"
    then: "Command result returned"

  - name: edit_file
    given: "File path and edit specification"
    when: "File modification needed"
    then: "File updated with changes"

  - name: search_codebase
    given: "Search query and scope"
    when: "Code search initiated"
    then: "Matching results returned"
```

---

## 5. Communication Protocols

### Message Types

| Type | Purpose | Example |
|------|---------|---------|
| REQUEST | Ask for action | "Please review this code" |
| INFORM | Share information | "The tests passed" |
| PROPOSE | Suggest action | "I suggest using async" |
| ACCEPT | Agree to proposal | "Approved, proceed" |
| REJECT | Decline proposal | "Rejected, try again" |
| DELEGATE | Assign subtask | "Handle the frontend" |

### State Machine

```
┌─────────┐  request   ┌─────────┐
│  IDLE   │───────────▶│ WORKING │
└────┬────┘            └────┬────┘
     │                      │
     │ timeout              │ complete
     │                      │
     ▼                      ▼
┌─────────┐  retry     ┌─────────┐
│  ERROR  │◀───────────│  DONE   │
└─────────┘            └─────────┘
```

---

## 6. Best Practices

### Agent Design
1. **Single Responsibility**: Each agent has one clear role
2. **Clear Interfaces**: Well-defined input/output contracts
3. **Graceful Degradation**: Handle failures without cascade
4. **Observability**: Log all agent interactions

### Team Composition
1. **Complementary Skills**: Diverse agent capabilities
2. **Clear Hierarchy**: Defined decision-making authority
3. **Shared Context**: Common knowledge base
4. **Feedback Loops**: Iterative improvement

### Scaling
1. **Horizontal**: Add more agents of same type
2. **Vertical**: Increase agent capabilities
3. **Hybrid**: Combine patterns as needed

---

## 7. Evaluation Metrics

| Metric | Description | Target |
|--------|-------------|--------|
| Task Success Rate | % of tasks completed | >90% |
| Communication Efficiency | Messages per task | Minimize |
| Latency | Time to completion | <5min |
| Cost | API calls per task | Minimize |
| Quality | Human evaluation score | >4/5 |

---

## References

- Wu et al. (2023): AutoGen
- Hong et al. (2023): MetaGPT
- Yang et al. (2024): SWE-Agent
- Park et al. (2023): Generative Agents

---

**φ² + 1/φ² = 3 | PHOENIX = 999**
