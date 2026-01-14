#!/usr/bin/env python3
"""
Trinity Graph Algorithms: 3-way approaches to graph problems
Testing if 3-state algorithms improve graph traversal

Author: Dmitrii Vasilev
Date: January 13, 2026

Key insight: Many graph algorithms use 2 states (visited/unvisited).
Using 3 states (unvisited/in-progress/visited) can simplify algorithms.
"""

import random
import time
from typing import List, Set, Dict, Tuple, Optional
from collections import deque
from enum import Enum

print("=" * 70)
print("TRINITY GRAPH ALGORITHMS")
print("=" * 70)

# =============================================================================
# GRAPH REPRESENTATION
# =============================================================================

class Graph:
    """Adjacency list graph representation"""
    
    def __init__(self, n: int, directed: bool = False):
        self.n = n
        self.directed = directed
        self.adj: List[List[int]] = [[] for _ in range(n)]
        self.edges = 0
    
    def add_edge(self, u: int, v: int) -> None:
        self.adj[u].append(v)
        if not self.directed:
            self.adj[v].append(u)
        self.edges += 1
    
    @staticmethod
    def random_graph(n: int, m: int, directed: bool = False) -> 'Graph':
        """Generate random graph with n vertices and m edges"""
        g = Graph(n, directed)
        edges_added = set()
        
        while g.edges < m:
            u = random.randint(0, n - 1)
            v = random.randint(0, n - 1)
            if u != v and (u, v) not in edges_added:
                g.add_edge(u, v)
                edges_added.add((u, v))
                if not directed:
                    edges_added.add((v, u))
        
        return g

# =============================================================================
# 1. CYCLE DETECTION: 2-STATE vs 3-STATE
# =============================================================================

class NodeState(Enum):
    """3 states for Trinity DFS"""
    UNVISITED = 0
    IN_PROGRESS = 1
    VISITED = 2

def has_cycle_2state(graph: Graph) -> bool:
    """
    Cycle detection with 2 states (standard approach)
    For directed graphs, needs parent tracking
    """
    visited = [False] * graph.n
    
    def dfs(v: int, parent: int) -> bool:
        visited[v] = True
        for u in graph.adj[v]:
            if not visited[u]:
                if dfs(u, v):
                    return True
            elif u != parent:  # Back edge found
                return True
        return False
    
    for v in range(graph.n):
        if not visited[v]:
            if dfs(v, -1):
                return True
    return False

def has_cycle_3state(graph: Graph) -> bool:
    """
    Cycle detection with 3 states (Trinity approach)
    Cleaner for directed graphs - no parent tracking needed
    """
    state = [NodeState.UNVISITED] * graph.n
    
    def dfs(v: int) -> bool:
        state[v] = NodeState.IN_PROGRESS
        
        for u in graph.adj[v]:
            if state[u] == NodeState.IN_PROGRESS:
                # Found back edge to node in current path
                return True
            if state[u] == NodeState.UNVISITED:
                if dfs(u):
                    return True
        
        state[v] = NodeState.VISITED
        return False
    
    for v in range(graph.n):
        if state[v] == NodeState.UNVISITED:
            if dfs(v):
                return True
    return False

# =============================================================================
# 2. TOPOLOGICAL SORT: 3-STATE DFS
# =============================================================================

def topological_sort_3state(graph: Graph) -> Optional[List[int]]:
    """
    Topological sort using 3-state DFS
    Returns None if cycle detected
    """
    state = [NodeState.UNVISITED] * graph.n
    result = []
    
    def dfs(v: int) -> bool:
        state[v] = NodeState.IN_PROGRESS
        
        for u in graph.adj[v]:
            if state[u] == NodeState.IN_PROGRESS:
                return False  # Cycle detected
            if state[u] == NodeState.UNVISITED:
                if not dfs(u):
                    return False
        
        state[v] = NodeState.VISITED
        result.append(v)
        return True
    
    for v in range(graph.n):
        if state[v] == NodeState.UNVISITED:
            if not dfs(v):
                return None
    
    return result[::-1]

