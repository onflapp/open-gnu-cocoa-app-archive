//
//  PXGrid.h
//  Pixen-XCode
//
//  Created by Andy Matuschak on Wed Mar 17 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface PXGrid : NSObject
{
	NSSize unitSize;
	id color;
	BOOL shouldDraw;
}

- initWithUnitSize:(NSSize)unitSize color:color shouldDraw:(BOOL)shouldDraw;

- (NSSize)unitSize;
- color;
- (BOOL)shouldDraw;

- (void)setShouldDraw:(BOOL)shouldDraw;
- (void)setColor:color;
- (void)setUnitSize:(NSSize)unitSize;

@end
