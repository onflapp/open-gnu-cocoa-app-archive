#import "drawundo.h"

/*
 * Please refer to external documentation about Draw
 * with Undo for information about what ChangeDetails 
 * are and where they fit in.
 *
 * The ChangeDetail.h and ChangeDetail.m files contain
 * the @interfaces and @implementations for the 11 
 * subclasses of ChangeDetail, as well as for ChangeDetail
 * itself. We grouped all the classes into one pair of 
 * files because the classes are so tiny and their behavior
 * is so similar.
 *
 * ChangeDetail
 *     ArrowChangeDetail
 *     DimensionsChangeDetail
 *     FillColorChangeDetail
 *     FillModeChangeDetail
 *     LineCapChangeDetail
 *     LineColorChangeDetail
 *     LineJoinChangeDetail
 *     LineWidthChangeDetail
 *     MoveChangeDetail
 *     OrderChangeDetail
 * 
 */

@interface ChangeDetail(PrivateMethods)

- (BOOL)personalChangeExpected;

@end

@implementation ChangeDetail

- initGraphic:aGraphic change:aChange
{
    NSMutableArray *subGraphics;
    int count, i;
    id changeDetail;
    
    graphic = aGraphic;
    change = aChange;
    if ([graphic isKindOfClass:[Group class]] && [self useNestedDetails]) {
        detailsDetails = [[NSArray alloc] init];
	subGraphics = [(Group *)graphic subGraphics];
	count = [subGraphics count];
	changeExpected = NO;
	for (i = 0; i < count; i++) {
	    changeDetail = [[[aChange changeDetailClass] alloc] initGraphic:[subGraphics objectAtIndex:i] change:aChange];
	    changeExpected = changeExpected || [changeDetail changeExpected];
	    [detailsDetails addObject:changeDetail];
	}
    } else {
        detailsDetails = nil;
	changeExpected = [self personalChangeExpected];
    }
    return self;
}

- (void)dealloc
{
    [detailsDetails removeAllObjects];
    [detailsDetails release];
    [super dealloc];
}

- (Graphic *)graphic
{
    return graphic;
}

- (BOOL)useNestedDetails
{
    return YES;
}

- (BOOL)changeExpected
{
    return changeExpected;
}

- (void)recordDetail
{
    if(detailsDetails)
        [detailsDetails makeObjectsPerform:@selector(recordDetail)];
    else
      [self recordIt]; 
}

- (void)undoDetail
{
    if (detailsDetails)
        [detailsDetails makeObjectsPerform:@selector(undoDetail)];
    else
      [self undoIt]; 
}

- (void)redoDetail
{
    if (detailsDetails)
        [detailsDetails makeObjectsPerform:@selector(redoDetail)];
    else
      [self redoIt]; 
}

- (void)recordIt
{
    /* Implemented by subclasses */
     
}

- (void)undoIt
{
    /* Implemented by subclasses */
     
}

- (void)redoIt
{
    /* Implemented by subclasses */
     
}

- (BOOL)personalChangeExpected
{
    return YES;
}

@end

@implementation ArrowChangeDetail

- (void)recordIt
{
    oldLineArrow = [graphic lineArrow]; 
}

- (void)undoIt
{
    [graphic setLineArrow:oldLineArrow]; 
}

- (void)redoIt
{
    [graphic setLineArrow:[change lineArrow]]; 
}

- (BOOL)personalChangeExpected
{
    return ([graphic lineArrow] != [change lineArrow]);
}

@end

@implementation DimensionsChangeDetail

- (BOOL)useNestedDetails
{
    return NO;
}

- (void)recordDetail
{
    oldBounds = [graphic bounds]; 
}

- (void)undoDetail
{
    newBounds = [graphic bounds];
    [graphic setBounds:oldBounds]; 
}

- (void)redoDetail
{
    [graphic setBounds:newBounds]; 
}

@end

@implementation FillChangeDetail

- (void)recordIt
{
    [oldFillColor release];
    oldFillColor = [[graphic fillColor] copy];
    oldFillMode = [graphic fill]; 
}

- (void)undoIt
{
    [newFillColor release];
    newFillColor = [[graphic fillColor] copy];
    newFillMode = [graphic fill];
    [graphic setFillColor:oldFillColor];
    [graphic setFill:oldFillMode]; 
}

- (void)redoIt
{
    [graphic setFillColor:newFillColor];
    [graphic setFill:newFillMode]; 
}

- (BOOL)personalChangeExpected
{
    return ([graphic fill] != [change fill]);
}

@end

@implementation LineCapChangeDetail

- (void)recordIt
{
    oldLineCap = [graphic lineCap]; 
}

- (void)undoIt
{
    [graphic setLineCap:oldLineCap]; 
}

- (void)redoIt
{
    [graphic setLineCap:[change lineCap]]; 
}

- (BOOL)personalChangeExpected
{
    return ([graphic lineCap] != [change lineCap]);
}

@end

@implementation LineColorChangeDetail

- (void)recordIt
{
    [oldColor release];
    oldColor = [[graphic lineColor] copy];
    oldIsOutlined = [graphic isOutlined]; 
}

- (void)undoIt
{
    [graphic setLineColor:oldColor];
    [graphic setOutlined:oldIsOutlined]; 
}

- (void)redoIt
{
    NSColor * color = [change lineColor];
    [graphic setLineColor:color];
    [graphic setOutlined:YES]; 
}

- (BOOL)personalChangeExpected
{
    return (![[graphic lineColor] isEqual:[change lineColor]]);
}

@end

@implementation LineJoinChangeDetail

- (void)recordIt
{
    oldLineJoin = [graphic lineJoin]; 
}

- (void)undoIt
{
    [graphic setLineJoin:oldLineJoin]; 
}

- (void)redoIt
{
    [graphic setLineJoin:[change lineJoin]]; 
}

- (BOOL)personalChangeExpected
{
    return ([graphic lineJoin] != [change lineJoin]);
}

@end

@implementation LineWidthChangeDetail

- (void)recordIt
{
    oldLineWidth = [graphic lineWidth]; 
}

- (void)undoIt
{
    [graphic setLineWidth:&oldLineWidth]; 
}

- (void)redoIt
{
    float lineWidth = [change lineWidth];
    [graphic setLineWidth:&lineWidth]; 
}

- (BOOL)personalChangeExpected
{
    return ([graphic lineWidth] != [change lineWidth]);
}

@end

@implementation MoveChangeDetail

- (BOOL)useNestedDetails
{
    return NO;
}

- (void)undoDetail
{
    NSPoint offset = [change undoVector];
    [graphic moveBy:&offset]; 
}

- (void)redoDetail
{
    NSPoint offset = [change undoVector];
    [graphic moveBy:&offset]; 
}

@end

@implementation OrderChangeDetail

- (BOOL)useNestedDetails
{
    return NO;
}

- (void)recordGraphicPositionIn:graphicList
{
    graphicPosition = [graphicList indexOfObject:graphic]; 
}

- (unsigned)graphicPosition
{
    return graphicPosition;
}

@end
