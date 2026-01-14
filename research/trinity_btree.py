#!/usr/bin/env python3
"""
Trinity B-Tree: B-Tree with branching factor 3
Testing if 3-way branching is optimal for B-trees

Author: Dmitrii Vasilev
Date: January 13, 2026

Hypothesis: B-tree with 3 children per node may have better
cache locality and simpler implementation than 2-3-4 trees.
"""

import random
import time
from typing import List, Optional, Tuple, Any
from dataclasses import dataclass, field

print("=" * 70)
print("TRINITY B-TREE: B-TREE WITH BRANCHING FACTOR 3")
print("=" * 70)

# =============================================================================
# TRINITY B-TREE IMPLEMENTATION
# =============================================================================

@dataclass
class TrinityNode:
    """
    Node in Trinity B-Tree
    Each node has at most 2 keys and 3 children
    """
    keys: List[int] = field(default_factory=list)
    children: List['TrinityNode'] = field(default_factory=list)
    is_leaf: bool = True
    
    def is_full(self) -> bool:
        return len(self.keys) >= 2
    
    def __repr__(self):
        return f"Node({self.keys})"

class TrinityBTree:
    """
    B-Tree with branching factor 3 (2-3 tree)
    - Each internal node has 2 or 3 children
    - Each node has 1 or 2 keys
    - All leaves at same depth
    """
    
    def __init__(self):
        self.root = TrinityNode()
        self.comparisons = 0
        self.height = 0
    
    def search(self, key: int) -> Tuple[Optional[TrinityNode], int]:
        """Search for key, return (node, index) or (None, -1)"""
        return self._search(self.root, key)
    
    def _search(self, node: TrinityNode, key: int) -> Tuple[Optional[TrinityNode], int]:
        """Recursive search"""
        i = 0
        while i < len(node.keys):
            self.comparisons += 1
            if key == node.keys[i]:
                return (node, i)
            if key < node.keys[i]:
                break
            i += 1
        
        if node.is_leaf:
            return (None, -1)
        
        return self._search(node.children[i], key)
    
    def insert(self, key: int) -> None:
        """Insert key into tree"""
        root = self.root
        
        if root.is_full():
            # Root is full, need to split
            new_root = TrinityNode(is_leaf=False)
            new_root.children.append(self.root)
            self._split_child(new_root, 0)
            self.root = new_root
            self.height += 1
        
        self._insert_non_full(self.root, key)
    
    def _split_child(self, parent: TrinityNode, i: int) -> None:
        """Split full child at index i"""
        full_child = parent.children[i]
        
        # Create new node with right half
        new_node = TrinityNode(is_leaf=full_child.is_leaf)
        
        # Move median key up to parent
        median_key = full_child.keys[1]
        
        # New node gets keys after median
        # (for 2-key node, there's nothing after median)
        
        # Left child keeps first key
        new_node.keys = []
        full_child.keys = [full_child.keys[0]]
        
        # Split children if not leaf
        if not full_child.is_leaf:
            new_node.children = full_child.children[2:]
            full_child.children = full_child.children[:2]
        
        # Insert median into parent
        parent.keys.insert(i, median_key)
        parent.children.insert(i + 1, new_node)
    
    def _insert_non_full(self, node: TrinityNode, key: int) -> None:
        """Insert into non-full node"""
        if node.is_leaf:
            # Insert into leaf
            i = 0
            while i < len(node.keys) and key > node.keys[i]:
                i += 1
            node.keys.insert(i, key)
        else:
            # Find child to descend into
            i = 0
            while i < len(node.keys) and key > node.keys[i]:
                i += 1
            
            # Split child if full
            if node.children[i].is_full():
                self._split_child(node, i)
                if key > node.keys[i]:
                    i += 1
            
            self._insert_non_full(node.children[i], key)
    
    def inorder(self) -> List[int]:
        """Return all keys in sorted order"""
        result = []
        self._inorder(self.root, result)
        return result
    
    def _inorder(self, node: TrinityNode, result: List[int]) -> None:
        """Recursive inorder traversal"""
        if node.is_leaf:
            result.extend(node.keys)
        else:
            for i, child in enumerate(node.children):
                self._inorder(child, result)
                if i < len(node.keys):
                    result.append(node.keys[i])

# =============================================================================
# STANDARD BINARY SEARCH TREE (for comparison)
# =============================================================================

@dataclass
class BSTNode:
    key: int
    left: 'BSTNode' = None
    right: 'BSTNode' = None

