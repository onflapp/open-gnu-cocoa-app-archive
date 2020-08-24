//
//  PXLinearTool.h
//  Pixen-XCode
//
//  Created by Ian Henderson on Mon Mar 15 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXPencilTool.h"


@interface PXLinearTool : PXPencilTool { // a generalized line tool
    NSPoint _origin;
    BOOL locked;
    BOOL centeredOnOrigin;
}

- (void)drawFromPoint:(NSPoint)origin toPoint:(NSPoint)finalPoint inCanvas:canvas;
- (void)finalDrawFromPoint:(NSPoint)origin toPoint:(NSPoint)finalPoint inCanvas:canvas;
@end
