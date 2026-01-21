{- ═══════════════════════════════════════════════════════════════════════════════
   UNIVERSAL TEST - Haskell
   Generated from universal_test.vibee
   φ² + 1/φ² = 3 | PHOENIX = 999
   ═══════════════════════════════════════════════════════════════════════════════ -}

module UniversalTest where

-- ═══════════════════════════════════════════════════════════════════════════════
-- TYPES
-- ═══════════════════════════════════════════════════════════════════════════════

data Point = Point
    { pointX :: Double
    , pointY :: Double
    } deriving (Show, Eq)

data Rectangle = Rectangle
    { rectOrigin :: Point
    , rectWidth  :: Double
    , rectHeight :: Double
    } deriving (Show, Eq)

data Color = Color
    { colorR :: Int
    , colorG :: Int
    , colorB :: Int
    , colorA :: Int
    } deriving (Show, Eq)

data Shape = Shape
    { shapeName    :: String
    , shapeRect    :: Rectangle
    , shapeColor   :: Color
    , shapeVisible :: Bool
    } deriving (Show, Eq)

-- ═══════════════════════════════════════════════════════════════════════════════
-- FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════

createPoint :: Double -> Double -> Point
createPoint = Point

createRectangle :: Point -> Double -> Double -> Rectangle
createRectangle = Rectangle

calculateArea :: Rectangle -> Double
calculateArea rect = rectWidth rect * rectHeight rect

moveShape :: Shape -> Double -> Double -> Shape
moveShape shape dx dy = shape { shapeRect = newRect }
  where
    oldRect = shapeRect shape
    oldOrigin = rectOrigin oldRect
    newOrigin = Point (pointX oldOrigin + dx) (pointY oldOrigin + dy)
    newRect = oldRect { rectOrigin = newOrigin }

setColor :: Shape -> Color -> Shape
setColor shape color = shape { shapeColor = color }

toggleVisibility :: Shape -> Shape
toggleVisibility shape = shape { shapeVisible = not (shapeVisible shape) }

cloneShape :: Shape -> Shape
cloneShape = id  -- Haskell values are immutable, so clone is identity

destroyShape :: Shape -> ()
destroyShape _ = ()  -- Haskell has garbage collection
