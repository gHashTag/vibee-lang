/**
 * VIBEE Browser - AI Agent Framework
 * Analog of Eko, but for VIBEE
 * φ² + 1/φ² = 3 | PHOENIX = 999
 */

const { CDPClient } = require('./cdp-client');

// ═══════════════════════════════════════════════════════════════════════════
// AGENT TOOLS
// ═══════════════════════════════════════════════════════════════════════════

const TOOLS = {
    navigate: {
        name: 'navigate',
        description: 'Navigate to a URL',
        parameters: {
            url: { type: 'string', description: 'The URL to navigate to' }
        },
        execute: async (agent, params) => {
            await agent.browser.navigate(params.url);
            return { success: true, url: params.url };
        }
    },

    click: {
        name: 'click',
        description: 'Click on an element',
        parameters: {
            selector: { type: 'string', description: 'CSS selector of the element' }
        },
        execute: async (agent, params) => {
            const result = await agent.browser.executeJs(`
                const el = document.querySelector('${params.selector}');
                if (el) {
                    el.click();
                    return { success: true };
                }
                return { success: false, error: 'Element not found' };
            `);
            return result;
        }
    },

    type: {
        name: 'type',
        description: 'Type text into an input field',
        parameters: {
            selector: { type: 'string', description: 'CSS selector of the input' },
            text: { type: 'string', description: 'Text to type' }
        },
        execute: async (agent, params) => {
            const result = await agent.browser.executeJs(`
                const el = document.querySelector('${params.selector}');
                if (el) {
                    el.focus();
                    el.value = '${params.text.replace(/'/g, "\\'")}';
                    el.dispatchEvent(new Event('input', { bubbles: true }));
                    return { success: true };
                }
                return { success: false, error: 'Element not found' };
            `);
            return result;
        }
    },

    scroll: {
        name: 'scroll',
        description: 'Scroll the page',
        parameters: {
            direction: { type: 'string', description: 'up or down' },
            amount: { type: 'number', description: 'Pixels to scroll' }
        },
        execute: async (agent, params) => {
            const y = params.direction === 'up' ? -params.amount : params.amount;
            await agent.browser.executeJs(`window.scrollBy(0, ${y})`);
            return { success: true };
        }
    },

    screenshot: {
        name: 'screenshot',
        description: 'Take a screenshot of the page',
        parameters: {},
        execute: async (agent) => {
            const result = await agent.browser.screenshot();
            return { success: true, data: result.data };
        }
    },

    extract: {
        name: 'extract',
        description: 'Extract text from an element',
        parameters: {
            selector: { type: 'string', description: 'CSS selector' }
        },
        execute: async (agent, params) => {
            const result = await agent.browser.executeJs(`
                const el = document.querySelector('${params.selector}');
                return el ? { success: true, text: el.innerText } : { success: false };
            `);
            return result;
        }
    },

    getPageContent: {
        name: 'getPageContent',
        description: 'Get the full text content of the page',
        parameters: {},
        execute: async (agent) => {
            const result = await agent.browser.getPageContent();
            return { success: true, content: result.content };
        }
    },

    wait: {
        name: 'wait',
        description: 'Wait for a specified time',
        parameters: {
            ms: { type: 'number', description: 'Milliseconds to wait' }
        },
        execute: async (agent, params) => {
            await new Promise(resolve => setTimeout(resolve, params.ms));
            return { success: true };
        }
    },

    done: {
        name: 'done',
        description: 'Mark the task as complete',
        parameters: {
            result: { type: 'string', description: 'Final result or summary' }
        },
        execute: async (agent, params) => {
            return { success: true, done: true, result: params.result };
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// VIBEE AGENT
// ═══════════════════════════════════════════════════════════════════════════

class VIBEEAgent {
    constructor(config = {}) {
        this.model = config.model || 'gpt-4';
        this.maxSteps = config.maxSteps || 20;
        this.browser = config.browser; // Browser interface
        this.llm = config.llm; // LLM interface
        this.tools = { ...TOOLS, ...config.tools };
        this.history = [];
        this.verbose = config.verbose || false;
    }

    /**
     * Run the agent with a goal
     */
    async run(goal) {
        this.log(`\n${'═'.repeat(60)}`);
        this.log(`VIBEE Agent Starting`);
        this.log(`Goal: ${goal}`);
        this.log(`${'═'.repeat(60)}\n`);

        this.history = [];
        
        for (let step = 1; step <= this.maxSteps; step++) {
            this.log(`\n--- Step ${step}/${this.maxSteps} ---`);

            // Think: Generate thought and action
            const { thought, action, actionInput } = await this.think(goal);
            
            this.log(`Thought: ${thought}`);
            this.log(`Action: ${action}`);
            this.log(`Input: ${JSON.stringify(actionInput)}`);

            // Act: Execute the action
            const observation = await this.act(action, actionInput);
            
            this.log(`Observation: ${JSON.stringify(observation).slice(0, 200)}`);

            // Record step
            this.history.push({
                step,
                thought,
                action,
                actionInput,
                observation
            });

            // Check if done
            if (observation.done) {
                this.log(`\n${'═'.repeat(60)}`);
                this.log(`Task Complete!`);
                this.log(`Result: ${observation.result}`);
                this.log(`${'═'.repeat(60)}\n`);
                return {
                    success: true,
                    result: observation.result,
                    steps: this.history
                };
            }
        }

        return {
            success: false,
            error: 'Max steps reached',
            steps: this.history
        };
    }

    /**
     * Think: Generate thought and action using LLM
     */
    async think(goal) {
        // Build prompt
        const toolDescriptions = Object.values(this.tools)
            .map(t => `- ${t.name}: ${t.description}`)
            .join('\n');

        const historyText = this.history
            .map(h => `Step ${h.step}:\nThought: ${h.thought}\nAction: ${h.action}\nObservation: ${JSON.stringify(h.observation).slice(0, 500)}`)
            .join('\n\n');

        const prompt = `You are VIBEE, an AI browser agent. Your goal is: ${goal}

Available tools:
${toolDescriptions}

${historyText ? `Previous steps:\n${historyText}\n\n` : ''}

Based on the goal and previous steps, decide what to do next.
Respond in this exact format:
Thought: [your reasoning about what to do]
Action: [tool name]
Action Input: [JSON object with parameters]

If the task is complete, use the "done" action with the result.`;

        // Call LLM (simplified - in real implementation, use actual LLM API)
        if (this.llm) {
            const response = await this.llm.complete(prompt);
            return this.parseResponse(response);
        }

        // Fallback: Simple rule-based logic
        return this.simpleThink(goal);
    }

    /**
     * Simple rule-based thinking (fallback when no LLM)
     */
    simpleThink(goal) {
        const goalLower = goal.toLowerCase();
        
        // Check history
        const lastStep = this.history[this.history.length - 1];
        
        if (this.history.length === 0) {
            // First step
            if (goalLower.includes('go to') || goalLower.includes('navigate')) {
                const urlMatch = goal.match(/(?:go to|navigate to?)\s+(\S+)/i);
                if (urlMatch) {
                    return {
                        thought: `I need to navigate to ${urlMatch[1]}`,
                        action: 'navigate',
                        actionInput: { url: urlMatch[1].startsWith('http') ? urlMatch[1] : `https://${urlMatch[1]}` }
                    };
                }
            }
            
            if (goalLower.includes('click')) {
                const selectorMatch = goal.match(/click\s+(?:on\s+)?(.+)/i);
                if (selectorMatch) {
                    return {
                        thought: `I need to click on ${selectorMatch[1]}`,
                        action: 'click',
                        actionInput: { selector: selectorMatch[1] }
                    };
                }
            }

            if (goalLower.includes('screenshot')) {
                return {
                    thought: 'I need to take a screenshot',
                    action: 'screenshot',
                    actionInput: {}
                };
            }

            // Default: get page content first
            return {
                thought: 'Let me first understand what is on the page',
                action: 'getPageContent',
                actionInput: {}
            };
        }

        // After first step
        if (lastStep && lastStep.observation.success) {
            return {
                thought: 'The action was successful. Task complete.',
                action: 'done',
                actionInput: { result: `Successfully completed: ${goal}` }
            };
        }

        return {
            thought: 'Unable to determine next action',
            action: 'done',
            actionInput: { result: 'Could not complete the task' }
        };
    }

    /**
     * Parse LLM response
     */
    parseResponse(response) {
        const thoughtMatch = response.match(/Thought:\s*(.+?)(?=\nAction:|$)/s);
        const actionMatch = response.match(/Action:\s*(\w+)/);
        const inputMatch = response.match(/Action Input:\s*({.+})/s);

        return {
            thought: thoughtMatch ? thoughtMatch[1].trim() : 'Thinking...',
            action: actionMatch ? actionMatch[1] : 'done',
            actionInput: inputMatch ? JSON.parse(inputMatch[1]) : {}
        };
    }

    /**
     * Act: Execute the action
     */
    async act(action, actionInput) {
        const tool = this.tools[action];
        
        if (!tool) {
            return { success: false, error: `Unknown action: ${action}` };
        }

        try {
            return await tool.execute(this, actionInput);
        } catch (error) {
            return { success: false, error: error.message };
        }
    }

    /**
     * Log message
     */
    log(message) {
        if (this.verbose) {
            console.log(`[VIBEE Agent] ${message}`);
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// LLM INTERFACE
// ═══════════════════════════════════════════════════════════════════════════

class LLMInterface {
    constructor(config = {}) {
        this.provider = config.provider || 'openai';
        this.apiKey = config.apiKey;
        this.model = config.model || 'gpt-4';
        this.baseUrl = config.baseUrl;
    }

    async complete(prompt) {
        if (this.provider === 'openai') {
            return this.openaiComplete(prompt);
        } else if (this.provider === 'anthropic') {
            return this.anthropicComplete(prompt);
        } else if (this.provider === 'local') {
            return this.localComplete(prompt);
        }
        throw new Error(`Unknown provider: ${this.provider}`);
    }

    async openaiComplete(prompt) {
        const OpenAI = require('openai');
        const client = new OpenAI({ apiKey: this.apiKey });
        
        const response = await client.chat.completions.create({
            model: this.model,
            messages: [{ role: 'user', content: prompt }],
            temperature: 0.7
        });

        return response.choices[0].message.content;
    }

    async anthropicComplete(prompt) {
        const Anthropic = require('@anthropic-ai/sdk');
        const client = new Anthropic({ apiKey: this.apiKey });

        const response = await client.messages.create({
            model: this.model,
            max_tokens: 1024,
            messages: [{ role: 'user', content: prompt }]
        });

        return response.content[0].text;
    }

    async localComplete(prompt) {
        // For local LLM (Ollama, LMStudio, etc.)
        const response = await fetch(`${this.baseUrl}/v1/chat/completions`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                model: this.model,
                messages: [{ role: 'user', content: prompt }]
            })
        });

        const data = await response.json();
        return data.choices[0].message.content;
    }
}

module.exports = { VIBEEAgent, LLMInterface, TOOLS };
