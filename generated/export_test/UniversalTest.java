// ═══════════════════════════════════════════════════════════════════════════════
// UNIVERSAL TEST - Java
// Generated from universal_test.vibee
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════════════════════

package universal_test;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

public class UniversalTest {
    
    public static class Point {
        public double x;
        public double y;
        
        public Point(double x, double y) {
            this.x = x;
            this.y = y;
        }
    }
    
    public static class Rectangle {
        public Point origin;
        public double width;
        public double height;
        
        public Rectangle(Point origin, double width, double height) {
            this.origin = origin;
            this.width = width;
            this.height = height;
        }
    }
    
    public static class Color {
        public long r;
        public long g;
        public long b;
        public long a;
        
        public Color(long r, long g, long b, long a) {
            this.r = r;
            this.g = g;
            this.b = b;
            this.a = a;
        }
    }
    
    public static class Shape {
        public String name;
        public Rectangle rect;
        public Color color;
        public boolean visible;
        
        public Shape(String name, Rectangle rect, Color color, boolean visible) {
            this.name = name;
            this.rect = rect;
            this.color = color;
            this.visible = visible;
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════════
    // FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════════
    
    public static Point createPoint(double x, double y) {
        return new Point(x, y);
    }
    
    public static Rectangle createRectangle(Point origin, double width, double height) {
        return new Rectangle(origin, width, height);
    }
    
    public static double calculateArea(Rectangle rect) {
        return rect.width * rect.height;
    }
    
    public static void moveShape(Shape shape, double dx, double dy) {
        shape.rect.origin.x += dx;
        shape.rect.origin.y += dy;
    }
    
    public static void setColor(Shape shape, Color color) {
        shape.color = color;
    }
    
    public static void toggleVisibility(Shape shape) {
        shape.visible = !shape.visible;
    }
    
    public static Shape cloneShape(Shape shape) {
        return new Shape(
            shape.name,
            new Rectangle(
                new Point(shape.rect.origin.x, shape.rect.origin.y),
                shape.rect.width,
                shape.rect.height
            ),
            new Color(shape.color.r, shape.color.g, shape.color.b, shape.color.a),
            shape.visible
        );
    }
    
    public static void destroyShape(Shape shape) {
        // Java has garbage collection
    }
    
    // ═══════════════════════════════════════════════════════════════════════════════
    // TESTS
    // ═══════════════════════════════════════════════════════════════════════════════
    
    public static void main(String[] args) {
        // Test Point
        Point p = createPoint(1.0, 2.0);
        assert p.x == 1.0;
        assert p.y == 2.0;
        System.out.println("✅ Point test passed");
        
        // Test Rectangle
        Rectangle r = createRectangle(p, 10.0, 5.0);
        assert calculateArea(r) == 50.0;
        System.out.println("✅ Rectangle test passed");
        
        // Test Shape
        Shape s = new Shape("test", r, new Color(255, 0, 0, 255), true);
        moveShape(s, 5.0, 5.0);
        assert s.rect.origin.x == 6.0;
        System.out.println("✅ Shape test passed");
        
        System.out.println("All tests passed!");
    }
}
