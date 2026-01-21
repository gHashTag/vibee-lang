// ═══════════════════════════════════════════════════════════════════════════════
// UNIVERSAL TEST - C Header
// Generated from universal_test.vibee
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════════════════════

#ifndef UNIVERSAL_TEST_H
#define UNIVERSAL_TEST_H

#include <stdint.h>
#include <stdbool.h>

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

typedef struct {
    double x;
    double y;
} Point;

typedef struct {
    Point origin;
    double width;
    double height;
} Rectangle;

typedef struct {
    int64_t r;
    int64_t g;
    int64_t b;
    int64_t a;
} Color;

typedef struct {
    const char* name;
    Rectangle rect;
    Color color;
    bool visible;
} Shape;

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

Point create_point(double x, double y);
Rectangle create_rectangle(Point origin, double width, double height);
double calculate_area(Rectangle rect);
void move_shape(Shape* shape, double dx, double dy);
void set_color(Shape* shape, Color color);
void toggle_visibility(Shape* shape);
Shape* clone_shape(const Shape* shape);
void destroy_shape(Shape* shape);

#endif // UNIVERSAL_TEST_H
