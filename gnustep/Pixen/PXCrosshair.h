//
//  PXCrosshair.h
//  Pixen-XCode
//
//  Created by Ian Henderson on Fri Jun 11 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface PXCrosshair : NSObject {
	NSPoint cursorPosition;
}


- color;
- (BOOL)shouldDraw;
- (NSPoint)cursorPosition;

- (void)setCursorPosition:(NSPoint)position;

@end
