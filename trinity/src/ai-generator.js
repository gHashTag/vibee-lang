/**
 * TRINITY v24.φ - AI Content Generator
 * 
 * φ-optimized AI generation for data structures, layouts, and content
 * Uses local models and API integration for intelligent generation
 * 
 * @version 24.φ
 */

// ═══════════════════════════════════════════════════════════════════════════════
// φ CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

const PHI = 1.618033988749895;
const PHI_INV = 0.618033988749895;
const PHI_SQ = 2.618033988749895;
const TRINITY = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// AI GENERATOR CLASS
// ═══════════════════════════════════════════════════════════════════════════════

class TrinityAIGenerator {
    constructor(options = {}) {
        this.apiEndpoint = options.apiEndpoint || 'https://api.openai.com/v1';
        this.apiKey = options.apiKey || null;
        this.model = options.model || 'gpt-4';
        this.localModel = options.localModel || null;
        this.temperature = options.temperature || PHI_INV; // φ-optimal temperature
        this.maxTokens = options.maxTokens || 1618; // φ × 1000
        
        // φ-optimized generation parameters
        this.phiParams = {
            creativityFactor: PHI_INV,
            structureBalance: PHI,
            harmonicDepth: 3, // TRINITY
            goldenSections: 5  // Fibonacci
        };
        
        // Generation cache
        this.cache = new Map();
        this.cacheMaxSize = 161; // φ × 100 rounded
        
        // Statistics
        this.stats = {
            totalGenerations: 0,
            cacheHits: 0,
            avgGenerationTime: 0
        };
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // DATA STRUCTURE GENERATION
    // ═══════════════════════════════════════════════════════════════════════════
    
    /**
     * Generate a data structure from natural language description
     */
    async generateDataStructure(description, options = {}) {
        const startTime = performance.now();
        
        const prompt = this.buildStructurePrompt(description, options);
        const cacheKey = this.hashPrompt(prompt);
        
        if (this.cache.has(cacheKey)) {
            this.stats.cacheHits++;
            return this.cache.get(cacheKey);
        }
        
        const response = await this.callAI(prompt, {
            temperature: this.phiParams.creativityFactor,
            maxTokens: this.maxTokens
        });
        
        const structure = this.parseStructureResponse(response);
        const phiOptimized = this.applyPhiOptimization(structure);
        
        this.cacheResult(cacheKey, phiOptimized);
        this.updateStats(startTime);
        
        return phiOptimized;
    }
    
    buildStructurePrompt(description, options) {
        return `You are TRINITY, an AI specialized in φ-optimized data structures.

GOLDEN RATIO PRINCIPLES:
- φ = ${PHI}
- φ² + 1/φ² = 3 (TRINITY Identity)
- All structures should exhibit golden ratio proportions

USER REQUEST: ${description}

OPTIONS:
- Type: ${options.type || 'auto-detect'}
- Complexity: ${options.complexity || 'medium'}
- φ-optimization level: ${options.phiLevel || 'high'}

Generate a data structure in JSON format with:
1. nodes: Array of {id, label, value, type, phi_weight}
2. edges: Array of {source, target, weight, type}
3. metadata: {name, description, phi_ratio, complexity}

Apply golden ratio to:
- Node spacing (φ intervals)
- Edge weights (Fibonacci sequence)
- Hierarchical depth (φ-based levels)

Respond with valid JSON only.`;
    }
    
    parseStructureResponse(response) {
        try {
            // Extract JSON from response
            const jsonMatch = response.match(/\{[\s\S]*\}/);
            if (jsonMatch) {
                return JSON.parse(jsonMatch[0]);
            }
            
            // Fallback: generate minimal structure
            return this.generateFallbackStructure();
        } catch (e) {
            console.warn('Failed to parse AI response:', e);
            return this.generateFallbackStructure();
        }
    }
    
    generateFallbackStructure() {
        return {
            nodes: [
                { id: 'root', label: 'Root', value: PHI, type: 'root', phi_weight: 1 },
                { id: 'child1', label: 'Child 1', value: PHI_INV, type: 'node', phi_weight: PHI_INV },
                { id: 'child2', label: 'Child 2', value: PHI_INV, type: 'node', phi_weight: PHI_INV }
            ],
            edges: [
                { source: 'root', target: 'child1', weight: PHI, type: 'primary' },
                { source: 'root', target: 'child2', weight: PHI_INV, type: 'secondary' }
            ],
            metadata: {
                name: 'Generated Structure',
                description: 'φ-optimized fallback structure',
                phi_ratio: PHI,
                complexity: 'simple'
            }
        };
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // LAYOUT GENERATION
    // ═══════════════════════════════════════════════════════════════════════════
    
    /**
     * Generate optimal layout for nodes using AI
     */
    async generateLayout(nodes, edges, options = {}) {
        const startTime = performance.now();
        
        const prompt = this.buildLayoutPrompt(nodes, edges, options);
        const cacheKey = this.hashPrompt(prompt);
        
        if (this.cache.has(cacheKey)) {
            this.stats.cacheHits++;
            return this.cache.get(cacheKey);
        }
        
        // Use local φ-algorithm for simple cases
        if (nodes.length <= 21) { // Fibonacci number
            return this.generatePhiLayout(nodes, edges, options);
        }
        
        const response = await this.callAI(prompt, {
            temperature: 0.3, // Lower for precise positioning
            maxTokens: nodes.length * 50
        });
        
        const layout = this.parseLayoutResponse(response, nodes);
        this.cacheResult(cacheKey, layout);
        this.updateStats(startTime);
        
        return layout;
    }
    
    buildLayoutPrompt(nodes, edges, options) {
        return `Generate φ-optimized 2D positions for ${nodes.length} nodes.

CONSTRAINTS:
- Canvas: ${options.width || 1000} × ${options.height || 618} (φ ratio)
- Spacing: Use golden ratio intervals
- Clustering: Group connected nodes
- Hierarchy: Respect edge directions

NODES: ${JSON.stringify(nodes.map(n => ({ id: n.id, type: n.type })))}
EDGES: ${JSON.stringify(edges.map(e => ({ s: e.source, t: e.target })))}

Return JSON array: [{id, x, y}]`;
    }
    
    /**
     * Local φ-optimized layout algorithm
     */
    generatePhiLayout(nodes, edges, options = {}) {
        const width = options.width || 1000;
        const height = options.height || width / PHI;
        const centerX = width / 2;
        const centerY = height / 2;
        
        const positions = [];
        const n = nodes.length;
        
        // φ-spiral layout
        for (let i = 0; i < n; i++) {
            const angle = i * Math.PI * 2 * PHI_INV;
            const radius = Math.min(width, height) * 0.4 * (1 - Math.exp(-i * 0.1));
            
            positions.push({
                id: nodes[i].id,
                x: centerX + radius * Math.cos(angle),
                y: centerY + radius * Math.sin(angle)
            });
        }
        
        // Apply force-directed refinement with φ-weights
        return this.refineLayoutWithPhi(positions, edges, { width, height });
    }
    
    refineLayoutWithPhi(positions, edges, bounds, iterations = 50) {
        const posMap = new Map(positions.map(p => [p.id, { x: p.x, y: p.y }]));
        
        for (let iter = 0; iter < iterations; iter++) {
            const forces = new Map();
            
            // Initialize forces
            for (const p of positions) {
                forces.set(p.id, { fx: 0, fy: 0 });
            }
            
            // Repulsion between all nodes (φ-weighted)
            for (let i = 0; i < positions.length; i++) {
                for (let j = i + 1; j < positions.length; j++) {
                    const p1 = posMap.get(positions[i].id);
                    const p2 = posMap.get(positions[j].id);
                    
                    const dx = p2.x - p1.x;
                    const dy = p2.y - p1.y;
                    const dist = Math.sqrt(dx * dx + dy * dy) || 1;
                    
                    // φ-weighted repulsion
                    const repulsion = (PHI * 10000) / (dist * dist);
                    const fx = (dx / dist) * repulsion;
                    const fy = (dy / dist) * repulsion;
                    
                    forces.get(positions[i].id).fx -= fx;
                    forces.get(positions[i].id).fy -= fy;
                    forces.get(positions[j].id).fx += fx;
                    forces.get(positions[j].id).fy += fy;
                }
            }
            
            // Attraction along edges (φ-weighted)
            for (const edge of edges) {
                const p1 = posMap.get(edge.source);
                const p2 = posMap.get(edge.target);
                if (!p1 || !p2) continue;
                
                const dx = p2.x - p1.x;
                const dy = p2.y - p1.y;
                const dist = Math.sqrt(dx * dx + dy * dy) || 1;
                
                // φ-optimal distance
                const optimalDist = 100 * PHI;
                const attraction = (dist - optimalDist) * PHI_INV * 0.1;
                const fx = (dx / dist) * attraction;
                const fy = (dy / dist) * attraction;
                
                forces.get(edge.source).fx += fx;
                forces.get(edge.source).fy += fy;
                forces.get(edge.target).fx -= fx;
                forces.get(edge.target).fy -= fy;
            }
            
            // Apply forces with φ-damping
            const damping = PHI_INV * Math.pow(PHI_INV, iter / iterations);
            
            for (const p of positions) {
                const f = forces.get(p.id);
                const pos = posMap.get(p.id);
                
                pos.x += f.fx * damping;
                pos.y += f.fy * damping;
                
                // Boundary constraints
                pos.x = Math.max(50, Math.min(bounds.width - 50, pos.x));
                pos.y = Math.max(50, Math.min(bounds.height - 50, pos.y));
            }
        }
        
        return positions.map(p => ({
            id: p.id,
            x: posMap.get(p.id).x,
            y: posMap.get(p.id).y
        }));
    }
    
    parseLayoutResponse(response, nodes) {
        try {
            const jsonMatch = response.match(/\[[\s\S]*\]/);
            if (jsonMatch) {
                const layout = JSON.parse(jsonMatch[0]);
                // Validate and fill missing positions
                const layoutMap = new Map(layout.map(l => [l.id, l]));
                return nodes.map((n, i) => {
                    if (layoutMap.has(n.id)) {
                        return layoutMap.get(n.id);
                    }
                    // Fallback position
                    return {
                        id: n.id,
                        x: 100 + (i % 10) * 100,
                        y: 100 + Math.floor(i / 10) * 100
                    };
                });
            }
        } catch (e) {
            console.warn('Failed to parse layout response:', e);
        }
        
        // Fallback to φ-layout
        return this.generatePhiLayout(nodes, [], {});
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // CONTENT GENERATION
    // ═══════════════════════════════════════════════════════════════════════════
    
    /**
     * Generate labels and descriptions for nodes
     */
    async generateLabels(nodes, context = '') {
        const prompt = `Generate concise, meaningful labels for data structure nodes.

CONTEXT: ${context || 'Generic data structure visualization'}

NODES TO LABEL:
${nodes.map(n => `- ID: ${n.id}, Type: ${n.type || 'node'}, Current: ${n.label || 'unlabeled'}`).join('\n')}

GUIDELINES:
- Labels should be 1-3 words
- Use domain-appropriate terminology
- Maintain φ-harmonic naming (balanced, proportional)

Return JSON: [{id, label, description}]`;

        const response = await this.callAI(prompt, {
            temperature: PHI_INV,
            maxTokens: nodes.length * 30
        });
        
        try {
            const jsonMatch = response.match(/\[[\s\S]*\]/);
            if (jsonMatch) {
                return JSON.parse(jsonMatch[0]);
            }
        } catch (e) {
            console.warn('Failed to parse labels:', e);
        }
        
        // Fallback
        return nodes.map(n => ({
            id: n.id,
            label: n.label || `Node ${n.id}`,
            description: `φ-optimized node`
        }));
    }
    
    /**
     * Generate code from data structure
     */
    async generateCode(structure, language = 'javascript') {
        const prompt = `Convert this data structure to ${language} code.

STRUCTURE:
${JSON.stringify(structure, null, 2)}

REQUIREMENTS:
- Use φ-optimized algorithms where applicable
- Include comments explaining φ relationships
- Follow ${language} best practices
- Make code immediately runnable

Return only the code, no explanations.`;

        const response = await this.callAI(prompt, {
            temperature: 0.2, // Low for precise code
            maxTokens: 2000
        });
        
        // Extract code block
        const codeMatch = response.match(/```(?:\w+)?\n([\s\S]*?)```/);
        return codeMatch ? codeMatch[1].trim() : response.trim();
    }
    
    /**
     * Generate documentation for structure
     */
    async generateDocumentation(structure, format = 'markdown') {
        const prompt = `Generate ${format} documentation for this φ-optimized data structure.

STRUCTURE:
${JSON.stringify(structure, null, 2)}

INCLUDE:
1. Overview with φ-optimization explanation
2. Node descriptions
3. Edge relationships
4. Usage examples
5. Complexity analysis (with φ factors)

Use TRINITY principles: φ² + 1/φ² = 3`;

        const response = await this.callAI(prompt, {
            temperature: PHI_INV,
            maxTokens: 1500
        });
        
        return response;
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // SMART SUGGESTIONS
    // ═══════════════════════════════════════════════════════════════════════════
    
    /**
     * Get AI suggestions for improving structure
     */
    async getSuggestions(structure, goal = 'optimize') {
        const prompt = `Analyze this data structure and suggest improvements.

STRUCTURE:
${JSON.stringify(structure, null, 2)}

GOAL: ${goal}

ANALYZE FOR:
1. φ-optimization opportunities
2. Structural balance (TRINITY: φ² + 1/φ² = 3)
3. Performance improvements
4. Visual harmony

Return JSON: {
  suggestions: [{type, description, impact, implementation}],
  phi_score: 0-1,
  balance_score: 0-1,
  overall_rating: 0-1
}`;

        const response = await this.callAI(prompt, {
            temperature: PHI_INV,
            maxTokens: 1000
        });
        
        try {
            const jsonMatch = response.match(/\{[\s\S]*\}/);
            if (jsonMatch) {
                return JSON.parse(jsonMatch[0]);
            }
        } catch (e) {
            console.warn('Failed to parse suggestions:', e);
        }
        
        return {
            suggestions: [
                {
                    type: 'phi-optimization',
                    description: 'Apply golden ratio to node weights',
                    impact: 'high',
                    implementation: 'Multiply weights by φ^level'
                }
            ],
            phi_score: 0.618,
            balance_score: 0.618,
            overall_rating: 0.618
        };
    }
    
    /**
     * Auto-complete structure based on pattern
     */
    async autoComplete(partialStructure, targetSize = null) {
        const currentSize = partialStructure.nodes?.length || 0;
        const target = targetSize || this.nextFibonacci(currentSize);
        
        const prompt = `Complete this partial data structure to ${target} nodes.

CURRENT STRUCTURE:
${JSON.stringify(partialStructure, null, 2)}

REQUIREMENTS:
- Maintain existing patterns
- Use φ-proportional growth
- Add ${target - currentSize} new nodes
- Create appropriate edges

Return complete structure in same JSON format.`;

        const response = await this.callAI(prompt, {
            temperature: PHI_INV,
            maxTokens: 2000
        });
        
        try {
            const jsonMatch = response.match(/\{[\s\S]*\}/);
            if (jsonMatch) {
                return JSON.parse(jsonMatch[0]);
            }
        } catch (e) {
            console.warn('Failed to parse auto-complete:', e);
        }
        
        // Fallback: simple expansion
        return this.expandStructure(partialStructure, target);
    }
    
    expandStructure(structure, targetSize) {
        const nodes = [...(structure.nodes || [])];
        const edges = [...(structure.edges || [])];
        const currentSize = nodes.length;
        
        for (let i = currentSize; i < targetSize; i++) {
            const newNode = {
                id: `node_${i}`,
                label: `Node ${i}`,
                value: PHI ** (-(i - currentSize)),
                type: 'generated',
                phi_weight: PHI_INV ** (i - currentSize)
            };
            nodes.push(newNode);
            
            // Connect to existing node using φ-selection
            const parentIndex = Math.floor(i * PHI_INV) % currentSize;
            if (parentIndex < nodes.length) {
                edges.push({
                    source: nodes[parentIndex].id,
                    target: newNode.id,
                    weight: PHI_INV,
                    type: 'generated'
                });
            }
        }
        
        return {
            ...structure,
            nodes,
            edges,
            metadata: {
                ...structure.metadata,
                expanded: true,
                expansion_factor: targetSize / currentSize
            }
        };
    }
    
    nextFibonacci(n) {
        const fibs = [1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987];
        for (const f of fibs) {
            if (f > n) return f;
        }
        return Math.ceil(n * PHI);
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // φ-OPTIMIZATION
    // ═══════════════════════════════════════════════════════════════════════════
    
    /**
     * Apply φ-optimization to any structure
     */
    applyPhiOptimization(structure) {
        if (!structure || !structure.nodes) return structure;
        
        const optimized = JSON.parse(JSON.stringify(structure));
        
        // Optimize node weights
        optimized.nodes = optimized.nodes.map((node, i) => ({
            ...node,
            phi_weight: node.phi_weight || PHI ** (-i * 0.1),
            phi_level: Math.floor(Math.log(i + 1) / Math.log(PHI))
        }));
        
        // Optimize edge weights
        if (optimized.edges) {
            optimized.edges = optimized.edges.map((edge, i) => ({
                ...edge,
                weight: edge.weight || this.fibonacci(i % 10 + 1) / this.fibonacci(10),
                phi_factor: PHI_INV ** (i * 0.1)
            }));
        }
        
        // Add φ-metadata
        optimized.metadata = {
            ...optimized.metadata,
            phi_optimized: true,
            phi_ratio: PHI,
            trinity_verified: true,
            optimization_timestamp: Date.now()
        };
        
        return optimized;
    }
    
    fibonacci(n) {
        if (n <= 1) return n;
        let a = 0, b = 1;
        for (let i = 2; i <= n; i++) [a, b] = [b, a + b];
        return b;
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // API COMMUNICATION
    // ═══════════════════════════════════════════════════════════════════════════
    
    async callAI(prompt, options = {}) {
        // Try local model first
        if (this.localModel) {
            try {
                return await this.callLocalModel(prompt, options);
            } catch (e) {
                console.warn('Local model failed, falling back to API:', e);
            }
        }
        
        // Fall back to API
        if (!this.apiKey) {
            console.warn('No API key configured, using fallback generation');
            return this.generateFallbackResponse(prompt);
        }
        
        try {
            const response = await fetch(`${this.apiEndpoint}/chat/completions`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${this.apiKey}`
                },
                body: JSON.stringify({
                    model: this.model,
                    messages: [
                        {
                            role: 'system',
                            content: `You are TRINITY AI, specialized in φ-optimized data structures. φ = ${PHI}, φ² + 1/φ² = 3.`
                        },
                        { role: 'user', content: prompt }
                    ],
                    temperature: options.temperature || this.temperature,
                    max_tokens: options.maxTokens || this.maxTokens
                })
            });
            
            if (!response.ok) {
                throw new Error(`API error: ${response.status}`);
            }
            
            const data = await response.json();
            return data.choices[0].message.content;
        } catch (e) {
            console.error('API call failed:', e);
            return this.generateFallbackResponse(prompt);
        }
    }
    
    async callLocalModel(prompt, options) {
        // WebLLM or similar local model integration
        if (typeof window !== 'undefined' && window.webllm) {
            const engine = await window.webllm.CreateEngine(this.localModel);
            const response = await engine.chat.completions.create({
                messages: [{ role: 'user', content: prompt }],
                temperature: options.temperature || this.temperature,
                max_tokens: options.maxTokens || this.maxTokens
            });
            return response.choices[0].message.content;
        }
        throw new Error('Local model not available');
    }
    
    generateFallbackResponse(prompt) {
        // Simple pattern-based fallback
        if (prompt.includes('data structure')) {
            return JSON.stringify(this.generateFallbackStructure());
        }
        if (prompt.includes('layout') || prompt.includes('position')) {
            return '[]';
        }
        if (prompt.includes('suggestion')) {
            return JSON.stringify({
                suggestions: [{ type: 'phi', description: 'Apply φ-optimization', impact: 'medium' }],
                phi_score: PHI_INV
            });
        }
        return 'φ-optimized response';
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // CACHING
    // ═══════════════════════════════════════════════════════════════════════════
    
    hashPrompt(prompt) {
        let hash = 0;
        for (let i = 0; i < prompt.length; i++) {
            const char = prompt.charCodeAt(i);
            hash = ((hash << 5) - hash) + char;
            hash = hash & hash;
        }
        return hash.toString(36);
    }
    
    cacheResult(key, value) {
        if (this.cache.size >= this.cacheMaxSize) {
            // Remove oldest entry (FIFO)
            const firstKey = this.cache.keys().next().value;
            this.cache.delete(firstKey);
        }
        this.cache.set(key, value);
    }
    
    clearCache() {
        this.cache.clear();
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // STATISTICS
    // ═══════════════════════════════════════════════════════════════════════════
    
    updateStats(startTime) {
        const duration = performance.now() - startTime;
        this.stats.totalGenerations++;
        this.stats.avgGenerationTime = 
            (this.stats.avgGenerationTime * (this.stats.totalGenerations - 1) + duration) / 
            this.stats.totalGenerations;
    }
    
    getStats() {
        return {
            ...this.stats,
            cacheSize: this.cache.size,
            cacheHitRate: this.stats.totalGenerations > 0 
                ? this.stats.cacheHits / this.stats.totalGenerations 
                : 0
        };
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROMPT TEMPLATES
// ═══════════════════════════════════════════════════════════════════════════════

const PromptTemplates = {
    STRUCTURE_ANALYSIS: `Analyze this structure for φ-optimization opportunities:
{structure}

Identify:
1. Nodes that could benefit from φ-weighting
2. Edges that should follow Fibonacci proportions
3. Hierarchical levels that match golden sections`,

    VISUAL_HARMONY: `Evaluate visual harmony of this layout:
{layout}

Score based on:
1. Golden ratio proportions (φ = ${PHI})
2. Balanced distribution
3. TRINITY principle (φ² + 1/φ² = 3)`,

    CODE_OPTIMIZATION: `Optimize this code using φ-principles:
{code}

Apply:
1. φ-based loop unrolling
2. Golden ratio cache sizing
3. Fibonacci-sequence iterations`
};

// ═══════════════════════════════════════════════════════════════════════════════
// EXPORTS
// ═══════════════════════════════════════════════════════════════════════════════

const aiGenerator = new TrinityAIGenerator();

if (typeof window !== 'undefined') {
    window.TrinityAI = {
        generator: aiGenerator,
        Generator: TrinityAIGenerator,
        templates: PromptTemplates,
        PHI, PHI_INV, PHI_SQ, TRINITY
    };
}

export {
    TrinityAIGenerator,
    PromptTemplates,
    aiGenerator,
    PHI, PHI_INV, PHI_SQ, TRINITY
};

console.log(`
╔═══════════════════════════════════════════════════════════════════════════════╗
║                      TRINITY v24.φ - AI Content Generator                     ║
║                                                                               ║
║  φ = ${PHI}                                                        ║
║  φ² + 1/φ² = 3 (TRINITY Identity)                                             ║
║                                                                               ║
║  Features:                                                                    ║
║  • Data structure generation from natural language                            ║
║  • φ-optimized layout algorithms                                              ║
║  • Smart suggestions and auto-completion                                      ║
║  • Code and documentation generation                                          ║
╚═══════════════════════════════════════════════════════════════════════════════╝
`);
