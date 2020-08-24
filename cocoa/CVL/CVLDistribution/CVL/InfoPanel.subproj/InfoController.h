
// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

extern NSString* CVLCurrentVersion;

@class NSPanel;


@interface InfoController : NSObject
{
    id versionCell;	
    id dateCell;
    id expirationMesgCell;
    id thePanel;
    id imgView;
    id textView;
    IBOutlet NSPanel	*cvsInfoPanel;
}

- (void) showPanel;
- (void) showCvsPanel;
- (void) showImg: sender;

- (IBAction) openMailer:(id)sender;
- (IBAction) openURL:(id)sender;

@end
