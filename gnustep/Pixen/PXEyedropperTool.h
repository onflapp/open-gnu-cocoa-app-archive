//  PXEyedropperTool.h
//  Pixen
//
//  Created by Joe Osborn on Mon Oct 13 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PXTool.h"


@interface PXEyedropperTool : PXTool {

}

- compositeColorAtPoint:(NSPoint)aPoint fromCanvas:controller;
- (void)mouseDownAt:(NSPoint)aPoint fromCanvasController:controller;
- (void)mouseDraggedFrom:(NSPoint)initialPoint to:(NSPoint)finalPoint fromCanvasController:controller;
- (void)mouseUpAt:(NSPoint)aPoint fromCanvasController:controller;
@end
