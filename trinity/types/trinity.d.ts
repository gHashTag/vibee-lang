/**
 * TRINITY Type Definitions v22.φ
 * TypeScript types for TRINITY modules
 * 
 * φ² + 1/φ² = 3
 */

// ═══════════════════════════════════════════════════════════════════════════════
// φ CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

export declare const PHI: 1.618033988749895;
export declare const PHI_INV: 0.618033988749895;
export declare const PHI_SQ: 2.618033988749895;
export declare const PHI_INV_SQ: 0.381966011250105;
export declare const TRINITY: 3;

export declare const FIB: readonly number[];

export declare function space(n: number): number;
export declare function font(base: number, level: number): number;
export declare function validateGoldenIdentity(): boolean;
export declare function fibonacci(n: number): number;
export declare function isGoldenRatio(a: number, b: number, tolerance?: number): boolean;
export declare function btreeBranchingFactor(): number;
export declare function cuckooLoadFactor(): number;
export declare function radixBucketRatio(): { primary: number; secondary: number };

// ═══════════════════════════════════════════════════════════════════════════════
// TABLE RENDERER
// ═══════════════════════════════════════════════════════════════════════════════

export interface TableData {
  headers: string[];
  rows: string[][];
}

export interface TableOptions {
  cellW?: number;
  cellH?: number;
  fontSize?: number;
  isDark?: boolean;
  headerBg?: string;
  borderColor?: string;
  textColor?: string;
  headerColor?: string;
}

export interface TableResult {
  width: number;
  height: number;
}

export declare function renderTable(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  data: TableData,
  options?: TableOptions
): TableResult;

export declare function optimalCellWidth(contentWidth: number, columns: number): number;
export declare function optimalCellHeight(fontSize: number): number;

// ═══════════════════════════════════════════════════════════════════════════════
// DIAGRAM RENDERER
// ═══════════════════════════════════════════════════════════════════════════════

export interface DiagramNode {
  id: string;
  label: string;
  row?: number;
  col?: number;
  shape?: 'rect' | 'diamond' | 'circle';
  highlight?: boolean;
}

export interface DiagramEdge {
  from: string;
  to: string;
  label?: string;
}

export interface DiagramOptions {
  nodeW?: number;
  nodeH?: number;
  fontSize?: number;
  isDark?: boolean;
  direction?: 'TB' | 'LR';
}

export interface DiagramResult {
  width: number;
  height: number;
}

export declare function renderFlowchart(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  nodes: DiagramNode[],
  edges: DiagramEdge[],
  options?: DiagramOptions
): DiagramResult;

export interface SequenceActor {
  id: string;
  name: string;
}

export interface SequenceMessage {
  from: string;
  to: string;
  label: string;
}

export interface SequenceOptions {
  actorW?: number;
  actorH?: number;
  fontSize?: number;
  isDark?: boolean;
}

export declare function renderSequence(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  actors: SequenceActor[],
  messages: SequenceMessage[],
  options?: SequenceOptions
): DiagramResult;

export declare function optimalNodeWidth(label: string, fontSize: number): number;

// ═══════════════════════════════════════════════════════════════════════════════
// WASM COMPUTE
// ═══════════════════════════════════════════════════════════════════════════════

export interface WASMExports {
  getPhi(): number;
  getPhiInv(): number;
  getPhiSq(): number;
  validateGoldenIdentity(): boolean;
  space(n: number): number;
  fibonacci(n: number): bigint;
  isGoldenRatio(a: number, b: number): boolean;
  btreeBranchingFactor(): number;
  cuckooLoadFactor(): number;
  bezierPoint(p0: number, p1: number, p2: number, p3: number, t: number): number;
  phiBezierControl(start: number, end: number): number;
  benchmarkFibonacci(iterations: number): bigint;
  benchmarkSpacing(iterations: number): bigint;
}

export interface WASMCompute {
  instance: WebAssembly.Instance | null;
  loaded: boolean;
  load(): Promise<WASMExports | null>;
  getPhi(): number;
  getPhiSq(): number;
  validateGoldenIdentity(): boolean;
  fibonacci(n: number): number;
  space(n: number): number;
  benchmark(iterations?: number): Promise<{
    iterations: number;
    wasmMs: string;
    jsMs: string;
    speedup: string;
    wasmLoaded: boolean;
  }>;
}

export declare const WASMCompute: WASMCompute;

// ═══════════════════════════════════════════════════════════════════════════════
// I18N
// ═══════════════════════════════════════════════════════════════════════════════

export type LanguageCode = 'en' | 'ru' | 'zh' | 'ja' | 'de' | 'fr' | 'es' | 'pt' | 'ko' | 'ar';

export interface I18n {
  LANGUAGES: Record<LanguageCode, string>;
  init(lang?: LanguageCode | null): LanguageCode;
  getLang(): LanguageCode;
  setLang(lang: LanguageCode): boolean;
  t(key: string, params?: Record<string, string | number>): string;
  hasTranslation(key: string): boolean;
  getAllTranslations(): Record<string, string>;
  addTranslations(lang: LanguageCode, strings: Record<string, string>): void;
}

export declare const i18n: I18n;

// ═══════════════════════════════════════════════════════════════════════════════
// ML LAYOUT
// ═══════════════════════════════════════════════════════════════════════════════

export interface MLLayoutWeights {
  scrollDepth: number;
  timeOnSection: number;
  clickRate: number;
  returnRate: number;
  deviceType: number;
}

export interface SectionScore {
  views: number;
  totalTime: number;
  score: number;
}

