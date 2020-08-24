//
//  PXToolMatrix.m
//  Pixen-XCode
//
//  Created by Ian Henderson on Sat Mar 20 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXToolMatrix.h"
#import "PXToolPropertiesController.h"


@implementation PXToolMatrix

- (void)awakeFromNib
{
	[self setDoubleAction:@selector(toolDoubleClicked:)];
}


/*- (void)mouseDown:event
{
    if ([event clickCount] == 2) {
		[self target] 
		[switcher orderFrontPropertiesPanel];
    }
    [super mouseDown:event];
}*/


@end
