// ═══════════════════════════════════════════════════════════════════════════════
// UNIVERSAL TEST - Swift
// Generated from universal_test.vibee
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════════════════════

import Foundation

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

struct Point {
    var x: Double
    var y: Double
}

struct Rectangle {
    var origin: Point
    var width: Double
    var height: Double
}

struct Color {
    var r: Int64
    var g: Int64
    var b: Int64
    var a: Int64
}

class Shape {
    var name: String
    var rect: Rectangle
    var color: Color
    var visible: Bool
    
    init(name: String, rect: Rectangle, color: Color, visible: Bool) {
        self.name = name
        self.rect = rect
        self.color = color
        self.visible = visible
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

func createPoint(x: Double, y: Double) -> Point {
    return Point(x: x, y: y)
}

func createRectangle(origin: Point, width: Double, height: Double) -> Rectangle {
    return Rectangle(origin: origin, width: width, height: height)
}

func calculateArea(rect: Rectangle) -> Double {
    return rect.width * rect.height
}

func moveShape(_ shape: Shape, dx: Double, dy: Double) {
    shape.rect.origin.x += dx
    shape.rect.origin.y += dy
}

func setColor(_ shape: Shape, color: Color) {
    shape.color = color
}

func toggleVisibility(_ shape: Shape) {
    shape.visible = !shape.visible
}

func cloneShape(_ shape: Shape) -> Shape {
    return Shape(
        name: shape.name,
        rect: Rectangle(
            origin: Point(x: shape.rect.origin.x, y: shape.rect.origin.y),
            width: shape.rect.width,
            height: shape.rect.height
        ),
        color: Color(r: shape.color.r, g: shape.color.g, b: shape.color.b, a: shape.color.a),
        visible: shape.visible
    )
}

func destroyShape(_ shape: Shape) {
    // Swift has ARC
}
