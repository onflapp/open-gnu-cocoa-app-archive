//
//  PXTool.h
//  Pixen-XCode
//
//  Created by Joe Osborn on Sat Dec 06 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface PXTool : NSObject {
    id switcher;
	id propertiesView;
}

- (NSString *)name;

- (void)setSwitcher:aSwitcher;
- (void)mouseDownAt:(NSPoint)aPoint fromCanvasController:controller;
- (void)mouseDraggedFrom:(NSPoint)origin to:(NSPoint)destination fromCanvasController:controller;
- (void)mouseUpAt:(NSPoint)point fromCanvasController:controller;
- undoManager;
- propertiesView;

- (BOOL)shiftKeyDown;
- (BOOL)shiftKeyUp;
- (BOOL)optionKeyDown;
- (BOOL)optionKeyUp;
@end
