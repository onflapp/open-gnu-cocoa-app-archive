
// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.


#import <AppKit/AppKit.h>

@class NSMutableArray;
@class NSTableView;
@class NSButton;


@interface ProgressPanelController : NSWindowController
{
    IBOutlet NSTableView	*tableView;
	NSMutableArray			*requests;
    IBOutlet NSButton		*killButton;
    IBOutlet NSButton		*moreInfoButton;
}

+ (id) sharedProgressPanelController;
- (IBAction) interruptSelectedRequests:(id)sender;
- (IBAction) moreInfo:(id)sender;

@end

