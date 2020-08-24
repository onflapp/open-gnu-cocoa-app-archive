/* PerformanceMap.m
 * Map of graphic objects for optimized access
 *
 * Copyright (C) 1993-2008 by vhf interservice GmbH
 * Authors:  T+T Hennerich (1993), Georg Fleischmann (2001-), Ilonka Fleischmann (2005-)
 *
 * created:  1993 T+T Hennerich, 2001-08-17 Georg Fleischmann
 * modified: 2008-05-03 (autorelease pool)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the vhf Public License as
 * published by vhf interservice GmbH. Among other things, the
 * License requires that the copyright notices and this notice
 * be preserved on all copies.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the vhf Public License for more details.
 *
 * You should have received a copy of the vhf Public License along
 * with this program; see the file LICENSE. If not, write to vhf.
 *
 * vhf interservice GmbH, Im Marxle 3, 72119 Altingen, Germany
 * eMail: info@vhf.de
 * http://www.vhf.de
 */

#include <Foundation/Foundation.h>
#include "PerformanceMap.h"
#include "VCurve.h"	// VCurve class
#include "VGroup.h"	// VGroup class
#include "VImage.h"	// VImage class
#include "VRectangle.h"	// -isPointInside

#define MIN_SIZE		30	// minimum width and height of segment
#define MAXCAPACITY		20	// maximum number of objects in segment (default)
#define INCREASECAPACITY	10	// amount to increase maximum number of objects in segment
#define MINSIZECAPACITY		15000

@implementation PerformanceMap

/*
 */
- (id)initWithFrame:(NSRect)frameRect
{
    bounds = frameRect;
    capacity = MAXCAPACITY;

    graphicList = [NSMutableArray new];
    segmentList = nil;

    borderObjectCnt = 0;

    return self;
}

- (NSString*)description
{   NSMutableString	*string = [NSMutableString string];

    [string appendFormat:@"PerformanceMap: bounds = {%.2f %.2f %.2f %.2f} segments = %d objects = %d",
        bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height,
        [segmentList count], [graphicList count]];
    return string;
}
- (NSString*)descriptionRecursive
{   static int		recursionCnt = 0;
    NSMutableString	*string = [NSMutableString string];
    int			i;

    [string appendFormat:@"%d PerformanceMap: bounds = {%.2f %.2f %.2f %.2f} segments = %d objects = %d",
        recursionCnt, bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height,
        [segmentList count], [graphicList count]];
    if ([graphicList count])
        [string appendFormat:@"\n%@", [graphicList description]];
    else
    {   recursionCnt++;
        for (i=0; i<(int)[segmentList count]; i++)
            [string appendFormat:@"\n%@", [[segmentList objectAtIndex:i] descriptionRecursive]];
        recursionCnt--;
    }
    return string;
}

/* Bei Groessenveraenderungen der GraphicView wird die Ausdehnung des 
 * Segments angepasst und alle GraphicObjecte in die damit
 * veraenderte Segmentierung neu einsortiert.
 *
 * Macht nur Sinn, falls das Object (self) das startSegment der GraphicView ist!
 */
- (void)resizeFrame:(NSRect)newFrame initWithList:(NSArray*)glist
{   int		i;

    newFrame = NSIntegralRect(newFrame);
    if ( bounds.size.width  == newFrame.size.width &&
         bounds.size.height == newFrame.size.height )
        return;
    for (i = [glist count]-1; i>=0; i--)	// remove all references of object to segments
        [[[glist objectAtIndex:i] pmList] removeAllObjects];

    [graphicList release]; graphicList = nil;
    [segmentList release]; segmentList = nil;
    [self initWithFrame:newFrame];

    [self addObjectList:glist withReferenceList:nil];
}

/* Neuaufbau ! Segmentierung neu einsortiert.
 *
 * Macht nur Sinn, falls das Object (self) das startSegment der GraphicView ist!
 */
- (void)sortNewInFrame:(NSRect)newFrame initWithList:(NSArray*)glist
{   int		i;

    newFrame = NSIntegralRect(newFrame);
    for (i = [glist count]-1; i>=0; i--)	// remove all references of object to segments
        [[[glist objectAtIndex:i] pmList] removeAllObjects];

    [graphicList release]; graphicList = nil;
    [segmentList release]; segmentList = nil;
    [self initWithFrame:newFrame];

    [self addObjectList:glist withReferenceList:nil];
}

/* Neue glist initialisieren. Ausdehnung darf sich nicht geaendert haben.
 * Macht nur Sinn, falls das Object (self) das startSegment der GraphicView ist
 */
