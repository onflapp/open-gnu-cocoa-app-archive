//
//  PXAboutPanel.m
//  Pixen-XCode
//
//  Created by Andy Matuschak on Sun Aug 01 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXAboutPanel.h"

@interface NSObject (DelegateMethods)
- (BOOL)handlesKeyDown:keyDown inWindow:window;
- (BOOL)handlesMouseDown:mouseDown inWindow:window;
@end

@implementation PXAboutPanel

- (BOOL)canBecomeMainWindow
{
    return YES;
}

- (BOOL)canBecomeKeyWindow
{
    return YES;
}

@end
