// ═══════════════════════════════════════════════════════════════════════════════
// UNIVERSAL TEST - Kotlin
// Generated from universal_test.vibee
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════════════════════

package universal_test

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

data class Point(var x: Double, var y: Double)

data class Rectangle(var origin: Point, var width: Double, var height: Double)

data class Color(var r: Long, var g: Long, var b: Long, var a: Long)

data class Shape(
    var name: String,
    var rect: Rectangle,
    var color: Color,
    var visible: Boolean
)

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

fun createPoint(x: Double, y: Double): Point = Point(x, y)

fun createRectangle(origin: Point, width: Double, height: Double): Rectangle =
    Rectangle(origin, width, height)

fun calculateArea(rect: Rectangle): Double = rect.width * rect.height

fun moveShape(shape: Shape, dx: Double, dy: Double) {
    shape.rect.origin.x += dx
    shape.rect.origin.y += dy
}

fun setColor(shape: Shape, color: Color) {
    shape.color = color
}

fun toggleVisibility(shape: Shape) {
    shape.visible = !shape.visible
}

fun cloneShape(shape: Shape): Shape = shape.copy(
    rect = shape.rect.copy(
        origin = shape.rect.origin.copy()
    ),
    color = shape.color.copy()
)

fun destroyShape(shape: Shape) {
    // Kotlin has garbage collection
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

fun main() {
    // Test Point
    val p = createPoint(1.0, 2.0)
    assert(p.x == 1.0)
    assert(p.y == 2.0)
    println("✅ Point test passed")
    
    // Test Rectangle
    val r = createRectangle(p, 10.0, 5.0)
    assert(calculateArea(r) == 50.0)
    println("✅ Rectangle test passed")
    
    // Test Shape
    val s = Shape("test", r, Color(255, 0, 0, 255), true)
    moveShape(s, 5.0, 5.0)
    assert(s.rect.origin.x == 6.0)
    println("✅ Shape test passed")
    
    println("All tests passed!")
}
