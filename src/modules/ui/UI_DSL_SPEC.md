# VIBEE UI DSL Specification

## Overview

Every plugin MUST have a UI page defined in `spec.yml` under `ui:` section.
UI is generated using Yoga Layout (Flexbox) and rendered to Canvas.

## spec.yml Structure

```yaml
plugin:
  name: my_plugin
  version: 1.0.0
  
ui:
  page:
    title: "My Plugin Dashboard"
    path: "/plugins/my_plugin"
    layout: "flex"
    
  theme:
    background: "#000000"
    text: "#ffffff"
    accent: "#6366f1"
    
  layout:
    direction: "column"        # row | column
    padding: 40                # All sides
    gap: 24                    # Between items
    align: "center"            # flex-start | center | flex-end | stretch
    justify: "flex-start"      # flex-start | center | flex-end | space-between
    
  components:
    - type: "header"
      text: "Plugin Dashboard"
      fontSize: 48
      fontWeight: 300
      letterSpacing: 4
      margin: [0, 0, 40, 0]    # top, right, bottom, left
      
    - type: "container"
      direction: "row"
      gap: 20
      padding: 20
      children:
        - type: "card"
          flex: 1
          padding: 30
          title: "Statistics"
          content: "Active users: 1,234"
          
        - type: "card"
          flex: 1
          padding: 30
          title: "Performance"
          content: "Uptime: 99.9%"
          
    - type: "section"
      title: "Documentation"
      content: "How to use this plugin..."
      padding: [20, 0]
      
    - type: "button"
      text: "View Details"
      onClick: "navigate:/plugins/my_plugin/details"
      padding: [12, 24]
      margin: [20, 0, 0, 0]
```

## Component Types

### Layout Components

**container**
```yaml
- type: "container"
  direction: "row" | "column"
  wrap: true | false
  gap: 16
  padding: 20
  margin: [10, 20]
  align: "center"
  justify: "space-between"
  children: [...]
```

**grid**
```yaml
- type: "grid"
  columns: 3
  gap: 20
  children: [...]
```

### Content Components

**header**
```yaml
- type: "header"
  text: "Title"
  level: 1 | 2 | 3
  fontSize: 48
  fontWeight: 300 | 400 | 700
  letterSpacing: 2
  align: "left" | "center" | "right"
```

**text**
```yaml
- type: "text"
  content: "Body text"
  fontSize: 16
  lineHeight: 1.5
  color: "#ffffff"
```

**card**
```yaml
- type: "card"
  title: "Card Title"
  content: "Card content"
  padding: 30
  border: 1
  borderColor: "rgba(255,255,255,0.15)"
  background: "rgba(255,255,255,0.05)"
```

**button**
```yaml
- type: "button"
  text: "Click Me"
  variant: "primary" | "secondary" | "ghost"
  onClick: "action:name" | "navigate:/path"
  padding: [12, 24]
```

**input**
```yaml
- type: "input"
  placeholder: "Enter text"
  value: ""
  onChange: "action:update"
```

### Data Components

**stat**
```yaml
- type: "stat"
  label: "Total Users"
  value: "1,234"
  change: "+12%"
  trend: "up" | "down"
```

**chart**
```yaml
- type: "chart"
  chartType: "line" | "bar" | "pie"
  data: [...]
  width: 400
  height: 200
```

**table**
```yaml
- type: "table"
  columns: ["Name", "Status", "Actions"]
  rows: [...]
```

## Spacing System

**Padding/Margin values:**
- Single: `20` - all sides
- Array: `[10, 20]` - vertical, horizontal
- Array: `[10, 20, 30, 40]` - top, right, bottom, left

**Gap values:**
- Between flex items: `gap: 16`
- Row/Column specific: `rowGap: 16, columnGap: 20`

## Responsive Breakpoints

