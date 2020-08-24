//
//  PXImageSizePrompter.h
//  Pixel Editor
//
//  Created by Open Sword Group on Thu May 01 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface NSObject(PXImageSizePrompterDelegate)
- (void)prompter:aPrompter didFinishWithSize:(NSSize)aSize;
@end

@interface PXImageSizePrompter : NSWindowController {
    IBOutlet NSForm * sizeForm;
    id delegate;
}
- init;
- (void)setDelegate:newDelegate;
- (void)promptInWindow:window;
- (IBAction)useEnteredSize:sender;
- (void)setDefaultSize:(NSSize)size;
@end
