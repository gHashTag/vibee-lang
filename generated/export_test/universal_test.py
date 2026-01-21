"""
═══════════════════════════════════════════════════════════════════════════════
UNIVERSAL TEST - Python
Generated from universal_test.vibee
φ² + 1/φ² = 3 | PHOENIX = 999
═══════════════════════════════════════════════════════════════════════════════
"""

from dataclasses import dataclass
from typing import Optional

# ═══════════════════════════════════════════════════════════════════════════════
# TYPES
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class Point:
    x: float
    y: float

@dataclass
class Rectangle:
    origin: Point
    width: float
    height: float

@dataclass
class Color:
    r: int
    g: int
    b: int
    a: int

@dataclass
class Shape:
    name: str
    rect: Rectangle
    color: Color
    visible: bool

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

def create_point(x: float, y: float) -> Point:
    return Point(x=x, y=y)

def create_rectangle(origin: Point, width: float, height: float) -> Rectangle:
    return Rectangle(origin=origin, width=width, height=height)

def calculate_area(rect: Rectangle) -> float:
    return rect.width * rect.height

def move_shape(shape: Shape, dx: float, dy: float) -> None:
    shape.rect.origin.x += dx
    shape.rect.origin.y += dy

def set_color(shape: Shape, color: Color) -> None:
    shape.color = color

def toggle_visibility(shape: Shape) -> None:
    shape.visible = not shape.visible

def clone_shape(shape: Shape) -> Shape:
    return Shape(
        name=shape.name,
        rect=Rectangle(
            origin=Point(x=shape.rect.origin.x, y=shape.rect.origin.y),
            width=shape.rect.width,
            height=shape.rect.height
        ),
        color=Color(r=shape.color.r, g=shape.color.g, b=shape.color.b, a=shape.color.a),
        visible=shape.visible
    )

def destroy_shape(shape: Shape) -> None:
    pass  # Python has garbage collection

# ═══════════════════════════════════════════════════════════════════════════════
# TESTS
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    # Test Point
    p = create_point(1.0, 2.0)
    assert p.x == 1.0
    assert p.y == 2.0
    print("✅ Point test passed")
    
    # Test Rectangle
    r = create_rectangle(p, 10.0, 5.0)
    assert calculate_area(r) == 50.0
    print("✅ Rectangle test passed")
    
    # Test Shape
    s = Shape(
        name="test",
        rect=r,
        color=Color(r=255, g=0, b=0, a=255),
        visible=True
    )
    move_shape(s, 5.0, 5.0)
    assert s.rect.origin.x == 6.0
    print("✅ Shape test passed")
    
    print("All tests passed!")