- (void)initList:(NSArray*)glist
{   int i;

    for (i = [glist count]-1; i>=0 ; i--)	// remove all references of object to segments
        [[[glist objectAtIndex:i] pmList] removeAllObjects];

    [self removeAllObjects];
    [graphicList release];
    [segmentList release]; segmentList = nil;
    capacity = MAXCAPACITY;
    graphicList = [NSMutableArray new];

    [self addObjectList:glist withReferenceList:nil];
}

/* add object to performance map segments
 */
- (void)addObject:(VGraphic*)anObject
{
    [self addObject:anObject inTryNumber:0 withReferenceList:nil];
}

/* Einsortieren einer ganzen GraphicObjects Liste (slist)
 *
 * Falls eine referenceList angegeben wird (glist) wird mit Hilfe dieser
 * die globale Lage der Objekte beruecksichtigt und korrekt nach der
 * Position der Objekte in referenceList einsortiert.
 *
 * Falls keine referenceList angegeben wird, wird rein nach aList 
 * einsortiert. Das erste Objekt der aList befindet sich danach 
 * an oberster Position in den Segmenten
 */
- (void)addObjectList:(NSArray*)aList withReferenceList:(NSArray*)referenceList
{   int i, count = [aList count];

    if (referenceList)	// Einsortieren nach Referenz
    {
        for (i = 0; i < count; i++)
            [self addObject:[aList objectAtIndex:i] inTryNumber:0 withReferenceList:referenceList];
    }
    else		// Einsortieren ohne Referenz
    {
        for (i = 0; i < count; i++)
            [self addObject:[aList objectAtIndex:i] inTryNumber:0 withReferenceList:nil];
    }
}

/* test if object is inside bounds
 */
- (BOOL)isObjectInside:(VGraphic*)g
{   NSRect      objectBounds = [g bounds];	// bounds including line width and vertices
    int         i, cnt;
    VRectangle  *gRect;

    /* object bounds entirely inside segment */
    if ( NSContainsRect(bounds, objectBounds) )
        return YES;

    borderObjectCnt++;

    /* just check for overlapping bounds for some object types */
    if ( [g isKindOfClass:[VPath class]] || [g isKindOfClass:[VGroup class]] )
    {
        if (NSIntersectsRect(bounds, objectBounds) /*|| NSContainsRect(objectBounds, bounds)*/ )
            return YES;
        return NO;
    }
    /* if bounds do not intersect */
    if ( !NSIntersectsRect(bounds, objectBounds) && !NSContainsRect(objectBounds, bounds) )
        return NO;
    /* vertex inside segment (bounds are not necessarily inside for a curve) */
    for (i=0, cnt = [g numPoints]; i<cnt; i++)
        if ( NSPointInRect([g pointWithNum:i], bounds) )
            return YES;
    /* object bounds and segment overlap and object intersects segment */
    //if ( NSIntersectsRect(objectBounds, bounds) && [g intersectsRect:bounds] )
    gRect = [VRectangle rectangle];
    [gRect setVertices:bounds.origin :NSMakePoint(bounds.size.width, bounds.size.height)];
    if ( NSIntersectsRect(objectBounds, bounds) &&
         [gRect sqrDistanceGraphic:g] <= ([g width]/2.0)*([g width]/2.0) )
        return YES;
    /* object if filled and point of segment is inside object */
    if ( [g filled] &&
         [(VPath*)g respondsToSelector:@selector(isPointInside:)] && [(VPath*)g isPointInside:bounds.origin] )
        return YES;
    /* same test as before for images */
    if ( [g isKindOfClass:[VImage class]] && NSPointInRect(bounds.origin, [g bounds]) )
        return YES;
    return NO;
}

/* Adds an object into a segment
 * if a segment has reached it's limit, the segment is splitted into
 * 4 sub segments.
 * inTryNumber prevents a too small fragmentation
 * If a reference list is passed, the position of the object
 * inside the segment list will be according to the reference list.
 * An object is added to the parent and its sub segments as well
 * to achieve a better performance when drawing everything.
 */
