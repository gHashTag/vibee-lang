// ═══════════════════════════════════════════════════════════════════════════════
// UNIVERSAL TEST - Rust
// Generated from universal_test.vibee
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct Point {
    pub x: f64,
    pub y: f64,
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct Rectangle {
    pub origin: Point,
    pub width: f64,
    pub height: f64,
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct Color {
    pub r: i64,
    pub g: i64,
    pub b: i64,
    pub a: i64,
}

#[repr(C)]
#[derive(Debug, Clone)]
pub struct Shape {
    pub name: String,
    pub rect: Rectangle,
    pub color: Color,
    pub visible: bool,
}

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

impl Point {
    pub fn new(x: f64, y: f64) -> Self {
        Self { x, y }
    }
}

impl Rectangle {
    pub fn new(origin: Point, width: f64, height: f64) -> Self {
        Self { origin, width, height }
    }
    
    pub fn area(&self) -> f64 {
        self.width * self.height
    }
}

impl Shape {
    pub fn move_by(&mut self, dx: f64, dy: f64) {
        self.rect.origin.x += dx;
        self.rect.origin.y += dy;
    }
    
    pub fn set_color(&mut self, color: Color) {
        self.color = color;
    }
    
    pub fn toggle_visibility(&mut self) {
        self.visible = !self.visible;
    }
    
    pub fn clone_shape(&self) -> Self {
        self.clone()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_point() {
        let p = Point::new(1.0, 2.0);
        assert_eq!(p.x, 1.0);
        assert_eq!(p.y, 2.0);
    }
    
    #[test]
    fn test_rectangle_area() {
        let r = Rectangle::new(Point::new(0.0, 0.0), 10.0, 5.0);
        assert_eq!(r.area(), 50.0);
    }
}
