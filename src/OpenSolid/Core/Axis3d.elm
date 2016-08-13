{- This Source Code Form is subject to the terms of the Mozilla Public License,
   v. 2.0. If a copy of the MPL was not distributed with this file, you can
   obtain one at http://mozilla.org/MPL/2.0/.

   Copyright 2016 by Ian Mackenzie
   ian.e.mackenzie@gmail.com
-}


module OpenSolid.Core.Axis3d
    exposing
        ( x
        , y
        , z
        , originPoint
        , direction
        , flip
        , rotateAround
        , translateBy
        , moveTo
        , mirrorAcross
        , projectOnto
        , relativeTo
        , placeIn
        , projectInto2d
        )

{-| Various functions for creating and working with `Axis3d` values. For the
examples below, assume that all OpenSolid core types have been imported using

    import OpenSolid.Core.Types exposing (..)

and all necessary modules have been imported using the following pattern:

    import OpenSolid.Core.Axis3d as Axis3d

Examples use `==` to indicate that two expressions are equivalent, even if (due
to numerical roundoff) they might not be exactly equal.

# Predefined axes

@docs x, y, z

# Constructors

Axes can by constructed by passing a record with `originPoint` and `direction`
fields to the `Axis3d` constructor, for example:

    axis =
        Axis3d
            { originPoint = Point3d ( 2, 1, 3 )
            , direction = Direction3d.y
            }

# Accessors

@docs originPoint, direction

# Transformations

@docs flip, rotateAround, translateBy, moveTo, mirrorAcross, projectOnto

# Coordinate transformations

@docs relativeTo, placeIn, projectInto2d
-}

import OpenSolid.Core.Types exposing (..)
import OpenSolid.Core.Point3d as Point3d
import OpenSolid.Core.Direction3d as Direction3d


{-| The global X axis.

    Axis3d.x ==
        Axis3d
            { originPoint = Point3d.origin
            , direction = Direction3d.x
            }
-}
x : Axis3d
x =
    Axis3d { originPoint = Point3d.origin, direction = Direction3d.x }


{-| The global Y axis.

    Axis3d.y ==
        Axis3d
            { originPoint = Point3d.origin
            , direction = Direction3d.y
            }
-}
y : Axis3d
y =
    Axis3d { originPoint = Point3d.origin, direction = Direction3d.y }


{-| The global Z axis.

    Axis3d.z ==
        Axis3d
            { originPoint = Point3d.origin
            , direction = Direction3d.z
            }
-}
z : Axis3d
z =
    Axis3d { originPoint = Point3d.origin, direction = Direction3d.z }


{-| Get the origin point of an axis.

    Axis3d.originPoint Axis3d.x ==
        Point3d.origin
-}
originPoint : Axis3d -> Point3d
originPoint (Axis3d properties) =
    properties.originPoint


{-| Get the direction of an axis.

    Axis3d.direction Axis3d.y ==
        Direction3d.y
-}
direction : Axis3d -> Direction3d
direction (Axis3d properties) =
    properties.direction


{-| Reverse the direction of an axis while keeping the same origin point.

    Axis3d.flip Axis3d.x ==
        Axis3d
            { originPoint = Point3d.origin
            , direction = Direction3d ( -1, 0, 0 )
            }
-}
flip : Axis3d -> Axis3d
flip axis =
    Axis3d
        { originPoint = originPoint axis
        , direction = Direction3d.negate (direction axis)
        }


{-| Rotate an axis around another axis by a given angle. The axis to rotate
around is given first and the axis to rotate is given last.

    Axis3d.rotateAround Axis3d.x (degrees 90) Axis3d.y ==
        Axis3d.z
-}
rotateAround : Axis3d -> Float -> Axis3d -> Axis3d
rotateAround otherAxis angle =
    let
        rotatePoint =
            Point3d.rotateAround otherAxis angle

        rotateDirection =
            Direction3d.rotateAround otherAxis angle
    in
        \axis ->
            Axis3d
                { originPoint = rotatePoint (originPoint axis)
                , direction = rotateDirection (direction axis)
                }


{-| Translate an axis by a given displacement. Applies the given displacement to
the axis' origin point.

    displacement =
        Vector3d ( 2, 1, 3 )

    Axis3d.translateBy displacement Axis3d.y ==
        Axis3d
            { originPoint = Point3d ( 2, 1, 3 )
            , direction = Direction3d.y
            }
-}
translateBy : Vector3d -> Axis3d -> Axis3d
translateBy vector axis =
    Axis3d
        { originPoint = Point3d.translateBy vector (originPoint axis)
        , direction = direction axis
        }


{-| Move an axis so that it has the given origin point but unchanged direction.

    axis =
        Axis3d
            { originPoint = Point3d ( 2, 1, 3 )
            , direction = Direction3d.y
            }

    newOrigin =
        Point3d ( 3, 4, 5 )

    Axis3d.moveTo newOrigin axis ==
        Axis3d
            { originPoint = Point3d ( 3, 4, 5 ),
            , direction = Direction3d.y
            }
-}
moveTo : Point3d -> Axis3d -> Axis3d
moveTo newOrigin axis =
    Axis3d { originPoint = newOrigin, direction = direction axis }