- (void)addObject:anObject inTryNumber:(int)try withReferenceList:(NSArray*)referenceList
{   NSInteger   i, count, objectIndex;
    id          segment;

    if (!segmentList && (int)[graphicList count] == capacity)			// limit of segment reached
        [self splitSegmentInTryNumber:++try withReferenceList:referenceList];	// -> request sub segments

    if (segmentList)				// add object to sub segments
    {
        for (i = [segmentList count]-1; i>=0; i--)
        {
            segment = [segmentList objectAtIndex:i];
            if ( [segment isObjectInside:anObject] )
                [segment addObject:anObject inTryNumber:try withReferenceList:referenceList];
        }
    }
    //else	// ! remove to have objects in parent segments
    {
        if (referenceList)			// insert object with reference list
        {
            count = [graphicList count];
            if (count > 0)
            {
                objectIndex = [referenceList indexOfObject:anObject];
                if (objectIndex != NSNotFound)
                {
                    for (i=0; i<count; i++)
                    {
                        if ((NSInteger)[referenceList indexOfObject:[graphicList objectAtIndex:i]] > objectIndex)
                        {   [graphicList insertObject:anObject atIndex:i];
                            break;
                        }
                    }
                    if (i >= count)
                        [graphicList addObject:anObject];
                }
                else					// not in reference list -> insert at end of list
                    [graphicList addObject:anObject];
            }
            else
                [graphicList addObject:anObject];
        }
        else
            [graphicList addObject:anObject];		// add object to graphic list
        [[anObject pmList] addObject:self];		// add segment to graphics list of segments
    }
}

/* Remove object, if it is a member of the map
 * removes object from map
 * This method should only be send to the master map !
 */
- (void)removeObjectFromPM:(VGraphic*)anObject
{   int			i;
    NSMutableArray	*pmList = [anObject pmList];

    if (![pmList count])	// only for members
        return;
    /* remove object from performance map */
    for (i=[pmList count]-1; i>=0; i--)
        [[pmList objectAtIndex:i] removeObject:anObject];
    [pmList removeAllObjects];
}

/* Update object, if it is a member of the map
 * removes object from map and inserts it again
 * Note: This method should only be send to the master map !
 * Note: Slow method, only use when sizes of the object change
 */
- (void)updateObject:(VGraphic*)anObject withReferenceList:(NSArray*)refList
{   int             i;
    NSMutableArray  *pmList = [anObject pmList];

    if (![pmList count])	// only for members
        return;
    /* remove object from performance map */
    for (i=[pmList count]-1; i>=0; i--)
        [[pmList objectAtIndex:i] removeObject:anObject];
    [pmList removeAllObjects];

    /* add object to performance map */
    [self addObject:anObject inTryNumber:0 withReferenceList:refList];
}

- (void)removeObject:(VGraphic*)anObject;
{
    [graphicList removeObject:anObject];
}

/* Verschiebt ein Objekt in der segmentListe an die neue Position newPosition
 * Falls newPosition groesser sein sollte, als der groesste derzeitige Index
 * wird das Objekt an das Ende angefuegt
 */
/*- (void)shuffleObject:anObject toPosition:(int)newPosition;
{
    [graphicList removeObject:anObject];
    if (newPosition > [graphicList count])
        [graphicList addObject:anObject];
    else
        [graphicList insertObject:anObject atIndex:newPosition];
}*/


