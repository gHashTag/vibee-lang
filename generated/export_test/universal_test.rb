# ═══════════════════════════════════════════════════════════════════════════════
# UNIVERSAL TEST - Ruby
# Generated from universal_test.vibee
# φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════════
# TYPES
# ═══════════════════════════════════════════════════════════════════════════════

Point = Struct.new(:x, :y)

Rectangle = Struct.new(:origin, :width, :height)

Color = Struct.new(:r, :g, :b, :a)

Shape = Struct.new(:name, :rect, :color, :visible)

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

def create_point(x, y)
  Point.new(x, y)
end

def create_rectangle(origin, width, height)
  Rectangle.new(origin, width, height)
end

def calculate_area(rect)
  rect.width * rect.height
end

def move_shape(shape, dx, dy)
  shape.rect.origin.x += dx
  shape.rect.origin.y += dy
end

def set_color(shape, color)
  shape.color = color
end

def toggle_visibility(shape)
  shape.visible = !shape.visible
end

def clone_shape(shape)
  Shape.new(
    shape.name.dup,
    Rectangle.new(
      Point.new(shape.rect.origin.x, shape.rect.origin.y),
      shape.rect.width,
      shape.rect.height
    ),
    Color.new(shape.color.r, shape.color.g, shape.color.b, shape.color.a),
    shape.visible
  )
end

def destroy_shape(shape)
  # Ruby has garbage collection
end

# ═══════════════════════════════════════════════════════════════════════════════
# TESTS
# ═══════════════════════════════════════════════════════════════════════════════

if __FILE__ == $0
  # Test Point
  p = create_point(1.0, 2.0)
  raise "Point x failed" unless p.x == 1.0
  raise "Point y failed" unless p.y == 2.0
  puts "✅ Point test passed"
  
  # Test Rectangle
  r = create_rectangle(p, 10.0, 5.0)
  raise "Area failed" unless calculate_area(r) == 50.0
  puts "✅ Rectangle test passed"
  
  # Test Shape
  s = Shape.new("test", r, Color.new(255, 0, 0, 255), true)
  move_shape(s, 5.0, 5.0)
  raise "Move failed" unless s.rect.origin.x == 6.0
  puts "✅ Shape test passed"
  
  puts "All tests passed!"
end
