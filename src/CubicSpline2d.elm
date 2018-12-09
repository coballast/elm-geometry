--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- This Source Code Form is subject to the terms of the Mozilla Public        --
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,  --
-- you can obtain one at http://mozilla.org/MPL/2.0/.                         --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


module CubicSpline2d exposing
    ( CubicSpline2d
    , with, fromEndpoints, fromQuadraticSpline
    , startPoint, endPoint, startControlPoint, endControlPoint, startDerivative, endDerivative, boundingBox
    , pointOn, pointsAt
    , Nondegenerate, nondegenerate, fromNondegenerate
    , tangentDirection, tangentDirectionsAt, sample, samplesAt
    , reverse, scaleAbout, rotateAround, translateBy, translateIn, mirrorAcross
    , relativeTo, placeIn
    , bisect, splitAt
    , ArcLengthParameterized, arcLengthParameterized, arcLength, midpoint, pointAlong, tangentDirectionAlong, sampleAlong
    , arcLengthParameterization, fromArcLengthParameterized
    , firstDerivative, firstDerivativesAt, secondDerivative, secondDerivativesAt, thirdDerivative, maxSecondDerivativeMagnitude
    )

{-| A `CubicSpline2d` is a cubic [Bézier curve](https://en.wikipedia.org/wiki/B%C3%A9zier_curve)
in 2D defined by a start point, end point and two control points. This module
contains functionality for

  - Constructing splines
  - Evaluating points and tangent directions along a spline
  - Scaling, rotating, translating or mirroring a spline
  - Converting a spline between local and global coordinates in different
    reference frames

@docs CubicSpline2d


# Constructors

@docs with, fromEndpoints, fromQuadraticSpline


# Properties

@docs startPoint, endPoint, startControlPoint, endControlPoint, startDerivative, endDerivative, boundingBox


# Evaluation

@docs pointOn, pointsAt
@docs Nondegenerate, nondegenerate, fromNondegenerate
@docs tangentDirection, tangentDirectionsAt, sample, samplesAt


# Transformations

@docs reverse, scaleAbout, rotateAround, translateBy, translateIn, mirrorAcross


# Coordinate conversions

@docs relativeTo, placeIn


# Subdivision

@docs bisect, splitAt


# Arc length parameterization

@docs ArcLengthParameterized, arcLengthParameterized, arcLength, midpoint, pointAlong, tangentDirectionAlong, sampleAlong


## Low level

An `ArcLengthParameterized` value is a combination of an
[`ArcLengthParameterization`](Geometry-ArcLengthParameterization) and an
underlying `CubicSpline2d`. If you need to do something fancy, you can extract
these two values separately.

@docs arcLengthParameterization, fromArcLengthParameterized


# Differentiation

You are unlikely to need to use these functions directly, but they are useful if
you are writing low-level geometric algorithms.

@docs firstDerivative, firstDerivativesAt, secondDerivative, secondDerivativesAt, thirdDerivative, maxSecondDerivativeMagnitude

-}

import Axis2d exposing (Axis2d)
import BoundingBox2d exposing (BoundingBox2d)
import Curve.ArcLengthParameterization as ArcLengthParameterization exposing (ArcLengthParameterization)
import Curve.ParameterValue as ParameterValue exposing (ParameterValue)
import Direction2d exposing (Direction2d)
import Frame2d exposing (Frame2d)
import Geometry.Types as Types
import LineSegment2d exposing (fromEndpoints, midpoint)
import Point2d exposing (Point2d)
import QuadraticSpline2d exposing (QuadraticSpline2d)
import Vector2d exposing (Vector2d)


{-| -}
type alias CubicSpline2d units coordinates =
    Types.CubicSpline2d units coordinates


{-| Construct a spline from its endpoints and control points:

    exampleSpline =
        CubicSpline2d.with
            { startPoint =
                Point2d.fromCoordinates ( 1, 1 )
            , startControlPoint =
                Point2d.fromCoordinates ( 3, 4 )
            , endControlPoint =
                Point2d.fromCoordinates ( 5, 1 )
            , endPoint =
                Point2d.fromCoordinates ( 7, 4 )
            }

-}
with :
    { startPoint : Point2d units coordinates
    , startControlPoint : Point2d units coordinates
    , endControlPoint : Point2d units coordinates
    , endPoint : Point2d units coordinates
    }
    -> CubicSpline2d units coordinates
with =
    Types.CubicSpline2d


{-| Construct a spline from a given start point with a given start derivative,
to a given end point with a given end derivative, like so:

![Cubic spline from endpoints](https://ianmackenzie.github.io/elm-geometry/1.0.0/CubicSpline2d/fromEndpoints.svg)

The spline is based on a parameter that ranges from 0 to 1; as a result, in most
cases the length of each derivative vector should be roughly equal to the length
of the resulting spline.

-}
fromEndpoints :
    { startPoint : Point2d units coordinates
    , startDerivative : Vector2d units coordinates
    , endPoint : Point2d units coordinates
    , endDerivative : Vector2d units coordinates
    }
    -> CubicSpline2d units coordinates
fromEndpoints arguments =
    let
        startControlPoint_ =
            arguments.startPoint
                |> Point2d.translateBy
                    (Vector2d.scaleBy (1 / 3) arguments.startDerivative)

        endControlPoint_ =
            arguments.endPoint
                |> Point2d.translateBy
                    (Vector2d.scaleBy (-1 / 3) arguments.endDerivative)
    in
    with
        { startPoint = arguments.startPoint
        , startControlPoint = startControlPoint_
        , endControlPoint = endControlPoint_
        , endPoint = arguments.endPoint
        }


{-| Convert a quadratic spline into the equivalent cubic spline (every quadratic
spline can be represented exactly as a cubic spline).

    quadraticSpline =
        QuadraticSpline2d.with
            { startPoint =
                Point2d.fromCoordinates ( 0, 0  )
            , controlPoint =
                Point2d.fromCoordinates ( 3, 0 )
            , endPoint =
                Point2d.fromCoordinates ( 3, 3 )
            }

    CubicSpline2d.fromQuadraticSpline quadraticSpline
    --> CubicSpline2d.with
    -->     { startPoint =
    -->         Point2d.fromCoordinates ( 0, 0 )
    -->     , startControlPoint =
    -->         Point2d.fromCoordinates ( 2, 0 )
    -->     , endControlPoint =
    -->         Point2d.fromCoordinates ( 3, 1 )
    -->     , endPoint =
    -->         Point2d.fromCoordinates ( 3, 3 )
    -->     }

-}
fromQuadraticSpline : QuadraticSpline2d units coordinates -> CubicSpline2d units coordinates
fromQuadraticSpline quadraticSpline =
    let
        startPoint_ =
            QuadraticSpline2d.startPoint quadraticSpline

        controlPoint_ =
            QuadraticSpline2d.controlPoint quadraticSpline

        endPoint_ =
            QuadraticSpline2d.endPoint quadraticSpline

        startControlPoint_ =
            Point2d.interpolateFrom startPoint_ controlPoint_ (2 / 3)

        endControlPoint_ =
            Point2d.interpolateFrom endPoint_ controlPoint_ (2 / 3)
    in
    with
        { startPoint = startPoint_
        , startControlPoint = startControlPoint_
        , endControlPoint = endControlPoint_
        , endPoint = endPoint_
        }


{-| Get the start point of a spline.

    CubicSpline2d.startPoint exampleSpline
    --> Point2d.fromCoordinates ( 1, 1 )

-}
startPoint : CubicSpline2d units coordinates -> Point2d units coordinates
startPoint (Types.CubicSpline2d spline) =
    spline.startPoint


{-| Get the end point of a spline.

    CubicSpline2d.endPoint exampleSpline
    --> Point2d.fromCoordinates ( 7, 4 )

-}
endPoint : CubicSpline2d units coordinates -> Point2d units coordinates
endPoint (Types.CubicSpline2d spline) =
    spline.endPoint


{-| Get the start control point of a spline (the control point next to the
start point).

    CubicSpline2d.startControlPoint exampleSpline
    --> Point2d.fromCoordinates ( 3, 4 )

-}
startControlPoint : CubicSpline2d units coordinates -> Point2d units coordinates
startControlPoint (Types.CubicSpline2d spline) =
    spline.startControlPoint


{-| Get the end control point of a spline (the control point next to the
end point).

    CubicSpline2d.endControlPoint exampleSpline
    --> Point2d.fromCoordinates ( 5, 1 )

-}
endControlPoint : CubicSpline2d units coordinates -> Point2d units coordinates
endControlPoint (Types.CubicSpline2d spline) =
    spline.endControlPoint


{-| Get the start derivative of a spline. This is equal to three times the
vector from the spline's start point to its start control point.

    CubicSpline2d.startDerivative exampleSpline
    --> Vector2d.fromComponents ( 6, 9 )

-}
startDerivative : CubicSpline2d units coordinates -> Vector2d units coordinates
startDerivative spline =
    Vector2d.from (startPoint spline) (startControlPoint spline)
        |> Vector2d.scaleBy 3


{-| Get the end derivative of a spline. This is equal to three times the vector
from the spline's end control point to its end point.

    CubicSpline2d.endDerivative exampleSpline
    --> Vector2d.fromComponents ( 6, 9 )

-}
endDerivative : CubicSpline2d units coordinates -> Vector2d units coordinates
endDerivative spline =
    Vector2d.from (endControlPoint spline) (endPoint spline)
        |> Vector2d.scaleBy 3


{-| Compute a bounding box for a given spline. It is not guaranteed that the
result will be the _smallest_ possible bounding box, since for efficiency the
bounding box is computed from the spline's control points (which cover a larger
area than the spline itself).

    CubicSpline2d.boundingBox exampleSpline
    --> BoundingBox2d.fromExtrema
    -->     { minX = 1
    -->     , maxX = 7
    -->     , minY = 1
    -->     , maxY = 4
    -->     }

-}
boundingBox : CubicSpline2d units coordinates -> BoundingBox2d units coordinates
boundingBox spline =
    let
        ( x1, y1 ) =
            Point2d.coordinates (startPoint spline)

        ( x2, y2 ) =
            Point2d.coordinates (startControlPoint spline)

        ( x3, y3 ) =
            Point2d.coordinates (endControlPoint spline)

        ( x4, y4 ) =
            Point2d.coordinates (endPoint spline)
    in
    BoundingBox2d.fromExtrema
        { minX = Quantity.min (Quantity.min x1 x2) (Quantity.min x3 x4)
        , maxX = Quantity.max (Quantity.max x1 x2) (Quantity.max x3 x4)
        , minY = Quantity.min (Quantity.min y1 y2) (Quantity.min y3 y4)
        , maxY = Quantity.max (Quantity.max y1 y2) (Quantity.max y3 y4)
        }


{-| Get the point along a spline at a given parameter value:

    CubicSpline2d.pointOn exampleSpline ParameterValue.zero
    --> Point2d.fromCoordinates ( 1, 1 )

    CubicSpline2d.pointOn exampleSpline ParameterValue.half
    --> Point2d.fromCoordinates ( 4, 2.5 )

    CubicSpline2d.pointOn exampleSpline ParameterValue.one
    --> Point2d.fromCoordinates ( 7, 4 )

-}
pointOn : CubicSpline2d units coordinates -> ParameterValue -> Point2d units coordinates
pointOn spline parameterValue =
    let
        t =
            ParameterValue.value parameterValue

        p1 =
            startPoint spline

        p2 =
            startControlPoint spline

        p3 =
            endControlPoint spline

        p4 =
            endPoint spline

        q1 =
            Point2d.interpolateFrom p1 p2 t

        q2 =
            Point2d.interpolateFrom p2 p3 t

        q3 =
            Point2d.interpolateFrom p3 p4 t

        r1 =
            Point2d.interpolateFrom q1 q2 t

        r2 =
            Point2d.interpolateFrom q2 q3 t
    in
    Point2d.interpolateFrom r1 r2 t


{-| Get points along a spline at a given set of parameter values:

    exampleSpline
        |> CubicSpline2d.pointsAt
            (ParameterValue.steps 2)
    --> [ Point2d.fromCoordinates ( 1, 1 )
    --> , Point2d.fromCoordinates ( 4, 2.5 )
    --> , Point2d.fromCoordinates ( 7, 4 )
    --> ]

-}
pointsAt : List ParameterValue -> CubicSpline2d units coordinates -> List (Point2d units coordinates)
pointsAt parameterValues spline =
    List.map (pointOn spline) parameterValues


{-| If a curve has zero length (consists of just a single point), then we say
that it is 'degenerate'. Some operations such as computing tangent directions
are not defined on degenerate curves.

A `Nondegenerate` value represents a spline that is definitely not degenerate.
It is used as input to functions such as `CubicSpline2d.tangentDirection` and
can be constructed using `CubicSpline2d.nondegenerate`.

-}
type Nondegenerate units coordinates
    = NonZeroThirdDerivative (CubicSpline2d units coordinates) (Direction2d coordinates)
    | NonZeroSecondDerivative (CubicSpline2d units coordinates) (Direction2d coordinates)
    | NonZeroFirstDerivative (CubicSpline2d units coordinates) (Direction2d coordinates)


{-| Attempt to construct a nondegenerate spline from a general `CubicSpline2d`.
If the spline is in fact degenerate (consists of a single point), returns an
`Err` with that point.

    CubicSpline2d.nondegenerate exampleSpline
    --> Ok nondegenerateExampleSpline

-}
nondegenerate : CubicSpline2d units coordinates -> Result (Point2d units coordinates) (Nondegenerate units coordinates)
nondegenerate spline =
    case Vector2d.direction (thirdDerivative spline) of
        Just direction ->
            -- Third derivative is non-zero, so if all else fails we can fall
            -- back on it to provide a tangent direction
            Ok (NonZeroThirdDerivative spline direction)

        Nothing ->
            let
                -- Third derivative is zero, so second derivative is constant -
                -- evaluate it at an arbitrary point to get its value
                secondDerivativeVector =
                    secondDerivative spline ParameterValue.zero
            in
            case Vector2d.direction secondDerivativeVector of
                Just direction ->
                    -- Second derivative is non-zero, so if all else fails we
                    -- can fall back on it to provide a tangent direction
                    Ok (NonZeroSecondDerivative spline direction)

                Nothing ->
                    let
                        -- Second and third derivatives are zero, so first
                        -- derivative is constant - evaluate it at an arbitrary
                        -- point to get its value
                        firstDerivativeVector =
                            firstDerivative spline ParameterValue.zero
                    in
                    case Vector2d.direction firstDerivativeVector of
                        Just direction ->
                            -- First derivative is constant and non-zero, so the
                            -- tangent direction will always be equal to the
                            -- first derivative direction
                            Ok (NonZeroFirstDerivative spline direction)

                        Nothing ->
                            Err (startPoint spline)


{-| Convert a nondegenerate spline back to a general `CubicSpline2d`.

    CubicSpline2d.fromNondegenerate
        nondegenerateExampleSpline
    --> exampleSpline

-}
fromNondegenerate : Nondegenerate units coordinates -> CubicSpline2d units coordinates
fromNondegenerate nondegenerateSpline =
    case nondegenerateSpline of
        NonZeroThirdDerivative spline _ ->
            spline

        NonZeroSecondDerivative spline _ ->
            spline

        NonZeroFirstDerivative spline _ ->
            spline


{-| Get the tangent direction to a nondegenerate spline at a given parameter
value:

    CubicSpline2d.tangentDirection
        nondegenerateExampleSpline
        ParameterValue.zero
    --> Direction2d.fromAngle (degrees 56.31)

    CubicSpline2d.tangentDirection
        nondegenerateExampleSpline
        ParameterValue.half
    --> Direction2d.fromAngle (degrees 0)

    CubicSpline2d.tangentDirection
        nondegenerateExampleSpline
        ParameterValue.one
    --> Direction2d.fromAngle (degrees 56.31)

-}
tangentDirection : Nondegenerate units coordinates -> ParameterValue -> Direction2d coordinates
tangentDirection nondegenerateSpline parameterValue =
    case nondegenerateSpline of
        NonZeroFirstDerivative spline firstDerivativeDirection ->
            -- Tangent direction is always equal to the (constant) first
            -- derivative direction
            firstDerivativeDirection

        NonZeroSecondDerivative spline secondDerivativeDirection ->
            let
                firstDerivativeVector =
                    firstDerivative spline parameterValue
            in
            case Vector2d.direction firstDerivativeVector of
                Just firstDerivativeDirection ->
                    -- First derivative is non-zero, so use its direction as the
                    -- tangent direction (normal case)
                    firstDerivativeDirection

                Nothing ->
                    -- Zero first derivative and non-zero second derivative mean
                    -- we have reached a reversal point, where the tangent
                    -- direction just afterwards is equal to the second
                    -- derivative direction and the tangent direction just
                    -- before is equal to the reversed second derivative
                    -- direction. If we happen to be right at the end of the
                    -- spline, choose the tangent direction just before the end
                    -- (instead of one that is off the spline!), otherwise
                    -- choose the tangent direction just after the point
                    -- (necessary for t = 0, arbitrary for all other points).
                    if parameterValue == ParameterValue.one then
                        Direction2d.reverse secondDerivativeDirection

                    else
                        secondDerivativeDirection

        NonZeroThirdDerivative spline thirdDerivativeDirection ->
            let
                firstDerivativeVector =
                    firstDerivative spline parameterValue
            in
            case Vector2d.direction firstDerivativeVector of
                Just firstDerivativeDirection ->
                    -- First derivative is non-zero, so use its direction as the
                    -- tangent direction (normal case)
                    firstDerivativeDirection

                Nothing ->
                    let
                        secondDerivativeVector =
                            secondDerivative spline parameterValue
                    in
                    case Vector2d.direction secondDerivativeVector of
                        Just secondDerivativeDirection ->
                            -- Zero first derivative and non-zero second
                            -- derivative mean we have reached a reversal point,
                            -- as above in the NonZeroSecondDerivative case
                            if parameterValue == ParameterValue.one then
                                Direction2d.reverse secondDerivativeDirection

                            else
                                secondDerivativeDirection

                        Nothing ->
                            -- First and second derivatives are zero, so fall
                            -- back to the third derivative direction
                            thirdDerivativeDirection


{-| Get tangent directions to a nondegenerate spline at a given set of parameter
values:

    nondegenerateExampleSpline
        |> CubicSpline2d.tangentDirectionsAt
            (ParameterValue.steps 2)
    --> [ Direction2d.fromAngle (degrees 56.31)
    --> , Direction2d.fromAngle (degrees 0)
    --> , Direction2d.fromAngle (degrees 56.31)
    --> ]

-}
tangentDirectionsAt : List ParameterValue -> Nondegenerate units coordinates -> List (Direction2d coordinates)
tangentDirectionsAt parameterValues nondegenerateSpline =
    List.map (tangentDirection nondegenerateSpline) parameterValues


{-| Get both the point and tangent direction of a nondegenerate spline at a
given parameter value:

    CubicSpline2d.sample nondegenerateExampleSpline
        ParameterValue.half
    --> ( Point2d.fromCoordinates ( 4, 2.5 )
    --> , Direction2d.fromAngle (degrees 0)
    --> )

-}
sample : Nondegenerate units coordinates -> ParameterValue -> ( Point2d units coordinates, Direction2d coordinates )
sample nondegenerateSpline parameterValue =
    ( pointOn (fromNondegenerate nondegenerateSpline) parameterValue
    , tangentDirection nondegenerateSpline parameterValue
    )


{-| Get points and tangent directions of a nondegenerate spline at a given set
of parameter values:

    nondegenerateExampleSpline
        |> CubicSpline2d.samplesAt
            (ParameterValue.steps 2)
    --> [ ( Point2d.fromCoordinates ( 1, 1 )
    -->   , Direction2d.fromAngle (degrees 56.31)
    -->   )
    --> , ( Point2d.fromCoordinates ( 4, 2.5 )
    -->   , Direction2d.fromAngle (degrees 0)
    -->   )
    --> , ( Point2d.fromCoordinates ( 7, 4 )
    -->   , Direction2d.fromAngle (degrees 56.31)
    -->   )
    --> ]

-}
samplesAt : List ParameterValue -> Nondegenerate units coordinates -> List ( Point2d units coordinates, Direction2d coordinates )
samplesAt parameterValues nondegenerateSpline =
    List.map (sample nondegenerateSpline) parameterValues


{-| Reverse a spline so that the start point becomes the end point, and vice
versa.

    CubicSpline2d.reverse exampleSpline
    --> CubicSpline2d.with
    -->     { startPoint =
    -->         Point2d.fromCoordinates ( 7, 4 )
    -->     , startControlPoint =
    -->         Point2d.fromCoordinates ( 5, 1 )
    -->     , endControlPoint =
    -->         Point2d.fromCoordinates ( 3, 4 )
    -->     , endPoint =
    -->         Point2d.fromCoordinates ( 1, 1 )
    -->     }

-}
reverse : CubicSpline2d units coordinates -> CubicSpline2d units coordinates
reverse spline =
    with
        { startPoint = endPoint spline
        , startControlPoint = endControlPoint spline
        , endControlPoint = startControlPoint spline
        , endPoint = startPoint spline
        }


{-| Scale a spline about the given center point by the given scale.

    CubicSpline2d.scaleAbout Point2d.origin 2 exampleSpline
    --> CubicSpline2d.with
    -->     { startPoint =
    -->         Point2d.fromCoordinates ( 2, 2 )
    -->     , startControlPoint =
    -->         Point2d.fromCoordinates ( 6, 8 )
    -->     , endControlPoint =
    -->         Point2d.fromCoordinates ( 10, 2 )
    -->     , endPoint =
    -->         Point2d.fromCoordinates ( 14, 8 )
    -->     }

-}
scaleAbout : Point2d units coordinates -> Float -> CubicSpline2d units coordinates -> CubicSpline2d units coordinates
scaleAbout point scale spline =
    mapControlPoints (Point2d.scaleAbout point scale) spline


{-| Rotate a spline counterclockwise around a given center point by a given
angle (in radians).

    exampleSpline
        |> CubicSpline2d.rotateAround Point2d.origin
            (degrees 90)
    --> CubicSpline2d.with
    -->     { startPoint =
    -->         Point2d.fromCoordinates ( -1, 1 )
    -->     , startControlPoint =
    -->         Point2d.fromCoordinates ( -4, 3 )
    -->     , endControlPoint =
    -->         Point2d.fromCoordinates ( -1, 5 )
    -->     , endPoint =
    -->         Point2d.fromCoordinates ( -4, 7 )
    -->     }

-}
rotateAround : Point2d units coordinates -> Angle -> CubicSpline2d units coordinates -> CubicSpline2d units coordinates
rotateAround point angle spline =
    mapControlPoints (Point2d.rotateAround point angle) spline


{-| Translate a spline by a given displacement.

    displacement =
        Vector2d.fromComponents ( 2, 3 )

    CubicSpline2d.translateBy displacement exampleSpline
    --> CubicSpline2d.with
    -->     { startPoint =
    -->         Point2d.fromCoordinates ( 3, 4 )
    -->     , startControlPoint =
    -->         Point2d.fromCoordinates ( 5, 7 )
    -->     , endControlPoint =
    -->         Point2d.fromCoordinates ( 7, 4 )
    -->     , endPoint =
    -->         Point2d.fromCoordinates ( 9, 7 )
    -->     }

-}
translateBy : Vector2d units coordinates -> CubicSpline2d units coordinates -> CubicSpline2d units coordinates
translateBy displacement spline =
    mapControlPoints (Point2d.translateBy displacement) spline


{-| Translate a spline in a given direction by a given distance;

    CubicSpline2d.translateIn direction distance

is equivalent to

    CubicSpline2d.translateBy
        (Vector2d.withLength distance direction)

-}
translateIn : Direction2d coordinates -> Quantity Float units -> CubicSpline2d units coordinates -> CubicSpline2d units coordinates
translateIn direction distance spline =
    translateBy (Vector2d.withLength distance direction) spline


{-| Mirror a spline across an axis.

    CubicSpline2d.mirrorAcross Axis2d.x exampleSpline
    --> CubicSpline2d.with
    -->     { startPoint =
    -->         Point2d.fromCoordinates ( 1, -1 )
    -->     , startControlPoint =
    -->         Point2d.fromCoordinates ( 3, -4 )
    -->     , endControlPoint =
    -->         Point2d.fromCoordinates ( 5, -1 )
    -->     , endPoint =
    -->         Point2d.fromCoordinates ( 7, -4 )
    -->     }

-}
mirrorAcross : Axis2d units coordinates -> CubicSpline2d units coordinates -> CubicSpline2d units coordinates
mirrorAcross axis spline =
    mapControlPoints (Point2d.mirrorAcross axis) spline


{-| Take a spline defined in global coordinates, and return it expressed in
local coordinates relative to a given reference frame.

    localFrame =
        Frame2d.atPoint (Point2d.fromCoordinates ( 1, 2 ))

    CubicSpline2d.relativeTo localFrame exampleSpline
    --> CubicSpline2d.with
    -->     { startPoint =
    -->         Point2d.fromCoordinates ( 0, -1 )
    -->     , startControlPoint =
    -->         Point2d.fromCoordinates ( 2, 2 )
    -->     , endControlPoint =
    -->         Point2d.fromCoordinates ( 4, -1 )
    -->     , endPoint =
    -->         Point2d.fromCoordinates ( 6, 2 )
    -->     }

-}
relativeTo : Frame2d units globalCoordinates { defines : localCoordinates } -> CubicSpline2d units globalCoordinates -> CubicSpline2d units localCoordinates
relativeTo frame spline =
    mapControlPoints (Point2d.relativeTo frame) spline


{-| Take a spline considered to be defined in local coordinates relative to a
given reference frame, and return that spline expressed in global coordinates.

    localFrame =
        Frame2d.atPoint (Point2d.fromCoordinates ( 1, 2 ))

    CubicSpline2d.placeIn localFrame exampleSpline
    --> CubicSpline2d.with
    -->     { startPoint =
    -->         Point2d.fromCoordinates ( 2, 3 )
    -->     , startControlPoint =
    -->         Point2d.fromCoordinates ( 4, 6 )
    -->     , endControlPoint =
    -->         Point2d.fromCoordinates ( 6, 3 )
    -->     , endPoint =
    -->         Point2d.fromCoordinates ( 8, 6 )
    -->     }

-}
placeIn : Frame2d units globalCoordinates { defines : localCoordinates } -> CubicSpline2d units localCoordinates -> CubicSpline2d units globalCoordinates
placeIn frame spline =
    mapControlPoints (Point2d.placeIn frame) spline


mapControlPoints : (Point2d units1 coordinates1 -> Point2d units2 coordinates2) -> CubicSpline2d units1 coordinates1 -> CubicSpline2d units2 coordinates2
mapControlPoints function spline =
    with
        { startPoint = function (startPoint spline)
        , startControlPoint = function (startControlPoint spline)
        , endControlPoint = function (endControlPoint spline)
        , endPoint = function (endPoint spline)
        }


{-| Split a spline into two roughly equal halves.

    CubicSpline2d.bisect exampleSpline
    --> ( CubicSpline2d.with
    -->     { startPoint =
    -->         Point2d.fromCoordinates ( 1, 1 )
    -->     , startControlPoint =
    -->         Point2d.fromCoordinates ( 2, 2.5 )
    -->     , endControlPoint =
    -->         Point2d.fromCoordinates ( 3, 2.5 )
    -->     , endPoint =
    -->         Point2d.fromCoordinates ( 4, 2.5 )
    -->     }
    --> , CubicSpline2d.with
    -->     { startPoint =
    -->         Point2d.fromCoordinates ( 4, 2.5 )
    -->     , startControlPoint =
    -->         Point2d.fromCoordinates ( 5, 2.5 )
    -->     , endControlPoint =
    -->         Point2d.fromCoordinates ( 6, 2.5 )
    -->     , endPoint =
    -->         Point2d.fromCoordinates ( 7, 4 )
    -->     }
    --> )

Equivalent to `CubicSpline2d.splitAt ParameterValue.half`.

-}
bisect : CubicSpline2d units coordinates -> ( CubicSpline2d units coordinates, CubicSpline2d units coordinates )
bisect spline =
    splitAt ParameterValue.half spline


{-| Split a spline at a particular parameter value, resulting in two smaller
splines.

    parameterValue =
        ParameterValue.clamped 0.75

    CubicSpline2d.splitAt parameterValue exampleSpline
    --> ( CubicSpline2d.with
    -->     { startPoint =
    -->         Point2d.fromCoordinates ( 1, 1 )
    -->     , startControlPoint =
    -->         Point2d.fromCoordinates ( 2.5, 3.25 )
    -->     , endControlPoint =
    -->         Point2d.fromCoordinates ( 4, 2.125 )
    -->     , endPoint =
    -->         Point2d.fromCoordinates ( 5.5, 2.6875 )
    -->     }
    --> , CubicSpline2d.with
    -->     { startPoint =
    -->         Point2d.fromCoordinates ( 5.5, 2.6875 )
    -->     , startControlPoint =
    -->         Point2d.fromCoordinates ( 6, 2.875 )
    -->     , endControlPoint =
    -->         Point2d.fromCoordinates ( 6.5, 3.25 )
    -->     , endPoint =
    -->         Point2d.fromCoordinates ( 7, 4 )
    -->     }
    --> )

-}
splitAt : ParameterValue -> CubicSpline2d units coordinates -> ( CubicSpline2d units coordinates, CubicSpline2d units coordinates )
splitAt parameterValue spline =
    let
        t =
            ParameterValue.value parameterValue

        p1 =
            startPoint spline

        p2 =
            startControlPoint spline

        p3 =
            endControlPoint spline

        p4 =
            endPoint spline

        q1 =
            Point2d.interpolateFrom p1 p2 t

        q2 =
            Point2d.interpolateFrom p2 p3 t

        q3 =
            Point2d.interpolateFrom p3 p4 t

        r1 =
            Point2d.interpolateFrom q1 q2 t

        r2 =
            Point2d.interpolateFrom q2 q3 t

        s =
            Point2d.interpolateFrom r1 r2 t
    in
    ( with
        { startPoint = p1
        , startControlPoint = q1
        , endControlPoint = r1
        , endPoint = s
        }
    , with
        { startPoint = s
        , startControlPoint = r2
        , endControlPoint = q3
        , endPoint = p4
        }
    )


{-| A spline that has been parameterized by arc length.
-}
type ArcLengthParameterized units coordinates
    = ArcLengthParameterized
        { underlyingSpline : CubicSpline2d units coordinates
        , parameterization : ArcLengthParameterization units
        , nondegenerateSpline : Maybe (Nondegenerate units coordinates)
        }


{-| Build an arc length parameterization of the given spline, with a given
accuracy. Generally speaking, all operations on the resulting
`ArcLengthParameterized` value will be accurate to within the specified maximum
error.

    parameterizedSpline =
        exampleSpline
            |> CubicSpline2d.arcLengthParameterized
                { maxError = 1.0e-4 }

The accuracy of the parameterization affects the accuracy of results returned
from functions such as `arcLength` and `pointAlong`.

-}
arcLengthParameterized : { maxError : Quantity Float units } -> CubicSpline2d units coordinates -> ArcLengthParameterized units coordinates
arcLengthParameterized { maxError } spline =
    let
        parameterization =
            ArcLengthParameterization.build
                { maxError = maxError
                , derivativeMagnitude = derivativeMagnitude spline
                , maxSecondDerivativeMagnitude =
                    maxSecondDerivativeMagnitude spline
                }
    in
    ArcLengthParameterized
        { underlyingSpline = spline
        , parameterization = parameterization
        , nondegenerateSpline = Result.toMaybe (nondegenerate spline)
        }


{-| Find the total arc length of a spline:

    arcLength =
        CubicSpline2d.arcLength parameterizedSpline

    arcLength
    --> 7.0952

In this example, the result will be accurate to within `1.0e-4` since that was
the tolerance used when constructing `parameterizedSpline`.

-}
arcLength : ArcLengthParameterized units coordinates -> Quantity Float units
arcLength parameterizedSpline =
    arcLengthParameterization parameterizedSpline
        |> ArcLengthParameterization.totalArcLength


{-| Get the midpoint of the spline.

    CubicSpline2d.midpoint parameterizedSpline
    --> Point2d.fromCoordinates (3.999999999999992, 2.5)

-}
midpoint : ArcLengthParameterized units coordinates -> Point2d units coordinates
midpoint parameterized =
    let
        halfArcLength =
            Quantity.scaleBy 0.5 (arcLength parameterized)
    in
    case pointAlong parameterized halfArcLength of
        Just point ->
            point

        Nothing ->
            -- Should never happen since half of total arc length will always
            -- be a valid distance along the curve, but let's default to something
            -- reasonable anyways
            startPoint (fromArcLengthParameterized parameterized)


{-| Try to get the point along a spline at a given arc length. For example, to
get the point a quarter of the way along `exampleSpline`, using `arcLength` as
computed above:

    CubicSpline2d.pointAlong parameterizedSpline
        (0.25 * arcLength)
    --> Just (Point2d.fromCoordinates ( 2.2681, 2.2114 ))

Note that this is not the same as evaulating at a parameter value of 0.25:

    CubicSpline2d.pointOn exampleSpline
        (ParameterValue.clamped 0.25)
    --> Point2d.fromCoordinates ( 2.5, 2.3125 )

If the given arc length is less than zero or greater than the arc length of the
spline, returns `Nothing`.

-}
pointAlong : ArcLengthParameterized units coordinates -> Quantity Float units -> Maybe (Point2d units coordinates)
pointAlong (ArcLengthParameterized parameterized) distance =
    parameterized.parameterization
        |> ArcLengthParameterization.arcLengthToParameterValue distance
        |> Maybe.map (pointOn parameterized.underlyingSpline)


{-| Try to get the tangent direction along a spline at a given arc length. To
get the tangent direction a quarter of the way along `exampleSpline`:

    CubicSpline2d.tangentDirectionAlong parameterizedSpline
        (0.25 * arcLength)
    --> Just (Direction2d.fromAngle (degrees 26.5611))

If the given arc length is less than zero or greater than the arc length of the
spline (or if the spline is degenerate), returns `Nothing`.

-}
tangentDirectionAlong : ArcLengthParameterized units coordinates -> Quantity Float units -> Maybe (Direction2d coordinates)
tangentDirectionAlong (ArcLengthParameterized parameterized) distance =
    case parameterized.nondegenerateSpline of
        Just nondegenerateSpline ->
            parameterized.parameterization
                |> ArcLengthParameterization.arcLengthToParameterValue distance
                |> Maybe.map (tangentDirection nondegenerateSpline)

        Nothing ->
            Nothing


{-| Try to get the point and tangent direction along a spline at a given arc
length. To get the point and tangent direction a quarter of the way along
`exampleSpline`:

    CubicSpline2d.sampleAlong parameterizedSpline
        (0.25 * arcLength)
    --> Just
    -->     ( Point2d.fromCoordinates ( 2.2681, 2.2114 )
    -->     , Direction2d.fromAngle (degrees 26.5611)
    -->     )

If the given arc length is less than zero or greater than the arc length of the
spline (or if the spline is degenerate), returns `Nothing`.

-}
sampleAlong : ArcLengthParameterized units coordinates -> Quantity Float units -> Maybe ( Point2d units coordinates, Direction2d coordinates )
sampleAlong (ArcLengthParameterized parameterized) distance =
    case parameterized.nondegenerateSpline of
        Just nondegenerateSpline ->
            parameterized.parameterization
                |> ArcLengthParameterization.arcLengthToParameterValue distance
                |> Maybe.map (sample nondegenerateSpline)

        Nothing ->
            Nothing


{-| -}
arcLengthParameterization : ArcLengthParameterized units coordinates -> ArcLengthParameterization units
arcLengthParameterization (ArcLengthParameterized parameterized) =
    parameterized.parameterization


{-| -}
fromArcLengthParameterized : ArcLengthParameterized units coordinates -> CubicSpline2d units coordinates
fromArcLengthParameterized (ArcLengthParameterized parameterized) =
    parameterized.underlyingSpline


{-| Get the first derivative of a spline at a given parameter value:

    CubicSpline2d.firstDerivative exampleSpline
        ParameterValue.zero
    --> Vector2d.fromComponents ( 6, 9 )

    CubicSpline2d.firstDerivative exampleSpline
        ParameterValue.half
    --> Vector2d.fromComponents ( 6, 0 )

    CubicSpline2d.firstDerivative exampleSpline
        ParameterValue.one
    --> Vector2d.fromComponents ( 6, 9 )

-}
firstDerivative : CubicSpline2d units coordinates -> ParameterValue -> Vector2d units coordinates
firstDerivative spline parameterValue =
    let
        t =
            ParameterValue.value parameterValue

        p1 =
            startPoint spline

        p2 =
            startControlPoint spline

        p3 =
            endControlPoint spline

        p4 =
            endPoint spline

        ( x1, y1 ) =
            Point2d.coordinates p1

        ( x2, y2 ) =
            Point2d.coordinates p2

        ( x3, y3 ) =
            Point2d.coordinates p3

        ( x4, y4 ) =
            Point2d.coordinates p4

        vx1 =
            x2 |> Quantity.minus x1

        vy1 =
            y2 |> Quantity.minus y1

        vx2 =
            x3 |> Quantity.minus x2

        vy2 =
            y3 |> Quantity.minus y2

        vx3 =
            x4 |> Quantity.minus x3

        vy3 =
            y4 |> Quantity.minus y3
    in
    if t <= 0.5 then
        let
            wx1 =
                vx1
                    |> Quantity.plus
                        (Quantity.scaleBy t (vx2 |> Quantity.minus vx1))

            wy1 =
                vy1
                    |> Quantity.plus
                        (Quantity.scaleBy t (vy2 |> Quantity.minus vy1))

            wx2 =
                vx2
                    |> Quantity.plus
                        (Quantity.scaleBy t (vx3 |> Quantity.minus vx2))

            wy2 =
                vy2
                    |> Quantity.plus
                        (Quantity.scaleBy t (vy3 |> Quantity.minus vy2))
        in
        Vector2d.fromComponents
            ( Quantity.scaleBy 3
                (wx1
                    |> Quantity.plus
                        (Quantity.scaleBy t (wx2 |> Quantity.minus wx1))
                )
            , Quantity.scaleBy 3
                (wy1
                    |> Quantity.plus
                        (Quantity.scaleBy t (wy2 |> Quantity.minus wy1))
                )
            )

    else
        let
            u =
                1 - t

            wx1 =
                vx2
                    |> Quantity.plus
                        (Quantity.scaleBy u (vx1 |> Quantity.minus vx2))

            wy1 =
                vy2
                    |> Quantity.plus
                        (Quantity.scaleBy u (vy1 |> Quantity.minus vy2))

            wx2 =
                vx3
                    |> Quantity.plus
                        (Quantity.scaleBy u (vx2 |> Quantity.minus vx3))

            wy2 =
                vy3
                    |> Quantity.plus
                        (Quantity.scaleBy u (vy2 |> Quantity.minus vy3))
        in
        Vector2d.fromComponents
            ( Quantity.scaleBy 3
                (wx2
                    |> Quantity.plus
                        (Quantity.scaleBy u (wx1 |> Quantity.minus wx2))
                )
            , Quantity.scaleBy 3
                (wy2
                    |> Quantity.plus
                        (Quantity.scaleBy u (wy1 |> Quantity.minus wy2))
                )
            )


{-| Evaluate the first derivative of a spline at a given set of parameter
values:

    exampleSpline
        |> CubicSpline2d.firstDerivativesAt
            (ParameterValue.steps 2)
    --> [ Vector2d.fromComponents ( 6, 9 )
    --> , Vector2d.fromComponents ( 6, 0 )
    --> , Vector2d.fromComponents ( 6, 9 )
    --> ]

-}
firstDerivativesAt : List ParameterValue -> CubicSpline2d units coordinates -> List (Vector2d units coordinates)
firstDerivativesAt parameterValues spline =
    List.map (firstDerivative spline) parameterValues


{-| Evaluate the second derivative of a spline at a given parameter value:

    CubicSpline2d.secondDerivativeAt 0 exampleSpline
    --> Just (Vector2d.fromComponents ( 0, -36 ))

    CubicSpline2d.secondDerivativeAt 0.5 exampleSpline
    --> Just (Vector2d.fromComponents ( 0, 0 ))

    CubicSpline2d.secondDerivativeAt 1 exampleSpline
    --> Just (Vector2d.fromComponents ( 0, 36 ))

-}
secondDerivative : CubicSpline2d units coordinates -> ParameterValue -> Vector2d units coordinates
secondDerivative spline parameterValue =
    let
        t =
            ParameterValue.value parameterValue

        p1 =
            startPoint spline

        p2 =
            startControlPoint spline

        p3 =
            endControlPoint spline

        p4 =
            endPoint spline

        u1 =
            Vector2d.from p1 p2

        u2 =
            Vector2d.from p2 p3

        u3 =
            Vector2d.from p3 p4

        v1 =
            Vector2d.difference u2 u1

        v2 =
            Vector2d.difference u3 u2
    in
    Vector2d.scaleBy 6 (Vector2d.interpolateFrom v1 v2 t)


{-| Evaluate the second derivative of a spline at a given set of parameter
values:

    exampleSpline
        |> CubicSpline2d.secondDerivativesAt
            (ParameterValue.steps 2)
    --> [ Vector2d.fromComponents ( 0, -36 )
    --> , Vector2d.fromComponents ( 0, 0 )
    --> , Vector2d.fromComponents ( 0, 36 )
    --> ]

-}
secondDerivativesAt : List ParameterValue -> CubicSpline2d units coordinates -> List (Vector2d units coordinates)
secondDerivativesAt parameterValues spline =
    List.map (secondDerivative spline) parameterValues


{-| Get the third derivative of a spline (for a cubic spline, this is a
constant):

    CubicSpline2d.thirdDerivative exampleSpline
    --> Vector2d.fromComponents ( 0, 72 )

-}
thirdDerivative : CubicSpline2d units coordinates -> Vector2d units coordinates
thirdDerivative spline =
    let
        p1 =
            startPoint spline

        p2 =
            startControlPoint spline

        p3 =
            endControlPoint spline

        p4 =
            endPoint spline

        u1 =
            Vector2d.from p1 p2

        u2 =
            Vector2d.from p2 p3

        u3 =
            Vector2d.from p3 p4

        v1 =
            Vector2d.difference u2 u1

        v2 =
            Vector2d.difference u3 u2
    in
    Vector2d.scaleBy 6 (Vector2d.difference v2 v1)


{-| Find a conservative upper bound on the magnitude of the second derivative of
a spline. This can be useful when determining error bounds for various kinds of
linear approximations.

    exampleSpline
        |> CubicSpline2d.maxSecondDerivativeMagnitude
    --> 36

-}
maxSecondDerivativeMagnitude : CubicSpline2d units coordinates -> Quantity Float units
maxSecondDerivativeMagnitude spline =
    let
        p1 =
            startPoint spline

        p2 =
            startControlPoint spline

        p3 =
            endControlPoint spline

        p4 =
            endPoint spline

        u1 =
            Vector2d.from p1 p2

        u2 =
            Vector2d.from p2 p3

        u3 =
            Vector2d.from p3 p4

        v1 =
            Vector2d.difference u2 u1

        v2 =
            Vector2d.difference u3 u2
    in
    6 * max (Vector2d.length v1) (Vector2d.length v2)


derivativeMagnitude : CubicSpline2d units coordinates -> ParameterValue -> Quantity Float units
derivativeMagnitude spline =
    let
        p1 =
            startPoint spline

        p2 =
            startControlPoint spline

        p3 =
            endControlPoint spline

        p4 =
            endPoint spline

        ( x1, y1 ) =
            Point2d.coordinates p1

        ( x2, y2 ) =
            Point2d.coordinates p2

        ( x3, y3 ) =
            Point2d.coordinates p3

        ( x4, y4 ) =
            Point2d.coordinates p4

        x12 =
            x2 |> Quantity.minus x1

        y12 =
            y2 |> Quantity.minus y1

        x23 =
            x3 |> Quantity.minus x2

        y23 =
            y3 |> Quantity.minus y2

        x34 =
            x4 |> Quantity.minus x3

        y34 =
            y4 |> Quantity.minus y3

        x123 =
            x23 |> Quantity.minus x12

        y123 =
            y23 |> Quantity.minus y12

        x234 =
            x34 |> Quantity.minus x23

        y234 =
            y34 |> Quantity.minus y23
    in
    \parameterValue ->
        let
            t =
                ParameterValue.value parameterValue

            x13 =
                x12 |> Quantity.plus (Quantity.scaleBy t x123)

            y13 =
                y12 |> Quantity.plus (Quantity.scaleBy t y123)

            x24 =
                x23 |> Quantity.plus (Quantity.scaleBy t x234)

            y24 =
                y23 |> Quantity.plus (Quantity.scaleBy t y234)

            x14 =
                x13 |> Quantity.plus (Quantity.scaleBy t (x24 - x13))

            y14 =
                y13 |> Quantity.plus (Quantity.scaleBy t (y24 - y13))
        in
        Quantity.scaleBy 3
            (Quantity.sqrt
                (Quantity.squared x14 |> Quantity.plus (Quantity.squared y14))
            )
