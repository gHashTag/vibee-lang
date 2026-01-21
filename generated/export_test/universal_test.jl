# ═══════════════════════════════════════════════════════════════════════════════
# UNIVERSAL TEST - Julia
# Generated from universal_test.vibee
# φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

module UniversalTest

# ═══════════════════════════════════════════════════════════════════════════════
# TYPES
# ═══════════════════════════════════════════════════════════════════════════════

struct Point
    x::Float64
    y::Float64
end

struct Rectangle
    origin::Point
    width::Float64
    height::Float64
end

struct Color
    r::Int64
    g::Int64
    b::Int64
    a::Int64
end

mutable struct Shape
    name::String
    rect::Rectangle
    color::Color
    visible::Bool
end

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

create_point(x::Float64, y::Float64) = Point(x, y)

create_rectangle(origin::Point, width::Float64, height::Float64) = Rectangle(origin, width, height)

calculate_area(rect::Rectangle) = rect.width * rect.height

function move_shape!(shape::Shape, dx::Float64, dy::Float64)
    new_origin = Point(shape.rect.origin.x + dx, shape.rect.origin.y + dy)
    shape.rect = Rectangle(new_origin, shape.rect.width, shape.rect.height)
end

function set_color!(shape::Shape, color::Color)
    shape.color = color
end

function toggle_visibility!(shape::Shape)
    shape.visible = !shape.visible
end

function clone_shape(shape::Shape)
    Shape(
        shape.name,
        Rectangle(Point(shape.rect.origin.x, shape.rect.origin.y), shape.rect.width, shape.rect.height),
        Color(shape.color.r, shape.color.g, shape.color.b, shape.color.a),
        shape.visible
    )
end

destroy_shape(shape::Shape) = nothing  # Julia has garbage collection

export Point, Rectangle, Color, Shape
export create_point, create_rectangle, calculate_area
export move_shape!, set_color!, toggle_visibility!, clone_shape, destroy_shape

end # module