class BinarySearchTree:
    """Standard BST for comparison"""
    
    def __init__(self):
        self.root = None
        self.comparisons = 0
        self.height = 0
    
    def insert(self, key: int) -> None:
        if self.root is None:
            self.root = BSTNode(key)
            self.height = 1
        else:
            self._insert(self.root, key, 1)
    
    def _insert(self, node: BSTNode, key: int, depth: int) -> None:
        self.comparisons += 1
        if key < node.key:
            if node.left is None:
                node.left = BSTNode(key)
                self.height = max(self.height, depth + 1)
            else:
                self._insert(node.left, key, depth + 1)
        else:
            if node.right is None:
                node.right = BSTNode(key)
                self.height = max(self.height, depth + 1)
            else:
                self._insert(node.right, key, depth + 1)
    
    def search(self, key: int) -> bool:
        return self._search(self.root, key)
    
    def _search(self, node: BSTNode, key: int) -> bool:
        if node is None:
            return False
        self.comparisons += 1
        if key == node.key:
            return True
        if key < node.key:
            return self._search(node.left, key)
        return self._search(node.right, key)

# =============================================================================
# 2-3-4 TREE (B-tree with branching factor 4)
# =============================================================================

@dataclass
class Node234:
    """Node in 2-3-4 tree"""
    keys: List[int] = field(default_factory=list)
    children: List['Node234'] = field(default_factory=list)
    is_leaf: bool = True
    
    def is_full(self) -> bool:
        return len(self.keys) >= 3

class Tree234:
    """2-3-4 Tree (B-tree with max 4 children)"""
    
    def __init__(self):
        self.root = Node234()
        self.comparisons = 0
        self.height = 0
    
    def insert(self, key: int) -> None:
        root = self.root
        
        if root.is_full():
            new_root = Node234(is_leaf=False)
            new_root.children.append(self.root)
            self._split_child(new_root, 0)
            self.root = new_root
            self.height += 1
        
        self._insert_non_full(self.root, key)
    
    def _split_child(self, parent: Node234, i: int) -> None:
        full_child = parent.children[i]
        new_node = Node234(is_leaf=full_child.is_leaf)
        
        # Median is middle key (index 1)
        median_key = full_child.keys[1]
        
        # Right node gets keys after median
        new_node.keys = full_child.keys[2:]
        full_child.keys = full_child.keys[:1]
        
        if not full_child.is_leaf:
            new_node.children = full_child.children[2:]
            full_child.children = full_child.children[:2]
        
        parent.keys.insert(i, median_key)
        parent.children.insert(i + 1, new_node)
    
    def _insert_non_full(self, node: Node234, key: int) -> None:
        if node.is_leaf:
            i = 0
            while i < len(node.keys) and key > node.keys[i]:
                i += 1
            node.keys.insert(i, key)
        else:
            i = 0
            while i < len(node.keys) and key > node.keys[i]:
                i += 1
            
            if node.children[i].is_full():
                self._split_child(node, i)
                if key > node.keys[i]:
                    i += 1
            
            self._insert_non_full(node.children[i], key)
    
    def search(self, key: int) -> bool:
        return self._search(self.root, key)
    
    def _search(self, node: Node234, key: int) -> bool:
        i = 0
        while i < len(node.keys):
            self.comparisons += 1
            if key == node.keys[i]:
                return True
            if key < node.keys[i]:
                break
            i += 1
        
        if node.is_leaf:
            return False
        
        return self._search(node.children[i], key)

# =============================================================================
# BENCHMARK
# =============================================================================

