//
//  PXTool.m
//  Pixen-XCode
//
//  Created by Joe Osborn on Sat Dec 06 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import "PXTool.h"

@implementation PXTool

- (NSString *)name
{
	return @"";
}

- (void)setSwitcher:aSwitcher { switcher = aSwitcher; }

- (void)mouseDownAt:(NSPoint)aPoint fromCanvasController:controller {}

- (void)mouseDraggedFrom:(NSPoint)origin to:(NSPoint)destination fromCanvasController:controller {}

- (void)mouseUpAt:(NSPoint)point fromCanvasController:controller {}

- undoManager
{
    return [[[NSDocumentController sharedDocumentController] currentDocument] undoManager];
}

- propertiesView { return propertiesView; }

- (BOOL)shiftKeyDown { return NO; }
- (BOOL)shiftKeyUp { return NO; }
- (BOOL)optionKeyDown { return NO; }
- (BOOL)optionKeyUp { return NO; }

@end
