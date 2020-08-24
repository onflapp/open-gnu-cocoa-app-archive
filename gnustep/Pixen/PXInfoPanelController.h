//
//  PXInfoPanelController.h
//  Pixen-XCode
//
//  Created by Andy Matuschak on Thu Jul 29 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import <Foundation/NSObject.h>
#import <Foundation/NSGeometry.h>

#import <AppKit/NSNibDeclarations.h>

@class NSPanel;
@class NSTextField;

@interface PXInfoPanelController : NSObject
{
	NSPoint draggingOrigin;
	
	id teensyHexView;
	
	IBOutlet NSPanel *panel;
	
	IBOutlet NSTextField *cursorX;
	IBOutlet NSTextField *cursorY;
	IBOutlet NSTextField *width;
	IBOutlet NSTextField *height;
	IBOutlet NSTextField *red;
	IBOutlet NSTextField *green;
	IBOutlet NSTextField *blue;
	IBOutlet NSTextField *alpha;
}

//singleton
+ (id) sharedInfoPanelController;

- (void)setCursorPosition: (NSPoint)point;
- (void)setColorInfo:color;
- (void)setCanvasSize: (NSSize)size;
- (void)setDraggingOrigin: (NSPoint)point;

	//Accessor
- (NSPanel *) infoPanel;

@end
