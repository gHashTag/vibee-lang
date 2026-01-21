-- ═══════════════════════════════════════════════════════════════════════════════
-- UNIVERSAL TEST - Lua
-- Generated from universal_test.vibee
-- φ² + 1/φ² = 3 | PHOENIX = 999
-- ═══════════════════════════════════════════════════════════════════════════════

local UniversalTest = {}

-- ═══════════════════════════════════════════════════════════════════════════════
-- TYPES (using tables)
-- ═══════════════════════════════════════════════════════════════════════════════

function UniversalTest.Point(x, y)
    return { x = x, y = y }
end

function UniversalTest.Rectangle(origin, width, height)
    return { origin = origin, width = width, height = height }
end

function UniversalTest.Color(r, g, b, a)
    return { r = r, g = g, b = b, a = a }
end

function UniversalTest.Shape(name, rect, color, visible)
    return { name = name, rect = rect, color = color, visible = visible }
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════

function UniversalTest.create_point(x, y)
    return UniversalTest.Point(x, y)
end

function UniversalTest.create_rectangle(origin, width, height)
    return UniversalTest.Rectangle(origin, width, height)
end

function UniversalTest.calculate_area(rect)
    return rect.width * rect.height
end

function UniversalTest.move_shape(shape, dx, dy)
    shape.rect.origin.x = shape.rect.origin.x + dx
    shape.rect.origin.y = shape.rect.origin.y + dy
end

function UniversalTest.set_color(shape, color)
    shape.color = color
end

function UniversalTest.toggle_visibility(shape)
    shape.visible = not shape.visible
end

function UniversalTest.clone_shape(shape)
    return UniversalTest.Shape(
        shape.name,
        UniversalTest.Rectangle(
            UniversalTest.Point(shape.rect.origin.x, shape.rect.origin.y),
            shape.rect.width,
            shape.rect.height
        ),
        UniversalTest.Color(shape.color.r, shape.color.g, shape.color.b, shape.color.a),
        shape.visible
    )
end

function UniversalTest.destroy_shape(shape)
    -- Lua has garbage collection
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- TESTS
-- ═══════════════════════════════════════════════════════════════════════════════

if arg and arg[0] then
    -- Test Point
    local p = UniversalTest.create_point(1.0, 2.0)
    assert(p.x == 1.0)
    assert(p.y == 2.0)
    print("✅ Point test passed")
    
    -- Test Rectangle
    local r = UniversalTest.create_rectangle(p, 10.0, 5.0)
    assert(UniversalTest.calculate_area(r) == 50.0)
    print("✅ Rectangle test passed")
    
    -- Test Shape
    local s = UniversalTest.Shape("test", r, UniversalTest.Color(255, 0, 0, 255), true)
    UniversalTest.move_shape(s, 5.0, 5.0)
    assert(s.rect.origin.x == 6.0)
    print("✅ Shape test passed")
    
    print("All tests passed!")
end

return UniversalTest
