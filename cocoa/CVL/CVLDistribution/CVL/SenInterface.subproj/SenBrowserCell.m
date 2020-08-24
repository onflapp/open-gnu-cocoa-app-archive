/* SenBrowserCell.m created by ja on Tue 11-Feb-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "SenBrowserCell.h"
#import <NSValue_Null.h>
#import <SenFoundation/SenFoundation.h>

@interface SenBrowserCell (Private)
- (void)willModifyTabs;
- (void)willModifyCells;
- (NSRect)_availableFrameInFrame:(NSRect)aRect;
@end

// This helper function works around the fact that -[NSArray copyWithZone:]
// only does a shallow copy now.  This was leading to elements of the cells 
// referencing a dealloced NSMatrix (stashed in the private _controlView ivar).
//
static id copyArrayWithZone(NSArray *array, NSZone *zone) {
    if (array) {
        unsigned int anIndex, count = [array count];
        NSMutableArray *result = [[NSMutableArray allocWithZone:zone] initWithCapacity:count];
        for(anIndex=0; anIndex<count; anIndex++) {
            id object = [array objectAtIndex:anIndex];
            if ([object respondsToSelector:@selector(copyWithZone:)]) {
                object = [object copyWithZone:zone];
            } else {
                object = [object retain];
            }
            [result addObject:object];
            [object release];
        }
        return result;
    } else {
        return nil;
    }
}

@implementation SenBrowserCell
+ (SenBrowserCell *)cell
{
    return [[[self alloc] init] autorelease];
}

- (id)init
{
	isIniting = YES;
    if ( (self=[super init]) ) {
        cells=[[NSMutableArray allocWithZone:[self zone]] init];
        tabWidths=[[NSMutableArray allocWithZone:[self zone]] init];
        values=[[NSMutableArray allocWithZone:[self zone]] init];

        reusedCells=NO;
        reusedTabs=NO;
    }
	isIniting = NO;
    return self;
}

- (void)dealloc
{
    RELEASE(tabWidths);
    RELEASE(cells);
    RELEASE(values);
    
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
    SenBrowserCell *copy;
    unsigned int anIndex;

    if ( (copy = [super copyWithZone:zone]) ) {
        copy->cells=copyArrayWithZone(cells, zone); // or copy  retain (120)
        copy->tabWidths=[tabWidths retain];
        copy->values=[[NSMutableArray allocWithZone:[self zone]] init];
        anIndex=0;
        while (anIndex<[tabWidths count]) {
            [copy->values addObject:[NSValue nullValue]];
            anIndex++;
        }

        copy->reusedCells=YES; //120
        copy->reusedTabs=YES;
        copy->namePosition=namePosition;
    }
    return copy;
}

- (NSRect)_availableFrameInFrame:(NSRect)aRect
{
    aRect.size.width-=[[[self class] branchImage] size].width;

    if (aRect.size.width<0) {
        aRect.size.width=0;
    }
    return aRect;
}

- (NSSize)cellSize
	/*" This method returns the minimum needed to display the contents of this 
		cell. This cell is made up of a number of subcells, either 3 or 5 if 
		watchers are turned on. The subcells return the minimum size needed to 
		display themselves. The tab widths are returned for the image cells and 
		the text field cells calculate their own width/height.
	"*/
{
	NSCell *aSubcell = nil;
    NSSize resultingSize = {0.0, 0.0};
	NSSize aSize = {0.0, 0.0};
    unsigned int aCount = 0;
    unsigned int anIndex = 0;
    float tabWidth = 0.0;
    	
    aCount = [tabWidths count];
    while ( anIndex < aCount ) {
		aSubcell = [self subcellAtIndex:anIndex];
		SEN_ASSERT_NOT_NIL(aSubcell);
        tabWidth = [self tabWidthAtIndex:anIndex];
        if ( tabWidth > 0.0 ) {
			aSize = [aSubcell cellSize];
			aSize.width = tabWidth;
		} else {
			// An object value has not been set yet in cases where 
			// it has not been displayed.
			[aSubcell setObjectValue:[self objectValueAtIndex:anIndex]];
			aSize = [aSubcell cellSize];

		}
		resultingSize.width = resultingSize.width + aSize.width;

        resultingSize.height = MAX(aSize.height,resultingSize.height);
        anIndex++;
    }
	// Add 15 pixels for the a branch icon.
	resultingSize.width = resultingSize.width + 15.0;


    return resultingSize;
}

- (void)willModifyTabs
{
    if (reusedTabs) {
        NSMutableArray *newTabWidths;

        reusedTabs=NO;

        newTabWidths=[tabWidths mutableCopyWithZone:[self zone]];
        [tabWidths release];
        tabWidths=newTabWidths;
    }
}

- (void)willModifyCells
{
    if (reusedCells) {
        NSMutableArray *newCells;

        reusedCells=NO;

        newCells=[cells mutableCopyWithZone:[self zone]];
        [cells release];
        cells=newCells;
    }
}

