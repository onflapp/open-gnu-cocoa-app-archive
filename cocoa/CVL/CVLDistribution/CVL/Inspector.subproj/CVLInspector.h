
// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <AppKit/AppKit.h>

@interface CVLInspector:NSObject
{
    IBOutlet NSWindow *window;
    IBOutlet NSView *view;
    NSArray *inspected;

}


+ (CVLInspector *) sharedInstance;
- (NSView *) view;

- (NSArray *) inspected;
- (void) setInspected:(NSArray *) anArray;
- (NSString *) firstInspectedFile;

- (void) update;
@end