- (void)splitSegmentInTryNumber:(int)try withReferenceList:(NSArray*)referenceList
{   NSMutableArray	*graphicListCopy;	// Copy von graphicList, da diese fruehzeitig geloescht werden mus
    float	heightHalf, widthHalf;
    NSRect	boundsOne, boundsTwo, boundsThree, boundsFour;
    int 	i, cnt;
    id 		g;

    if (borderObjectCnt > capacity/3.0)	// half objects in segment are objects greater than segmentbounds
    {	capacity += INCREASECAPACITY;		// nicht splitten, da sonst zuviele segmente in denen alles doppelt
        return;					//  und vielfach drinnen ist -> Capacity dieses Segments hochsetzten
    }

    if (try == 2)			// Einmal Aufsplitten hat noch keine (volltstaendige) Verbesserung
    {	capacity += INCREASECAPACITY;	// ergeben. Um sinnlose Kleinstaufteilung zu vermeiden
        //printf("Increase Capacity to %d\n", (int) capacity);
        return;				// Capacity dieses Segments hochsetzten
    }

    heightHalf = bounds.size.height / 2.0;
    widthHalf  = bounds.size.width  / 2.0;

    if (heightHalf <= MIN_SIZE || widthHalf <= MIN_SIZE)	// Als kleinste Ausdehnung sind 1,5 cm^2 zugelassen
    {	capacity = MINSIZECAPACITY;			// Demnach duerfen jetzt soviele Elemente rein, wie wollen
        // printf("MinSize (%f,%f). No Splitting!\n", bounds.size.width, bounds.size.height);
        return;
    }

    boundsOne = NSMakeRect(bounds.origin.x, bounds.origin.y, widthHalf, heightHalf);
    boundsTwo = NSMakeRect(bounds.origin.x+widthHalf, bounds.origin.y, widthHalf, heightHalf);
    boundsThree = NSMakeRect(bounds.origin.x, bounds.origin.y+heightHalf, widthHalf, heightHalf);
    boundsFour = NSMakeRect(bounds.origin.x+widthHalf, bounds.origin.y+heightHalf, widthHalf, heightHalf);

    segmentList = [[NSMutableArray alloc] initWithCapacity:4];
    [segmentList addObject:[[[PerformanceMap alloc] initWithFrame:boundsOne] autorelease]];
    [segmentList addObject:[[[PerformanceMap alloc] initWithFrame:boundsTwo] autorelease]];
    [segmentList addObject:[[[PerformanceMap alloc] initWithFrame:boundsThree] autorelease]];
    [segmentList addObject:[[[PerformanceMap alloc] initWithFrame:boundsFour] autorelease]];

    /* remove objects from graphic list, keep copy of graphic list to reinsert objects */
    cnt = [graphicList count];
    graphicListCopy = [NSMutableArray arrayWithCapacity:cnt];
    for (i=0; i<cnt; i++)
    {	g = [graphicList objectAtIndex:i];

        [[g pmList] removeObject:self];		// remove segment from graphic objects
        [graphicListCopy addObject:g];		// add graphics to temporary array
    }
    [graphicList removeAllObjects];		// empty list of graphic objects

    /* add graphic objects to sub segments */
    for (i = 0, cnt = [graphicListCopy count]; i < cnt; i++)
    {	g = [graphicListCopy objectAtIndex:i];

        [self addObject:g inTryNumber:try withReferenceList:referenceList];
    }
}


/* Returns the object which owns the knobbie we have hit.
 * If we didn't hit a knob we return nil
 * corner	number of knob
 */
- (VGraphic*)controlHitAtPoint:(NSPoint)point gotCornerNumber:(int*)corner :(float)controlsize
{   NSRect	segmentBounds;
    int 	i, count;

    if (segmentList)
    {
        for (i = [segmentList count]-1; i>=0; i--)
        {   PerformanceMap	*segment = [segmentList objectAtIndex:i];

            segmentBounds = [segment bounds];
            if (point.x >= segmentBounds.origin.x	// point inside segment
                && point.x <= segmentBounds.origin.x + segmentBounds.size.width
                && point.y >= segmentBounds.origin.y
                && point.y <= segmentBounds.origin.y + segmentBounds.size.height)
            {   VGraphic	*g = [segment controlHitAtPoint:point gotCornerNumber:corner :controlsize];

                if ( g )
                    return g;
            }
        }
    }
    else
    {
        for (i=0, count = [graphicList count]; i<count; i++)
        {   VGraphic	*g = [graphicList objectAtIndex:i];

            if ([g hitControl:point :corner controlSize:controlsize])
                return g;
        }
    }

    return nil;
}

// Sucht das erste Objekt an Position Point.
// Liefert das gefundene Objekt oder nil zurueck 
- (VGraphic*)objectAtPoint:(NSPoint)point fuzz:(float)fuzz
{   NSRect	segmentBounds;
    id 		segment;
    id		hitObject;
    int 	i, count;	

    if (segmentList)
    {
        for (i = [segmentList count]-1; i>=0; i--)
        {
            segment = [segmentList objectAtIndex:i];
            segmentBounds = [segment bounds];

            //if (NSPointInRect(point, segmentBounds))
            if (point.x >= segmentBounds.origin.x	// point inside segment
                && point.x <= segmentBounds.origin.x + segmentBounds.size.width
                && point.y >= segmentBounds.origin.y
                && point.y <= segmentBounds.origin.y + segmentBounds.size.height)
            {
                hitObject = [segment objectAtPoint:point fuzz:fuzz];
                if (hitObject)
                    return hitObject;	
            }
        }
    }
    else
    {
        for (i=0, count = [graphicList count]; i<count; i++)
        {
            hitObject = [graphicList objectAtIndex:i];
            if ([hitObject hit:point fuzz:fuzz])
                return hitObject;
        }
    }

    return nil;
}