- (void)useTemplate:(SenBrowserCell *)anotherCell
{
    [self setTabWidths:[anotherCell tabWidths]];
    [self setCells:[anotherCell cells]];
    [self setNamePosition:[anotherCell namePosition]];
}

- (void) setTabWidths:(NSArray *)someTabs
{
    reusedTabs=YES;

    ASSIGN(tabWidths, someTabs);
}

- (NSArray *)tabWidths
{
    return tabWidths;
}

- (void) addTabWithFixedWidth:(float)width
{
    [self willModifyTabs];

    [tabWidths addObject:[NSNumber numberWithFloat:width]];
    [cells addObject:[NSValue nullValue]];
    [values addObject:[NSValue nullValue]];
}

- (void) addTabWithProportionalWidth:(float)width
{
    [self willModifyTabs];

    [tabWidths addObject:[NSNumber numberWithFloat:-width]];
    [cells addObject:[NSValue nullValue]];
    [values addObject:[NSValue nullValue]];
}

- (float) tabWidthAtIndex:(unsigned int)anIndex
{
	NSNumber *aTabWidthNumber = nil;
	float aTabWidth = 0.0;
	
	SEN_ASSERT_CONDITION(( anIndex < [tabWidths count] ));
	
	aTabWidthNumber = [tabWidths objectAtIndex:anIndex];
	aTabWidth = [aTabWidthNumber floatValue];
	
	return aTabWidth;
}

- (void) setTabFixedWidth:(float)width atIndex:(unsigned int)anIndex
{
    [self willModifyTabs];

	SEN_ASSERT_CONDITION(( anIndex <= [tabWidths count] ));

    [tabWidths replaceObjectAtIndex:anIndex
						 withObject:[NSNumber numberWithFloat:width]];
}

- (void) setTabProportionalWidth:(float)width atIndex:(unsigned int)anIndex
{
    [self willModifyTabs];

	SEN_ASSERT_CONDITION(( anIndex <= [tabWidths count] ));

    [tabWidths replaceObjectAtIndex:anIndex 
						 withObject:[NSNumber numberWithFloat:-width]];
}

- (void) setCells:(NSArray *)someCells
{
    reusedCells=YES;

//    [someCells retain];
    [cells release];
    cells=(NSMutableArray *)copyArrayWithZone(someCells, [self zone]); //reusedCells say that it's not mutable
}

- (NSArray *)cells
{
    return cells;
}

- (void) setSubcell:(NSCell *)cell atIndex:(unsigned int)anIndex
{
    [self willModifyCells];

	SEN_ASSERT_CONDITION(( anIndex <= [cells count] ));

    [cells replaceObjectAtIndex:anIndex withObject:cell];
}

- (NSCell *) subcellAtIndex:(unsigned int)anIndex
{
	NSCell *aSubCell = nil;
	
	SEN_ASSERT_CONDITION(( anIndex < [cells count] ));
	
	aSubCell = [cells objectAtIndex:anIndex];
	if ( (id)aSubCell == [NSValue nullValue] ) {
		aSubCell = nil;
	}

	return aSubCell;
}

- (void) setObjectValue:(id)value atIndex:(unsigned int)anIndex
{
	NSCell *aSubcell = nil;
	
    if (!values) {
        [super setObjectValue:value];
    }
	SEN_ASSERT_CONDITION(( anIndex <= [values count] ));

    [values replaceObjectAtIndex:anIndex withObject:value];
	// Update the object value of the subcell.
	aSubcell = [self subcellAtIndex:anIndex];
	SEN_ASSERT_NOT_NIL(aSubcell);
	[aSubcell setObjectValue:value];
}

- (id)objectValueAtIndex:(unsigned int)anIndex;
{
    id object;

    if (!values) {
        return [super objectValue];
    }

	SEN_ASSERT_CONDITION(( anIndex < [values count] ));

    object=[values objectAtIndex:anIndex];
    if (object==[NSValue nullValue]) {
        return nil;
    } else {
        return object;
    }
}

- (void)setNamePosition:(unsigned int)anIndex
{
    namePosition = anIndex;
}

- (unsigned int)namePosition
{
    return namePosition;
}

- (NSString *)stringValue
{
    if (!values) {
        return [super stringValue];
    }
    return [[[self objectValueAtIndex:namePosition] retain] autorelease];
}

- (void)setStringValue:(NSString *)aString
{
    if (!values) {
        [super setStringValue:aString];
    }
	// We need to skip the message below when init calls this method
	// before any values have been added.
	if ( isIniting == NO ) {
		[self setObjectValue:aString atIndex:namePosition];
	}
}

- (void)set
{
	[super set];
}

- (void)setState:(int)flag
{
    id cellEnumerator;
    NSCell *cell;

    cellEnumerator=[cells objectEnumerator];
    while ( (cell=[cellEnumerator nextObject]) ) {
        [cell setState:flag];
    }
    [super setState:flag];
}