{-| Mirror an axis across a plane.

    axis =
        Axis3d
            { originPoint = Point3d ( 1, 2, 3 )
            , direction = Direction3d ( 0, 0.6, 0.8 )
            }

    Axis3d.mirrorAcross Plane3d.xy axis ==
        Axis3d
            { originPoint = Point3d ( 1, 2, -3 )
            , direction = Direction3d ( 0, 0.6, -0.8 )
            }
-}
mirrorAcross : Plane3d -> Axis3d -> Axis3d
mirrorAcross plane =
    let
        mirrorPoint =
            Point3d.mirrorAcross plane

        mirrorDirection =
            Direction3d.mirrorAcross plane
    in
        \axis ->
            Axis3d
                { originPoint = mirrorPoint (originPoint axis)
                , direction = mirrorDirection (direction axis)
                }


{-| Project an axis onto a plane, returning the axis that is the 'shadow' of the
given axis on the given plane. If the given axis is exactly perpendicular to the
given plane, returns `Nothing`.

    axis =
        Axis3d
            { originPoint = Point3d ( 2, 1, 3 )
            , direction = Diretion3d ( 0.6, 0, 0.8 )
            }

    Axis3d.projectOnto Plane3d.xy axis ==
        Just
            (Axis3d
                { originPoint = Point3d ( 2, 1, 0 )
                , direction = Direction3d ( 1, 0, 0 )
                }
            )

    Axis3d.projectOnto Plane3d.xy Axis3d.z ==
        Nothing
-}
projectOnto : Plane3d -> Axis3d -> Maybe Axis3d
projectOnto plane axis =
    let
        projectedOrigin =
            Point3d.projectOnto plane (originPoint axis)

        toAxis direction =
            Axis3d { originPoint = projectedOrigin, direction = direction }
    in
        Maybe.map toAxis (Direction3d.projectOnto plane (direction axis))


{-| Take an axis currently expressed in global coordinates and express it
relative to a given frame. For example, consider a frame raised up one unit
above the global XYZ frame and rotated 45 degrees clockwise around the Z axis:

    frame =
        Frame3d.xyz
            |> Frame3d.moveTo (Point3d (0, 0, 1))
            |> Frame3d.rotateAround Axis3d.z (degrees -45)

Relative to this frame, the global X axis is one unit below the origin, with
a direction halfway between the X and Y directions:

    Axis3d.relativeTo frame Axis3d.x ==
        Axis3d
            { originPoint = Point3d ( 0, 0, -1 )
            , direction = Direction3d ( 0.7071, 0.7071, 0 )
            }
-}
relativeTo : Frame3d -> Axis3d -> Axis3d
relativeTo frame =
    let
        relativePoint =
            Point3d.relativeTo frame

        relativeDirection =
            Direction3d.relativeTo frame
    in
        \axis ->
            Axis3d
                { originPoint = relativePoint (originPoint axis)
                , direction = relativeDirection (direction axis)
                }


{-| Place an axis in a given frame, considering it as being expressed relative
to that frame and returning the corresponding axis in global coordinates.
Inverse of `relativeTo`.

For example, consider a frame raised up one unit above the global XYZ frame and
rotated 45 degrees clockwise around the Z axis:

    frame =
        Frame3d.xyz
            |> Frame3d.moveTo (Point3d (0, 0, 1))
            |> Frame3d.rotateAround Axis3d.z (degrees -45)

Now, consider an axis in the X direction through the point (0, 0, 1):

    axis =
        Axis3d
            { originPoint = Point3d ( 0, 0, 1 )
            , direction = Direction3d.x
            }

Placing this axis in the given frame gives an axis that is two units above the
global origin point, with the X direction of the rotated frame:

    Axis3d.placeIn frame axis ==
        Axis3d
            { originPoint = Point3d ( 0, 0, 2 )
            , direction = Direction3d ( 0.7071, -0.7071, 0 )
            }

-}
placeIn : Frame3d -> Axis3d -> Axis3d
placeIn frame =
    let
        placePoint =
            Point3d.placeIn frame

        placeDirection =
            Direction3d.placeIn frame
    in
        \axis ->
            Axis3d
                { originPoint = placePoint (originPoint axis)
                , direction = placeDirection (direction axis)
                }


{-| Project a 3D axis into 2D, projecting it onto the plane of the given planar
frame and then expressing the projected axis in terms of 2D coordinates within
that frame. If the axis is exactly perpendicular to the plane of the given
frame, returns `Nothing`.

    axis =
        Axis3d
            { originPoint = Point3d ( 2, 1, 3 )
            , direction = Direction3d ( 0.6, -0.8, 0 )
            }

    Axis3d.projectInto2d PlanarFrame3d.xy ==
        Just
            (Axis2d
                { originPoint = Point2d ( 2, 1 )
                , direction = Direction3d ( 0.6, -0.8 )
                }
            )

    Axis3d.projectInto2d PlanarFrame3d.yz ==
        Just
            (Axis2d
                { originPoint = Point2d ( 1, 3 )
                , direction = Direction2d ( -1, 0 )
                }
            )

    Axis3d.projectInto PlanarFrame3d.xy Axis3d.z ==
        Nothing
-}
projectInto2d : PlanarFrame3d -> Axis3d -> Maybe Axis2d
projectInto2d planarFrame axis =
    let
        projectedOrigin =
            Point3d.projectInto2d planarFrame (originPoint axis)

        maybeDirection =
            Direction3d.projectInto2d planarFrame (direction axis)

        toAxis direction =
            Axis2d { originPoint = projectedOrigin, direction = direction }
    in
        Maybe.map toAxis maybeDirection