// Sucht das erste selektierte Objekt an Position Point.
// Liefert das gefundene Objekt oder nil zurueck, in ObjectBelow wird das direkt darunterliegende 
// Objekt (falls vorhanden und gefundenes Objekt durchsichtig) zurueckgeliefert, sonst nil.
// Wird fuer den mouseDown deepHit benoetigt.
- (VGraphic *)selectedObjectAtPoint:(NSPoint)point andObjectBelow:(id *)belowObject
{   NSRect	segmentBounds;
    id 		segment;
    id		g, returnObject=nil;
    int 	i, count;	

    if (segmentList)
    {
        for (i = [segmentList count]-1; i>=0; i--)
        {
            segment = [segmentList objectAtIndex:i];
            segmentBounds = [segment bounds];

            if (point.x >= segmentBounds.origin.x	// point inside segment
                && point.x <= segmentBounds.origin.x + segmentBounds.size.width
                && point.y >= segmentBounds.origin.y
                && point.y <= segmentBounds.origin.y + segmentBounds.size.height)
            {
                returnObject = [segment selectedObjectAtPoint:point andObjectBelow:belowObject];
                if (returnObject)
                    return returnObject;	
            }
        }
    }
    else
    {
        for (i=0, count = [graphicList count]; i<count; i++)
        {
            g = [graphicList objectAtIndex:i];
            if (returnObject == nil)
            {
                if ([g isSelected] && [g hit:point fuzz:0])		// Selektiertes Object suchen
                {
                    returnObject = g;
                    *belowObject = nil;
                    if ([returnObject isOpaque])		// Object undurchsichtig, somit kein
                        return returnObject;			// Object darunter zu erreichen
                }
            }
            else						// Wir haben schon ein transparentes
            {
                if ([g hit:point fuzz:0])			// Object gefunden, gibt's auch noch
                {
                    *belowObject = g;				// eines darunter?
                    return returnObject;
                }
            }
        }
    }

    return returnObject;
}


// Sucht das erste unselektierte Objekt an Position Point.
// Liefert das gefundene Objekt oder nil zurueck 
- (VGraphic*)unselectedObjectAtPoint:(NSPoint)point
{   NSRect	segmentBounds;
    id 		segment;
    id		hitObject;
    int 	i, count;	

    if (segmentList)
    {
        for (i = [segmentList count]-1; i>=0; i--)
        {
            segment = [segmentList objectAtIndex:i];
            segmentBounds = [segment bounds];

            if (point.x >= segmentBounds.origin.x	// point inside segment
                && point.x <= segmentBounds.origin.x + segmentBounds.size.width
                && point.y >= segmentBounds.origin.y
                && point.y <= segmentBounds.origin.y + segmentBounds.size.height)
            {
                hitObject = [segment unselectedObjectAtPoint:point];
                if (hitObject)
                    return hitObject;	
            }
        }
    }
    else
    {
        for (i=0, count = [graphicList count]; i<count; i++)
        {
            hitObject = [graphicList objectAtIndex:i];
            if (![hitObject isSelected] && [hitObject hit:point fuzz:0])	// Unselektiertes Object suchen
                return hitObject;
        }
    }

    return nil;
}


// Sucht das erste Objekt der Art class an Position Point.
// Liefert das gefundene Objekt oder nil zurueck 
- (VGraphic*)objectAtPoint:(NSPoint)point ofKind:(Class)kind fuzz:(float)fuzz
{   NSRect	segmentBounds;
    id 		segment;
    id		hitObject;
    int 	i, count;	

    if (segmentList)
    {
        for (i = [segmentList count]-1; i>=0; i--)
        {
            segment = [segmentList objectAtIndex:i];
            segmentBounds = [segment bounds];

            if (point.x >= segmentBounds.origin.x	// point inside segment
                && point.x <= segmentBounds.origin.x + segmentBounds.size.width
                && point.y >= segmentBounds.origin.y
                && point.y <= segmentBounds.origin.y + segmentBounds.size.height)
            {
                hitObject = [segment unselectedObjectAtPoint:point];
                if (hitObject)
                    return hitObject;
            }
        }
    }
    else
    {
        for (i=0, count = [graphicList count]; i<count; i++)
        {
            hitObject = [graphicList objectAtIndex:i];
            if ([hitObject isKindOfClass:kind] && [hitObject hit:point fuzz:fuzz])
                return hitObject;
        }
    }

    return nil;
}


/* Fuegt alle Objekte die sich KOMPLETT innerhalb
 * des uebergeben Rechtecks befinden in die Liste ein
 */
