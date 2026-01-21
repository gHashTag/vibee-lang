# ═══════════════════════════════════════════════════════════════════════════════
# UNIVERSAL TEST - Elixir
# Generated from universal_test.vibee
# φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

defmodule UniversalTest do
  # ═══════════════════════════════════════════════════════════════════════════════
  # TYPES
  # ═══════════════════════════════════════════════════════════════════════════════

  defmodule Point do
    defstruct [:x, :y]
    @type t :: %__MODULE__{x: float(), y: float()}
  end

  defmodule Rectangle do
    defstruct [:origin, :width, :height]
    @type t :: %__MODULE__{origin: Point.t(), width: float(), height: float()}
  end

  defmodule Color do
    defstruct [:r, :g, :b, :a]
    @type t :: %__MODULE__{r: integer(), g: integer(), b: integer(), a: integer()}
  end

  defmodule Shape do
    defstruct [:name, :rect, :color, :visible]
    @type t :: %__MODULE__{name: String.t(), rect: Rectangle.t(), color: Color.t(), visible: boolean()}
  end

  # ═══════════════════════════════════════════════════════════════════════════════
  # FUNCTIONS
  # ═══════════════════════════════════════════════════════════════════════════════

  @spec create_point(float(), float()) :: Point.t()
  def create_point(x, y), do: %Point{x: x, y: y}

  @spec create_rectangle(Point.t(), float(), float()) :: Rectangle.t()
  def create_rectangle(origin, width, height) do
    %Rectangle{origin: origin, width: width, height: height}
  end

  @spec calculate_area(Rectangle.t()) :: float()
  def calculate_area(%Rectangle{width: w, height: h}), do: w * h

  @spec move_shape(Shape.t(), float(), float()) :: Shape.t()
  def move_shape(%Shape{rect: rect} = shape, dx, dy) do
    new_origin = %Point{x: rect.origin.x + dx, y: rect.origin.y + dy}
    new_rect = %Rectangle{rect | origin: new_origin}
    %Shape{shape | rect: new_rect}
  end

  @spec set_color(Shape.t(), Color.t()) :: Shape.t()
  def set_color(shape, color), do: %Shape{shape | color: color}

  @spec toggle_visibility(Shape.t()) :: Shape.t()
  def toggle_visibility(shape), do: %Shape{shape | visible: not shape.visible}

  @spec clone_shape(Shape.t()) :: Shape.t()
  def clone_shape(shape) do
    %Shape{
      name: shape.name,
      rect: %Rectangle{
        origin: %Point{x: shape.rect.origin.x, y: shape.rect.origin.y},
        width: shape.rect.width,
        height: shape.rect.height
      },
      color: %Color{r: shape.color.r, g: shape.color.g, b: shape.color.b, a: shape.color.a},
      visible: shape.visible
    }
  end

  @spec destroy_shape(Shape.t()) :: :ok
  def destroy_shape(_shape), do: :ok  # Elixir has garbage collection
end
