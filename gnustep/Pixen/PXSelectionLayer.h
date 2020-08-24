//
//  PXSelectionLayer.h
//  Pixen-XCode
//
//  Created by Joe Osborn on Sun Jan 04 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXLayer.h"

@interface PXSelectionLayer : PXLayer
{
	id workingPoints;
	BOOL isSubtracting;
}
- workingPoints;
+ selectionWithSize:(NSSize)aSize;
- (void)finalize;
- (void)drawBezierFromPoint:(NSPoint)fromPoint toPoint:(NSPoint)toPoint color:color;
- (void)addWorkingPoint:(NSPoint)aPoint;
- (void)removeWorkingPoint:(NSPoint)aPoint;
- (BOOL)pointIsSelected:(NSPoint)point;

- (void)setIsSubtracting:(BOOL)isSubtracting;

@end
