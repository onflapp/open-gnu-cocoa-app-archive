/*
    PPGNUstepGlue_BezierPathAliasing.m

    Copyright 2014-2018 Josh Freeman
    http://www.twilightedge.com

    This file is part of PikoPixel for GNUstep.
    PikoPixel is a graphical application for drawing & editing pixel-art images.

    PikoPixel is free software: you can redistribute it and/or modify it under
    the terms of the GNU Affero General Public License as published by the
    Free Software Foundation, either version 3 of the License, or (at your
    option) any later version approved for PikoPixel by its copyright holder (or
    an authorized proxy).

    PikoPixel is distributed in the hope that it will be useful, but WITHOUT ANY
    WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
    FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
    details.

    You should have received a copy of the GNU Affero General Public License
    along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

//    PPGNUstepGlue_BezierPathAliasing.m was initially meant as a workaround for GNUstep's
// antialiasing setting (path drawing would always use antialiasing, even if the graphics
// context's antialiasing setting was disabled).
//    The antialiasing setting has been since fixed for Cairo in the GNUstep trunk (2015-09-20),
// however, un-antialiased Cairo paths are drawn in different shapes than on Mac OS X: some
// pixels are missing, possibly due to roundoff.
//    Antialiased paths are also drawn differently between Cairo & OS X, however, the
// workaround below accounted for those differences, so until a workaround is developed for the
// unantialiased drawing differences, the current fix is to use antialiasing when drawing (set
// in PPGNUstepGlue_BitmapGraphcisContext.m's ppGSPatch_SetAsCurrentGraphicsContext), and
// continue to use the antialiasing workaround.

#ifdef GNUSTEP

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "NSBezierPath_PPUtilities.h"
#import "PPDocument.h"
#import "PPGeometry.h"


// disable clang warnings about fabsf() truncating passed double-type values to float-type
#ifdef __clang__
#   pragma clang diagnostic ignored "-Wabsolute-value"
#endif  // __clang__


@interface NSBezierPath (PPGNUstepGlue_BezierPathAliasingUtilities)

- (NSBezierPath *) ppGSGlue_ResegmentedPathForDrawing;

- (void) ppGSGlue_SegmentedLineToPoint: (NSPoint) endPoint lastPoint: (NSPoint) startPoint;

@end


@implementation NSObject (PPGNUstepGlue_BezierPathAliasing)

+ (void) ppGSGlue_BezierPathAliasing_InstallPatches
{
    macroSwizzleInstanceMethod(NSBezierPath, ppAppendSinglePixelLineAtPoint:,
                                ppGSPatch_AppendSinglePixelLineAtPoint:);

    macroSwizzleInstanceMethod(NSBezierPath, ppAppendLineFromPixelAtPoint:toPixelAtPoint:,
                                ppGSPatch_AppendLineFromPixelAtPoint:toPixelAtPoint:);


    macroSwizzleInstanceMethod(PPDocument, drawBezierPath:andFill:pathIsPixelated:,
                                ppGSPatch_BezierPathAliasing_DrawBezierPath:andFill:
                                    pathIsPixelated:);
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_BezierPathAliasing_InstallPatches);
}

@end

@implementation NSBezierPath (PPGNUstepGlue_BezierPathAliasing)

// PATCH: -[NSBezierPath (PPUtilities) ppAppendSinglePixelLineAtPoint:]
// GNUstep's -[NSBezierPath stroke] always uses antialiasing (despite graphics context setting),
// so override uses a different method for filling in a pixel (draw a centered,
// half-pixel-length square)

- (void) ppGSPatch_AppendSinglePixelLineAtPoint: (NSPoint) point
{
    NSRect pixelRect;

    point = PPGeometry_PixelCenteredPoint(point);

    pixelRect = NSMakeRect(floorf(point.x) + 0.4, floorf(point.y) + 0.4, 0.2, 0.2);

    [self appendBezierPathWithRect: pixelRect];

    [self lineToPoint: point];
}

// PATCH: -[NSBezierPath (PPUtilities) ppAppendLineFromPixelAtPoint:toPixelAtPoint:]
// Overridden to use -[NSBezierPath (PPUtilities) ppAppendSinglePixelLineAtPoint:] when
// drawing a single pixel (both line endpoints are the same) in order to use the patched
// implementation (original's method for filling a pixel doesn't work due to GNUstep's
// antialiasing)

- (void) ppGSPatch_AppendLineFromPixelAtPoint: (NSPoint) startPoint
            toPixelAtPoint: (NSPoint) endPoint
{
    if (NSEqualPoints(startPoint, endPoint))
    {
        [self ppAppendSinglePixelLineAtPoint: endPoint];
        return;
    }

    [self ppGSPatch_AppendLineFromPixelAtPoint: startPoint toPixelAtPoint: endPoint];
}

@end

@implementation PPDocument (PPGNUstepGlue_BezierPathAliasing)

// PATCH: -[PPDocument (DrawingPrivateMethods) drawBezierPath:andFill:pathIsPixelated:]
// GNUstep's -[NSBezierPath stroke] always uses antialiasing (despite graphics context setting),
// which can fill in extra pixels around the path - overridden to call local utility method
// before drawing, -[NSBezierPath pGSGlue_ResegmentedPathForDrawing], which resegments the
// lines in the path into a series of horizontal, vertical, or 1:1 diagonal lines, because
// lines with those slopes are drawn with minimal antialiasing

- (void) ppGSPatch_BezierPathAliasing_DrawBezierPath: (NSBezierPath *) path
            andFill: (bool) shouldFill
            pathIsPixelated: (bool) pathIsPixelated
{
    if (!pathIsPixelated)
    {
        path = [path ppGSGlue_ResegmentedPathForDrawing];
    }

    [self ppGSPatch_BezierPathAliasing_DrawBezierPath: path
            andFill: shouldFill
            pathIsPixelated: pathIsPixelated];
}

@end

@implementation NSBezierPath (PPGNUstepGlue_BezierPathAliasingUtilities)

// ppGSGlue_ResegmentedPathForDrawing: Utility method for resegmenting the lines in a path into
// a series of horizontal, vertical, or 1:1 diagonal lines, which minimizes antialiasing when
// the path is drawn

- (NSBezierPath *) ppGSGlue_ResegmentedPathForDrawing
{
    NSBezierPath *resegmentedPath;
    NSInteger elementCount, elementIndex;
    NSPoint currentPoint, lastPoint, elementPoints[3], pointsDelta;

    resegmentedPath = [NSBezierPath bezierPath];

    if (!resegmentedPath)
        return self;

    elementCount = [self elementCount];

    for (elementIndex = 0; elementIndex < elementCount; elementIndex++)
    {
        switch ([self elementAtIndex: elementIndex associatedPoints: elementPoints])
        {
            case NSMoveToBezierPathElement:
            {
                currentPoint = elementPoints[0];

                [resegmentedPath moveToPoint: currentPoint];

                lastPoint = currentPoint;
            }
            break;

            case NSLineToBezierPathElement:
            {
                currentPoint = elementPoints[0];

                pointsDelta = PPGeometry_PointDifference(currentPoint, lastPoint);

                if (!pointsDelta.x || !pointsDelta.y
                    || (pointsDelta.x == pointsDelta.y))
                {
                    [resegmentedPath lineToPoint: currentPoint];
                }
                else
                {
                    [resegmentedPath ppGSGlue_SegmentedLineToPoint: currentPoint
                                        lastPoint: lastPoint];
                }

                lastPoint = currentPoint;
            }
            break;

            case NSCurveToBezierPathElement:
            {
                return self;
            }
            break;

            case NSClosePathBezierPathElement:
            {
                [resegmentedPath closePath];
            }
            break;

            default:
            break;
        }
    }

    return resegmentedPath;
}

// ppGSGlue_SegmentedLineToPoint: Utility method to append a segmented line between
// startPoint & endPoint, made up of a series of horizontal, vertical, or 1:1 diagonal lines,
// in order to minimize antialiasing when drawing - used by ppGSGlue_ResegmentedPathForDrawing:
// method above

- (void) ppGSGlue_SegmentedLineToPoint: (NSPoint) endPoint lastPoint: (NSPoint) startPoint
{
    NSPoint pointsDelta, absPointsDelta;
    CGFloat x, y, startX, startY, stepX, stepY, endX, endY, ratio;

    pointsDelta = PPGeometry_PointDifference(endPoint, startPoint);
    absPointsDelta = NSMakePoint(fabsf(pointsDelta.x), fabsf(pointsDelta.y));

    if (absPointsDelta.x > absPointsDelta.y)
    {
        if (pointsDelta.y > 0)
        {
            startY = floor(startPoint.y + 1.0);
            stepY = 1.0;
            endY = floor(endPoint.y + 1.0);
        }
        else
        {
            startY = floorf(startPoint.y);
            stepY = -1.0;
            endY = floor(endPoint.y);
        }

        stepX = (pointsDelta.x > 0) ? 1.0 : -1.0;

        ratio = pointsDelta.x / pointsDelta.y;

        for (y = startY; y != endY; y += stepY)
        {
            x = round((y - startPoint.y) * ratio + startPoint.x) - stepX * 0.5;

            [self lineToPoint: NSMakePoint(x, y - stepY * 0.5)];
            [self lineToPoint: NSMakePoint(x + stepX, y + stepY * 0.5)];
        }

        [self lineToPoint: endPoint];
    }
    else
    {
        if (pointsDelta.x > 0)
        {
            startX = floor(startPoint.x + 1.0);
            stepX = 1.0;
            endX = floor(endPoint.x + 1.0);
        }
        else
        {
            startX = floorf(startPoint.x);
            stepX = -1.0;
            endX = floor(endPoint.x);
        }

        stepY = (pointsDelta.y > 0) ? 1.0 : -1.0;

        ratio = pointsDelta.y / pointsDelta.x;

        for (x = startX; x != endX; x += stepX)
        {
            y = round((x - startPoint.x) * ratio + startPoint.y) - stepY * 0.5;

            [self lineToPoint: NSMakePoint(x - stepX * 0.5, y)];
            [self lineToPoint: NSMakePoint(x + stepX * 0.5, y + stepY)];
        }

        [self lineToPoint: endPoint];
    }
}

@end

#endif  // GNUSTEP

