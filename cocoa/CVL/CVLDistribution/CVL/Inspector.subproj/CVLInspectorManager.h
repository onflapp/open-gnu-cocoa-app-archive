
// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <AppKit/AppKit.h>

@class CVLInspector, CVLFileIconWell;


@interface CVLInspectorManager:NSObject
{
    IBOutlet NSWindow *window;
    IBOutlet NSPopUpButton *inspectorPopup;
    IBOutlet NSTextField *filenameTextField;
    IBOutlet NSTextField *fullPathTextField;
    IBOutlet NSView *multiView;

    NSArray *inspectedObjects;
    NSMutableDictionary *inspectorDictionary;
    CVLInspector *currentInspector;
    IBOutlet CVLFileIconWell	*fileIconWell;
}

+ (CVLInspectorManager *) sharedInspector;
- (IBAction) showWindow:(id)sender;
- (NSWindow *) window;

- (IBAction) setInspectorFromPopup:(id)sender;
- (IBAction) setInspectorFromMenuItem:(id)sender;
- (void) setInspected:(NSArray *) anArray;

- (IBAction) nameEdited:(id)sender;
@end
