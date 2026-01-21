// ═══════════════════════════════════════════════════════════════════════════════
// UNIVERSAL TEST - Go
// Generated from universal_test.vibee
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════════════════════

package universal_test

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

type Point struct {
	X float64
	Y float64
}

type Rectangle struct {
	Origin Point
	Width  float64
	Height float64
}

type Color struct {
	R int64
	G int64
	B int64
	A int64
}

type Shape struct {
	Name    string
	Rect    Rectangle
	Color   Color
	Visible bool
}

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

func CreatePoint(x, y float64) Point {
	return Point{X: x, Y: y}
}

func CreateRectangle(origin Point, width, height float64) Rectangle {
	return Rectangle{Origin: origin, Width: width, Height: height}
}

func CalculateArea(rect Rectangle) float64 {
	return rect.Width * rect.Height
}

func MoveShape(shape *Shape, dx, dy float64) {
	shape.Rect.Origin.X += dx
	shape.Rect.Origin.Y += dy
}

func SetColor(shape *Shape, color Color) {
	shape.Color = color
}

func ToggleVisibility(shape *Shape) {
	shape.Visible = !shape.Visible
}

func CloneShape(shape *Shape) *Shape {
	return &Shape{
		Name:    shape.Name,
		Rect:    shape.Rect,
		Color:   shape.Color,
		Visible: shape.Visible,
	}
}

func DestroyShape(shape *Shape) {
	// Go has garbage collection
}
