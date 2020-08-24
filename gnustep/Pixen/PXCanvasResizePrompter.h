//
//  PXCanvasResizePrompter.h
//  Pixen-XCode
//
//  Created by Ian Henderson on Wed Jun 09 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import <AppKit/AppKit.h>


@class PXCanvasResizeView;

@interface NSObject(PXCanvasResizePrompterDelegate)
- (void)prompter:aPrompter didFinishWithSize:(NSSize)size position:(NSPoint)position backgroundColor:(NSColor *)color;
@end

@interface PXCanvasResizePrompter : NSWindowController {
    IBOutlet NSForm *sizeForm;
    IBOutlet PXCanvasResizeView *resizeView;
    IBOutlet NSColorWell *backgroundColor;
	NSImage *cachedImage;
    id delegate;
}
- init;
- (void)setDelegate:newDelegate;
- (void)promptInWindow:window;

- (IBAction)cancel:sender;
- (IBAction)updateBgColor:sender;
- (IBAction)updateSize:sender;
- (IBAction)useEnteredFrame:sender;
- (void)setCurrentSize:(NSSize)size;
- (void)setCachedImage:(NSImage *)image;
@end
