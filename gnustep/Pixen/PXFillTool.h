//
//  PXFillTool.h
//  Pixen-XCode
//
//  Created by Joe Osborn on Tue Nov 18 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PXTool.h"


@interface PXFillTool : PXTool {
    id color;
}

- (void)mouseDownAt:(NSPoint)aPoint fromCanvasController:controller;
- (void)setColor:aColor;


- (BOOL)shouldAbandonFillingAtPoint:(NSPoint)aPoint fromCanvasController:controller;
- (void)replaceColor:oldColor withColor:newColor atPoints:points inLayer:aLayer ofCanvas:aCanvas;
- (void)fillAtPoint:(NSPoint)aPoint inCanvas:aCanvas replacingColor:oldColor withColor:newColor;
- (void)activatePointWithOldColor:oldColor newColor:newColor atPoints:thisTimeFilled ofCanvas:aCanvas;

@end
