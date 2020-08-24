// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <AppKit/AppKit.h>


@interface CVLConsoleController : NSWindowController
{
    IBOutlet NSTextView	*text;
    IBOutlet NSButton	*autoPopupSwitch;
    IBOutlet NSFormCell	*popupTimeoutFormCell;
    IBOutlet NSButton	*logRequestsSwitch;
}

+ (CVLConsoleController *) sharedConsoleController;

- (IBAction) clearText:(id)sender;
- (IBAction) toggleAutoPopup:(id)sender;
- (IBAction) updatePopupTimeout:(id)sender;
- (IBAction) toggleRequestLogging:(id)sender;

- (void) output:(NSString *) aString;
- (void) output:(NSString *) aString bold: (BOOL) flag;
- (void) outputError:(NSString *)aString;
- (void) output:(NSString *) aString bold: (BOOL) flag error:(BOOL)flagE italic:(BOOL)flagI;

- (BOOL) showConsoleAtStartup;

@end