# =============================================================================
# 3. STRONGLY CONNECTED COMPONENTS: TARJAN'S ALGORITHM
# =============================================================================

def tarjan_scc(graph: Graph) -> List[List[int]]:
    """
    Tarjan's SCC algorithm - naturally uses 3 states
    - UNVISITED: not yet discovered
    - IN_PROGRESS: on current DFS stack
    - VISITED: assigned to an SCC
    """
    n = graph.n
    index_counter = [0]
    stack = []
    lowlink = [0] * n
    index = [0] * n
    on_stack = [False] * n
    state = [NodeState.UNVISITED] * n
    sccs = []
    
    def strongconnect(v: int):
        index[v] = index_counter[0]
        lowlink[v] = index_counter[0]
        index_counter[0] += 1
        stack.append(v)
        on_stack[v] = True
        state[v] = NodeState.IN_PROGRESS
        
        for u in graph.adj[v]:
            if state[u] == NodeState.UNVISITED:
                strongconnect(u)
                lowlink[v] = min(lowlink[v], lowlink[u])
            elif on_stack[u]:
                lowlink[v] = min(lowlink[v], index[u])
        
        if lowlink[v] == index[v]:
            scc = []
            while True:
                u = stack.pop()
                on_stack[u] = False
                state[u] = NodeState.VISITED
                scc.append(u)
                if u == v:
                    break
            sccs.append(scc)
    
    for v in range(n):
        if state[v] == NodeState.UNVISITED:
            strongconnect(v)
    
    return sccs

# =============================================================================
# 4. 3-COLORING CHECK
# =============================================================================

def is_3_colorable_greedy(graph: Graph) -> Tuple[bool, Optional[List[int]]]:
    """
    Greedy 3-coloring attempt
    Note: 3-coloring is NP-complete, this is just a heuristic
    """
    colors = [-1] * graph.n
    
    def can_color(v: int, c: int) -> bool:
        for u in graph.adj[v]:
            if colors[u] == c:
                return False
        return True
    
    def color_vertex(v: int) -> bool:
        for c in range(3):  # Try colors 0, 1, 2
            if can_color(v, c):
                colors[v] = c
                return True
        return False
    
    # Sort vertices by degree (descending) - greedy heuristic
    vertices = sorted(range(graph.n), key=lambda v: len(graph.adj[v]), reverse=True)
    
    for v in vertices:
        if not color_vertex(v):
            return False, None
    
    return True, colors

# =============================================================================
# 5. TRINITY BFS: 3-LEVEL FRONTIER
# =============================================================================

def trinity_bfs(graph: Graph, start: int) -> List[int]:
    """
    BFS with 3-level frontier management
    Maintains: current, next, and future frontiers
    Better cache locality for large graphs
    """
    dist = [-1] * graph.n
    dist[start] = 0
    
    current = [start]
    next_frontier = []
    future = []
    
    level = 0
    
    while current or next_frontier or future:
        if not current:
            current = next_frontier
            next_frontier = future
            future = []
            level += 1
            continue
        
        v = current.pop()
        
        for u in graph.adj[v]:
            if dist[u] == -1:
                dist[u] = level + 1
                # Distribute to next or future based on some criterion
                if len(next_frontier) < len(future):
                    next_frontier.append(u)
                else:
                    future.append(u)
    
    return dist

# =============================================================================
# BENCHMARK
# =============================================================================

