/* SenBrowserCell.h created by ja on Tue 11-Feb-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <AppKit/AppKit.h>
/*$id$*/

@interface SenBrowserCell : NSBrowserCell
{
    BOOL reusedTabs;
    BOOL reusedCells;
    BOOL isIniting;
	
    NSMutableArray *tabWidths;
    NSMutableArray *cells;
    NSMutableArray *values;

    unsigned int namePosition;
}

+ (SenBrowserCell *)cell;

- (void) addTabWithFixedWidth:(float)width;
- (void) addTabWithProportionalWidth:(float)width;
- (void) setTabFixedWidth:(float)width atIndex:(unsigned int)anIndex;
- (void) setTabProportionalWidth:(float)width atIndex:(unsigned int)anIndex;

- (void)useTemplate:(SenBrowserCell *)anotherCell;

- (void)setNamePosition:(unsigned int)anIndex; //used by the browser and for string value
- (unsigned int)namePosition;

- (void) setTabWidths:(NSArray *)someTabs;
- (NSArray *)tabWidths;
- (float) tabWidthAtIndex:(unsigned int)anIndex;

- (void) setCells:(NSArray *)someCells;
- (NSArray *)cells;
- (void) setSubcell:(NSCell *)cell atIndex:(unsigned int)anIndex;
- (NSCell *) subcellAtIndex:(unsigned int)anIndex;

- (void) setObjectValue:(id)value atIndex:(unsigned int)anIndex;
- (id)objectValueAtIndex:(unsigned int)anIndex;
@end
/*$log$*/