```yaml
responsive:
  mobile: 320-767
  tablet: 768-1023
  desktop: 1024-1919
  wide: 1920+
  
# Component can have responsive variants
- type: "container"
  direction: "column"
  responsive:
    desktop:
      direction: "row"
    mobile:
      padding: 10
```

## Theme Variables

```yaml
theme:
  colors:
    background: "#000000"
    surface: "rgba(255,255,255,0.05)"
    border: "rgba(255,255,255,0.15)"
    text: "#ffffff"
    textSecondary: "rgba(255,255,255,0.6)"
    accent: "#6366f1"
    
  spacing:
    xs: 4
    sm: 8
    md: 16
    lg: 24
    xl: 40
    
  typography:
    fontFamily: "Montserrat"
    fontSize:
      xs: 12
      sm: 14
      base: 16
      lg: 20
      xl: 24
      2xl: 32
      3xl: 48
    fontWeight:
      light: 300
      normal: 400
      bold: 700
```

## Navigation

Central dashboard at `/plugins` lists all plugin pages:

```yaml
navigation:
  - name: "Dashboard"
    path: "/plugins"
    icon: "home"
    
  - name: "My Plugin"
    path: "/plugins/my_plugin"
    icon: "plugin"
    
  - name: "Settings"
    path: "/plugins/settings"
    icon: "settings"
```

## Example: Complete Plugin UI

```yaml
plugin:
  name: pixel_grid
  version: 1.0.0
  
ui:
  page:
    title: "Pixel Grid Dashboard"
    path: "/plugins/pixel_grid"
    
  theme:
    background: "#000000"
    text: "#ffffff"
    
  layout:
    direction: "column"
    padding: 40
    gap: 40
    maxWidth: 1920
    
  components:
    # Header
    - type: "header"
      text: "PIXEL GRID"
      fontSize: 64
      fontWeight: 300
      letterSpacing: 8
      align: "center"
      margin: [0, 0, 20, 0]
      
    # Subtitle
    - type: "text"
      content: "32,400 BEAM processes rendering Full HD"
      fontSize: 20
      align: "center"
      color: "rgba(255,255,255,0.6)"
      margin: [0, 0, 60, 0]
      
    # Stats Grid
    - type: "grid"
      columns: 4
      gap: 20
      children:
        - type: "stat"
          label: "Processes"
          value: "32,400"
          
        - type: "stat"
          label: "FPS"
          value: "60+"
          
        - type: "stat"
          label: "Memory"
          value: "256MB"
          
        - type: "stat"
          label: "Uptime"
          value: "99.9%"
          
    # Documentation
    - type: "section"
      title: "How It Works"
      padding: [40, 0]
      children:
        - type: "text"
          content: "Each 8x8 pixel tile is a separate BEAM process..."
          lineHeight: 1.6
          
    # Actions
    - type: "container"
      direction: "row"
      gap: 20
      justify: "center"
      children:
        - type: "button"
          text: "View Demo"
          variant: "primary"
          onClick: "navigate:/plugins/pixel_grid/demo"
          
        - type: "button"
          text: "Documentation"
          variant: "secondary"
          onClick: "navigate:/plugins/pixel_grid/docs"
```

## Generator Output

The UI generator will:
1. Parse `spec.yml` → `ui:` section
2. Create Yoga Layout tree
3. Calculate positions with Flexbox
4. Generate Canvas drawing code
5. Add to central navigation
6. Create route handler

Generated files:
- `honeycomb/ui/pages/{plugin_name}.gleam` - Page renderer
- `honeycomb/ui/routes.gleam` - Route registration
- `honeycomb/ui/navigation.gleam` - Nav menu

## Benefits

✅ **Consistency** - All plugins use same UI system
✅ **Responsive** - Yoga Layout handles all screen sizes
✅ **Maintainable** - UI defined in spec.yml, not code
✅ **Documented** - UI spec IS documentation
✅ **Centralized** - All pages linked from dashboard
✅ **No padding issues** - Proper spacing system
✅ **Theme-aware** - Dark/light themes built-in
