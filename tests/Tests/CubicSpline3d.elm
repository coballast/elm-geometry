module Tests.CubicSpline3d exposing
    ( arcLengthMatchesAnalytical
    , fromEndpointsReproducesSpline
    , pointAtArcLengthIsEnd
    , pointAtZeroLengthIsStart
    )

import CubicSpline3d
import Expect
import Fuzz
import Geometry.Expect as Expect
import Geometry.Fuzz as Fuzz
import Quantity
import Test exposing (Test)
import Tests.QuadraticSpline3d
import Vector3d


fromEndpointsReproducesSpline : Test
fromEndpointsReproducesSpline =
    Test.fuzz Fuzz.cubicSpline3d
        "CubicSpline3d.fromEndpoints reproduces original spline"
        (\spline ->
            let
                startPoint =
                    CubicSpline3d.startPoint spline

                endPoint =
                    CubicSpline3d.endPoint spline

                startDerivative =
                    CubicSpline3d.startDerivative spline

                endDerivative =
                    CubicSpline3d.endDerivative spline
            in
            CubicSpline3d.fromEndpoints
                { startPoint = startPoint
                , startDerivative = startDerivative
                , endPoint = endPoint
                , endDerivative = endDerivative
                }
                |> Expect.cubicSpline3d spline
        )


arcLengthMatchesAnalytical : Test
arcLengthMatchesAnalytical =
    Test.fuzz Tests.QuadraticSpline3d.curvedSpline
        "arc length matches analytical formula"
        (\quadraticSpline ->
            quadraticSpline
                |> CubicSpline3d.fromQuadraticSpline
                |> CubicSpline3d.arcLengthParameterized
                    { maxError = Quantity.float 1.0e-3 }
                |> CubicSpline3d.arcLength
                |> Expect.quantityWithin (Quantity.float 1.0e-3)
                    (Tests.QuadraticSpline3d.analyticalLength quadraticSpline)
        )


pointAtZeroLengthIsStart : Test
pointAtZeroLengthIsStart =
    Test.fuzz Fuzz.cubicSpline3d
        "point along spline at zero length is start point"
        (\spline ->
            let
                parameterizedCurve =
                    spline
                        |> CubicSpline3d.arcLengthParameterized
                            { maxError = Quantity.float 1.0e-3 }
            in
            CubicSpline3d.pointAlong parameterizedCurve Quantity.zero
                |> Expect.equal (Just (CubicSpline3d.startPoint spline))
        )


pointAtArcLengthIsEnd : Test
pointAtArcLengthIsEnd =
    Test.fuzz Fuzz.cubicSpline3d
        "point along spline at arc length is end point"
        (\spline ->
            let
                parameterizedCurve =
                    spline
                        |> CubicSpline3d.arcLengthParameterized
                            { maxError = Quantity.float 1.0e-3 }

                arcLength =
                    CubicSpline3d.arcLength parameterizedCurve
            in
            CubicSpline3d.pointAlong parameterizedCurve arcLength
                |> Expect.equal (Just (CubicSpline3d.endPoint spline))
        )