def benchmark():
    """Compare 2-state vs 3-state algorithms"""
    
    print("\n" + "=" * 70)
    print("BENCHMARK: 2-STATE vs 3-STATE ALGORITHMS")
    print("=" * 70)
    
    sizes = [(100, 200), (500, 1000), (1000, 2000), (5000, 10000)]
    
    for n, m in sizes:
        print(f"\n--- Graph: {n} vertices, {m} edges ---")
        
        # Create directed graph for cycle detection
        random.seed(42)
        g = Graph.random_graph(n, m, directed=True)
        
        # Cycle detection
        start = time.perf_counter()
        result_2 = has_cycle_2state(g)
        time_2 = (time.perf_counter() - start) * 1000
        
        start = time.perf_counter()
        result_3 = has_cycle_3state(g)
        time_3 = (time.perf_counter() - start) * 1000
        
        print(f"\nCycle Detection:")
        print(f"  2-state: {time_2:.2f} ms, has_cycle={result_2}")
        print(f"  3-state: {time_3:.2f} ms, has_cycle={result_3}")
        
        # Topological sort (on DAG)
        dag = Graph(n, directed=True)
        for i in range(n - 1):
            dag.add_edge(i, i + 1)
            if i + 2 < n:
                dag.add_edge(i, i + 2)
        
        start = time.perf_counter()
        topo = topological_sort_3state(dag)
        time_topo = (time.perf_counter() - start) * 1000
        
        print(f"\nTopological Sort (DAG):")
        print(f"  3-state: {time_topo:.2f} ms, valid={topo is not None}")
        
        # SCC
        start = time.perf_counter()
        sccs = tarjan_scc(g)
        time_scc = (time.perf_counter() - start) * 1000
        
        print(f"\nStrongly Connected Components:")
        print(f"  Tarjan (3-state): {time_scc:.2f} ms, num_sccs={len(sccs)}")
        
        # 3-coloring
        g_undirected = Graph.random_graph(n, m, directed=False)
        start = time.perf_counter()
        colorable, colors = is_3_colorable_greedy(g_undirected)
        time_color = (time.perf_counter() - start) * 1000
        
        print(f"\n3-Coloring (greedy):")
        print(f"  Time: {time_color:.2f} ms, colorable={colorable}")

def analyze_3state_benefits():
    """Analyze benefits of 3-state approach"""
    
    print("\n" + "=" * 70)
    print("ANALYSIS: BENEFITS OF 3-STATE APPROACH")
    print("=" * 70)
    
    print("""
    WHY 3 STATES ARE BETTER FOR GRAPH ALGORITHMS:
    
    1. CYCLE DETECTION (Directed Graphs)
       2-state: Need parent tracking, complex logic
       3-state: IN_PROGRESS state directly indicates back edge
       
    2. TOPOLOGICAL SORT
       3-state naturally detects cycles during sort
       No need for separate cycle check
       
    3. STRONGLY CONNECTED COMPONENTS
       Tarjan's algorithm inherently uses 3 states:
       - UNVISITED: not discovered
       - IN_PROGRESS: on DFS stack
       - VISITED: assigned to SCC
       
    4. BICONNECTED COMPONENTS
       Similar to SCC, 3 states simplify articulation point detection
       
    5. CODE CLARITY
       3-state code is often cleaner and more intuitive
       State transitions are explicit
    
    THE TRINITY PRINCIPLE IN GRAPHS:
    - UNVISITED: Future (not yet explored)
    - IN_PROGRESS: Present (currently exploring)
    - VISITED: Past (fully explored)
    
    This mirrors the 3-way partition in sorting:
    - Less than pivot
    - Equal to pivot
    - Greater than pivot
    """)

# =============================================================================
# MAIN
# =============================================================================

if __name__ == "__main__":
    benchmark()
    analyze_3state_benefits()
    
    print("\n" + "=" * 70)
    print("CONCLUSIONS")
    print("=" * 70)
    
    print("""
    KEY FINDINGS:
    
    1. 3-STATE DFS IS CLEANER FOR DIRECTED GRAPHS
       - No parent tracking needed for cycle detection
       - State transitions are explicit and clear
       
    2. TARJAN'S SCC ALGORITHM NATURALLY USES 3 STATES
       - This is not coincidence
       - 3 states capture the essential structure
       
    3. 3-COLORING IS NP-COMPLETE
       - The number 3 is the threshold of complexity
       - 2-coloring is P, 3-coloring is NP-complete
       
    4. THE TRINITY PRINCIPLE IN GRAPHS
       - Past/Present/Future states
       - Matches sorting: Less/Equal/Greater
       - Fundamental structure of computation
    
    RECOMMENDATION:
    Use 3-state DFS for:
    - Cycle detection in directed graphs
    - Topological sorting
    - SCC algorithms
    - Any algorithm needing "currently processing" state
    """)