- (void)setFont:(NSFont *)fontObj
{
    id cellEnumerator;
    NSCell *cell;

    cellEnumerator=[cells objectEnumerator];
    while ( (cell=[cellEnumerator nextObject]) ) {
        [cell setFont:fontObj];
    }
    [super setFont:fontObj];
}

- (void)highlight:(BOOL)flag withFrame:(NSRect)cellFrame inView:(NSView *)aView
{
    [self setState:flag];
    [aView setNeedsDisplayInRect:cellFrame];
//    [super highlight:flag withFrame:cellFrame inView:aView];
//    [self drawInteriorWithFrame:cellFrame inView:aView];
}
/*
- (void)highlight:(BOOL)flag withFrame:(NSRect)cellFrame inView:(NSView *)aView
{
    float proportionalTotalWidth;
    float proportionalAvailableWidth;
    float tabWidth=0;
    int anIndex,count;
    float tabStart,tabEnd;
    NSRect subCellFrame;
    NSCell *cell;

    [super highlight:flag withFrame:cellFrame inView:aView];
    cellFrame=[self _availableFrameInFrame:cellFrame];
    subCellFrame=cellFrame;
    proportionalTotalWidth=0;
    proportionalAvailableWidth=NSWidth(cellFrame);
    count=[tabWidths count];
    anIndex=0;
    while (anIndex<count) {
        tabWidth=[self tabWidthAtIndex:anIndex];
        if (tabWidth<0) {
            proportionalTotalWidth-=tabWidth;
        } else {
            proportionalAvailableWidth-=tabWidth;
        }
        anIndex++;
    }

    anIndex=0;
    tabStart=tabEnd=NSMinX(cellFrame);

    while ((anIndex<count) && (tabEnd<NSMaxX(cellFrame))) {
        tabStart=tabEnd;
        tabWidth=[self tabWidthAtIndex:anIndex];
        if (tabWidth<0) {
            if (proportionalAvailableWidth>0) {
                tabWidth=(-tabWidth/proportionalTotalWidth)*proportionalAvailableWidth;
            } else {
                tabWidth=0;
            }
        }

        tabEnd=tabStart+tabWidth;

        if (tabEnd>NSMaxX(cellFrame)) {
            tabEnd=NSMaxX(cellFrame);
            tabWidth=tabEnd-tabStart;
        }

        if (tabWidth>0) {
            subCellFrame.origin.x=tabStart;
            subCellFrame.size.width=tabWidth;

            cell=[self subcellAtIndex:anIndex];
            [cell setObjectValue:[self objectValueAtIndex:anIndex]];
            [cell highlight:flag withFrame:subCellFrame inView:aView];
        }
        anIndex++;
    }
} */

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)aView 
{
    float proportionalTotalWidth;
    float proportionalAvailableWidth;
    float tabWidth=0;
    unsigned int anIndex,count;
    float tabStart,tabEnd;
    NSRect subCellFrame,availableCellFrame;
    NSCell *aSubcell = nil;

    availableCellFrame=[self _availableFrameInFrame:cellFrame];
    subCellFrame=availableCellFrame;
    proportionalTotalWidth=0;
    proportionalAvailableWidth=NSWidth(availableCellFrame);
    count=[tabWidths count];
    anIndex=0;
    while (anIndex<count) {
        tabWidth=[self tabWidthAtIndex:anIndex];
        if (tabWidth<0) {
            proportionalTotalWidth-=tabWidth;
        } else {
            proportionalAvailableWidth-=tabWidth;
        }
        anIndex++;
    }

    [super drawInteriorWithFrame:cellFrame inView:aView];

    anIndex=0;
    tabStart=tabEnd=NSMinX(availableCellFrame);

    while ((anIndex<count) && (tabEnd<NSMaxX(availableCellFrame))) {
        tabStart=tabEnd;
        tabWidth=[self tabWidthAtIndex:anIndex];
        if (tabWidth<0) {
            if (proportionalAvailableWidth>0) {
                tabWidth=(-tabWidth/proportionalTotalWidth)*proportionalAvailableWidth;
            } else {
                tabWidth=0;
            }
        }

        tabEnd=tabStart+tabWidth;

        if (tabEnd>NSMaxX(availableCellFrame)) {
            tabEnd=NSMaxX(availableCellFrame);
            tabWidth=tabEnd-tabStart;
        }

        if (tabWidth>0) {
            subCellFrame.origin.x=tabStart;
            subCellFrame.size.width=tabWidth;

            aSubcell = [self subcellAtIndex:anIndex];
            [aSubcell setObjectValue:[self objectValueAtIndex:anIndex]];
            if ([aSubcell state]!=[self state]) {
                [aSubcell setState:[self state]];
            }
            [aSubcell drawWithFrame:subCellFrame inView:aView];
        }
        anIndex++;
    } 

}

@end
