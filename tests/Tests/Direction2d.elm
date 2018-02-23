module Tests.Direction2d
    exposing
        ( angleFromAndEqualWithinAreConsistent
        , angleFromAndRotateByAreConsistent
        , jsonRoundTrips
        , orthonormalizeProducesValidFrameBasis
        , orthonormalizingParallelVectorsReturnsNothing
        )

import Direction2d
import Expect
import Frame2d
import Fuzz
import Geometry.Decode as Decode
import Geometry.Encode as Encode
import Geometry.Expect as Expect
import Geometry.Fuzz as Fuzz
import Point2d
import Test exposing (Test)
import Tests.Generic as Generic
import Vector2d


jsonRoundTrips : Test
jsonRoundTrips =
    Generic.jsonRoundTrips Fuzz.direction2d
        Encode.direction2d
        Decode.direction2d


angleFromAndEqualWithinAreConsistent : Test
angleFromAndEqualWithinAreConsistent =
    Test.fuzz2 Fuzz.direction2d
        Fuzz.direction2d
        "angleFrom and equalWithin are consistent"
        (\firstDirection secondDirection ->
            let
                angle =
                    abs (Direction2d.angleFrom firstDirection secondDirection)
            in
            Expect.true "Two directions should be equal to within the angle between them"
                (Direction2d.equalWithin (angle + 1.0e-12)
                    firstDirection
                    secondDirection
                )
        )


angleFromAndRotateByAreConsistent : Test
angleFromAndRotateByAreConsistent =
    Test.fuzz2 Fuzz.direction2d
        Fuzz.direction2d
        "angleFrom and rotateBy are consistent"
        (\firstDirection secondDirection ->
            let
                angle =
                    Direction2d.angleFrom firstDirection secondDirection
            in
            firstDirection
                |> Direction2d.rotateBy angle
                |> Expect.direction2d secondDirection
        )


orthonormalizeProducesValidFrameBasis : Test
orthonormalizeProducesValidFrameBasis =
    Test.fuzz (Fuzz.tuple ( Fuzz.vector2d, Fuzz.vector2d ))
        "orthonormalize produces a valid frame basis"
        (\vectors ->
            case Direction2d.orthonormalize vectors of
                Just ( xDirection, yDirection ) ->
                    Expect.validFrame2d
                        (Frame2d.unsafe
                            { originPoint = Point2d.origin
                            , xDirection = xDirection
                            , yDirection = yDirection
                            }
                        )

                Nothing ->
                    let
                        ( v1, v2 ) =
                            vectors

                        crossProduct =
                            Vector2d.crossProduct v1 v2
                    in
                    Expect.approximately 0.0 crossProduct
        )


orthonormalizingParallelVectorsReturnsNothing : Test
orthonormalizingParallelVectorsReturnsNothing =
    Test.test "orthonormalizing parallel vectors returns Nothing"
        (\() ->
            let
                vectors =
                    ( Vector2d.fromComponents ( 1, 2 )
                    , Vector2d.fromComponents ( -3, -6 )
                    )
            in
            Expect.equal Nothing (Direction2d.orthonormalize vectors)
        )