- (void)addObjectsInContentsRect:(NSRect)rect inList:(NSMutableArray*)aList
{   NSRect	segmentBounds, objectBounds;
    id 		segment;
    id		object;
    int 	i, count;	

    if (segmentList)
    {
        for (i = [segmentList count]-1; i>=0; i--)
        {
            segment = [segmentList objectAtIndex:i];
            segmentBounds = [segment bounds];
            if (NSIntersectsRect(rect, segmentBounds))	// Liegt Segment teilweise im ContentsRect?
                [segment addObjectsInContentsRect:rect inList:aList];
        }
    }
    else
    {
        for (i=0, count = [graphicList count]; i<count; i++)
        {
            object=[graphicList objectAtIndex:i];
            objectBounds = [object bounds];
            if (NSContainsRect(rect, objectBounds))	// Liegt Objekt komplett im ContentsRect?
                [aList addObject:object];
        }
    }
}


/* Fuegt alle Objekte die sich (mindestens teilweise) innerhalb
 * des uebergeben Rechtecks befinden in die Liste ein
 */
- (void)addObjectsInIntersectionRect:(NSRect)rect inList:(NSMutableArray*)aList
{   NSRect	segmentBounds, objectBounds;
    id 		segment;
    id		object;
    int 	i, count;	

    if (segmentList)
    {
        for (i = [segmentList count]-1; i>=0; i--)
        {
            segment = [segmentList objectAtIndex:i];
            segmentBounds = [segment bounds];
            if (NSIntersectsRect(rect, segmentBounds))		// Liegt Segment teilweise im ContentsRect?
                [segment addObjectsInIntersectionRect:rect inList:aList];
        }
    }
    else
    {
        for (i=0, count = [graphicList count]; i<count; i++)
        {
            object = [graphicList objectAtIndex:i];
            objectBounds = [object bounds];
            if (NSIntersectsRect(rect, objectBounds))		// Liegt Objekt teilweise im ContentsRect?
                if ([aList indexOfObject:object] == NSNotFound)
                    [aList addObject:object];
        }
    }
}

/* draw map
 * we draw the top most segment of our hierarchie entirely inside rect
 */
- (void)drawInRect:(NSRect)rect principal:(id)view
{   int	i, count;

    if (segmentList && !NSContainsRect(NSInsetRect(rect, -MIN_SIZE/4, -MIN_SIZE/4), bounds))
    {
        for (i = [segmentList count]-1; i>=0; i--)
        {   PerformanceMap	*segment = [segmentList objectAtIndex:i];
            NSRect		segmentBounds = [segment bounds];

            /* segment is inside drawing bounds -> draw */
            if (NSIntersectsRect(rect, segmentBounds))
                [segment drawInRect:NSIntersectionRect(rect, segmentBounds) principal:view];
        }
    }
    else
    {
        /* we clip to the segment bounds not to mess up the redraw order of the objects */
        PSgsave();
        NSRectClip(rect);

        for (i=0, count = [graphicList count]; i<count; i++)
        {   VGraphic            *g = [graphicList objectAtIndex:i];
			NSAutoreleasePool   *pool = [NSAutoreleasePool new];

            //[g drawInRect:rect principal:view];	// from different segments
            [g drawWithPrincipal:view];
			[pool release];
        }

        PSgrestore();
    }
}


/* Nur zur Debugging Zwecken: Anzeige der Segment-Grenzen in der GraphicView
 */
- (void)drawSegmentBoundaries
{   int i;

    if (segmentList)		// draw sub segments
    {
        for (i = [segmentList count]-1; i>=0; i--)
            [[segmentList objectAtIndex:i] drawSegmentBoundaries];
    }
    else
    {
	PSgsave();
        [[NSColor blackColor] set];
        [NSBezierPath setDefaultLineWidth:[NSBezierPath defaultLineWidth]];
        [NSBezierPath strokeRect:NSMakeRect(bounds.origin.x,   bounds.origin.y,
                                            bounds.size.width, bounds.size.height)];
        PSgrestore();
    }
}

- (NSRect)bounds
{
    return bounds;
}

/* this must be called before finally releasing the performance map.
 * otherwise the map will not be dealloced!
 */
- (void)removeAllObjects
{   int	i;

    if (graphicList)
        for (i=[graphicList count]-1; i>=0; i--)
            [[[graphicList objectAtIndex:i] pmList] removeAllObjects];
    else
        for (i=[segmentList count]-1; i>=0; i--)
            [[segmentList objectAtIndex:i] removeAllObjects];
}

- (void)dealloc
{
    [segmentList release];
    [graphicList release];
    [super dealloc];
}

@end