export interface MLLayoutRecommendations {
  topSections: Array<{ name: string; score: string }>;
  scrollBehavior: {
    avgDepth: string;
    recommendation: string;
  };
  weights: Record<string, string>;
  stats: {
    totalInteractions: number;
    totalViews: number;
    sectionsTracked: number;
  };
}

export interface MLLayoutOptimizer {
  weights: MLLayoutWeights;
  sectionScores: Record<string, SectionScore>;
  learningRate: number;
  
  recordInteraction(type: string, data: object): void;
  recordScroll(scrollY: number, maxScroll: number): void;
  recordSectionView(section: string, duration: number): void;
  recordClick(target: string, position: { x: number; y: number }): void;
  getOptimizedOrder(sections: string[]): string[];
  getSectionScore(section: string): number;
  getOptimizedHeight(section: string, baseHeight: number): number;
  getRecommendations(): MLLayoutRecommendations;
  saveState(): void;
  loadState(): void;
  reset(): void;
}

export declare const mlLayout: MLLayoutOptimizer;

// ═══════════════════════════════════════════════════════════════════════════════
// COLLABORATION
// ═══════════════════════════════════════════════════════════════════════════════

export interface CRDTCounter {
  nodeId: string;
  increments: Record<string, number>;
  decrements: Record<string, number>;
  
  increment(): void;
  decrement(): void;
  value(): number;
  merge(other: CRDTCounter): void;
  toJSON(): { increments: Record<string, number>; decrements: Record<string, number> };
}

export interface CRDTRegister<T> {
  nodeId: string;
  value: T | null;
  timestamp: number;
  
  set(value: T): void;
  get(): T | null;
  merge(other: CRDTRegister<T>): void;
  toJSON(): { value: T | null; timestamp: number };
}

export interface CollaborationState {
  scrollPosition: CRDTRegister<number>;
  activeSection: CRDTRegister<string>;
  theme: CRDTRegister<string>;
  viewCount: CRDTCounter;
}

export interface Cursor {
  x: number;
  y: number;
  timestamp: number;
}

export interface CollaborationManager {
  nodeId: string;
  connected: boolean;
  state: CollaborationState;
  cursors: Map<string, Cursor>;
  
  connect(wsUrl: string): Promise<void>;
  disconnect(): void;
  updateScroll(scrollY: number): void;
  updateSection(section: string): void;
  updateCursor(x: number, y: number): void;
  incrementViews(): void;
  getViewCount(): number;
  getCursors(): Array<{ nodeId: string } & Cursor>;
  on(event: string, handler: (data: any) => void): void;
}

export declare const collaboration: CollaborationManager;

// ═══════════════════════════════════════════════════════════════════════════════
// PLUGINS
// ═══════════════════════════════════════════════════════════════════════════════

export type PluginPhase = 
  | 'registered'
  | 'initializing'
  | 'active'
  | 'suspended'
  | 'unloading'
  | 'unloaded'
  | 'error';

export type PluginHook =
  | 'beforeInit'
  | 'afterInit'
  | 'beforeRender'
  | 'afterRender'
  | 'onScroll'
  | 'onResize'
  | 'onTabChange'
  | 'onThemeChange'
  | 'onDataLoad'
  | 'onDataSave'
  | 'custom';

export interface PluginManifest {
  id: string;
  name: string;
  version: string;
  description?: string;
  author?: string;
  dependencies?: string[];
  hooks?: Partial<Record<PluginHook, (data: any) => any>>;
}

export interface Plugin extends PluginManifest {
  phase: PluginPhase;
  error: string | null;
  
  init(): Promise<void>;
  cleanup(): Promise<void>;
  render(ctx: CanvasRenderingContext2D, state: object): void;
  handleHook(hook: PluginHook, data: any): any;
}

export interface PluginManager {
  plugins: Map<string, Plugin>;
  loadOrder: string[];
  
  register(plugin: Plugin): boolean;
  unregister(pluginId: string): Promise<boolean>;
  initAll(): Promise<void>;
  initPlugin(pluginId: string): Promise<boolean>;
  on(hook: PluginHook, pluginId: string, handler: (data: any) => any): void;
  emit(hook: PluginHook, data: any): Promise<Array<{ pluginId: string; result: any }>>;
  renderAll(ctx: CanvasRenderingContext2D, state: object): void;
  get(pluginId: string): Plugin | undefined;
  getAll(): Plugin[];
  getActive(): Plugin[];
  getStatus(): {
    total: number;
    active: number;
    plugins: Array<{
      id: string;
      name: string;
      version: string;
      phase: PluginPhase;
      error: string | null;
    }>;
  };
}

export declare const pluginManager: PluginManager;
export declare function createPlugin(manifest: PluginManifest): Plugin;

// ═══════════════════════════════════════════════════════════════════════════════
// GLOBAL
// ═══════════════════════════════════════════════════════════════════════════════

declare global {
  interface Window {
    WASMCompute: WASMCompute;
    ArticleState: {
      scrollY: number;
      theme: 'dark' | 'light';
      lastW: number;
      lastH: number;
      layoutCache: object | null;
      dirtyRegions: {
        enabled: boolean;
        lastScrollY: number;
        visibleSections: Set<string>;
        dirtyRects: Array<{ x: number; y: number; w: number; h: number }>;
        fullRedrawNeeded: boolean;
        markDirty(x: number, y: number, w: number, h: number): void;
        scrollChanged(newScrollY: number, threshold?: number): boolean;
        getVisibleSections(scrollY: number, viewportH: number, sections: object): Set<string>;
        visibilityChanged(newVisible: Set<string>): boolean;
        shouldRedraw(sectionName: string): boolean;
        clearDirty(): void;
        forceFullRedraw(): void;
      };
    };
  }
}

export {};