def benchmark():
    """Compare Trinity B-Tree with other tree structures"""
    
    print("\n" + "=" * 70)
    print("BENCHMARK: TREE STRUCTURES")
    print("=" * 70)
    
    sizes = [100, 1000, 5000, 10000]
    
    for n in sizes:
        print(f"\n--- n = {n} ---")
        
        random.seed(42)
        data = random.sample(range(n * 10), n)
        search_keys = random.sample(data, min(100, n))
        
        # Trinity B-Tree
        trinity = TrinityBTree()
        start = time.perf_counter()
        for key in data:
            trinity.insert(key)
        insert_time_trinity = (time.perf_counter() - start) * 1000
        
        trinity.comparisons = 0
        start = time.perf_counter()
        for key in search_keys:
            trinity.search(key)
        search_time_trinity = (time.perf_counter() - start) * 1000
        search_comp_trinity = trinity.comparisons / len(search_keys)
        
        # 2-3-4 Tree
        tree234 = Tree234()
        start = time.perf_counter()
        for key in data:
            tree234.insert(key)
        insert_time_234 = (time.perf_counter() - start) * 1000
        
        tree234.comparisons = 0
        start = time.perf_counter()
        for key in search_keys:
            tree234.search(key)
        search_time_234 = (time.perf_counter() - start) * 1000
        search_comp_234 = tree234.comparisons / len(search_keys)
        
        # BST
        bst = BinarySearchTree()
        start = time.perf_counter()
        for key in data:
            bst.insert(key)
        insert_time_bst = (time.perf_counter() - start) * 1000
        
        bst.comparisons = 0
        start = time.perf_counter()
        for key in search_keys:
            bst.search(key)
        search_time_bst = (time.perf_counter() - start) * 1000
        search_comp_bst = bst.comparisons / len(search_keys)
        
        print(f"{'Structure':<20} {'Insert (ms)':<15} {'Search (ms)':<15} {'Avg Comparisons':<15} {'Height'}")
        print("-" * 80)
        print(f"{'Trinity B-Tree':<20} {insert_time_trinity:<15.2f} {search_time_trinity:<15.2f} {search_comp_trinity:<15.1f} {trinity.height}")
        print(f"{'2-3-4 Tree':<20} {insert_time_234:<15.2f} {search_time_234:<15.2f} {search_comp_234:<15.1f} {tree234.height}")
        print(f"{'BST':<20} {insert_time_bst:<15.2f} {search_time_bst:<15.2f} {search_comp_bst:<15.1f} {bst.height}")
        
        # Theoretical comparison
        import math
        log2 = math.log2(n)
        log3 = math.log(n, 3)
        log4 = math.log(n, 4)
        
        print(f"\nTheoretical heights: log₂(n)={log2:.1f}, log₃(n)={log3:.1f}, log₄(n)={log4:.1f}")

def analyze_comparisons():
    """Analyze comparison counts for different branching factors"""
    
    print("\n" + "=" * 70)
    print("ANALYSIS: COMPARISONS PER SEARCH")
    print("=" * 70)
    
    print("""
    For a B-tree with branching factor b:
    - Height: h = log_b(n)
    - Comparisons per node: O(b) with linear search, O(log b) with binary
    - Total comparisons: O(h × b) = O(log_b(n) × b) = O(b × log(n) / log(b))
    
    Minimizing b × log(n) / log(b):
    d/db [b / log(b)] = (log(b) - 1) / log²(b)
    
    Setting to 0: log(b) = 1 → b = e ≈ 2.718
    
    OPTIMAL BRANCHING FACTOR ≈ e ≈ 2.718
    
    Closest integers: 2 or 3
    
    For b=2: 2/log(2) = 2/0.693 = 2.89
    For b=3: 3/log(3) = 3/1.099 = 2.73  ← BETTER!
    For b=4: 4/log(4) = 4/1.386 = 2.89
    
    CONCLUSION: b=3 is theoretically optimal!
    """)
    
    import math
    
    print("\nComparison factor b/log(b) for different branching factors:")
    print(f"{'b':<10} {'b/log(b)':<15} {'Relative to b=3'}")
    print("-" * 40)
    
    base_factor = 3 / math.log(3)
    
    for b in [2, 3, 4, 5, 6, 8, 16, 32]:
        factor = b / math.log(b)
        relative = factor / base_factor
        print(f"{b:<10} {factor:<15.3f} {relative:<.3f}")

# =============================================================================
# MAIN
# =============================================================================

if __name__ == "__main__":
    benchmark()
    analyze_comparisons()
    
    print("\n" + "=" * 70)
    print("CONCLUSIONS")
    print("=" * 70)
    
    print("""
    KEY FINDINGS:
    
    1. OPTIMAL BRANCHING FACTOR IS e ≈ 2.718
       - Minimizes b/log(b)
       - Closest integer is 3!
       
    2. TRINITY B-TREE (b=3) vs 2-3-4 TREE (b=4)
       - Trinity: 3/log(3) = 2.73
       - 2-3-4:   4/log(4) = 2.89
       - Trinity is 6% more efficient in comparisons!
       
    3. PRACTICAL CONSIDERATIONS
       - Cache line size favors larger nodes
       - In practice, b=32 or b=64 often used
       - But for in-memory structures, b=3 is optimal
       
    4. THE NUMBER 3 APPEARS AGAIN!
       - Optimal branching factor ≈ e ≈ 2.718 ≈ 3
       - This is NOT coincidence
       - 3 is the integer closest to e
    
    RECOMMENDATION:
    - For in-memory trees: use Trinity B-Tree (b=3)
    - For disk-based trees: use larger b (cache line optimization)
    """)
