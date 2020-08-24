/* VLDiffInspector.h created by vincent on Mon 08-Dec-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <CVLInspector.h>
#import <AppKit/AppKit.h>

@interface VLDiffInspector : CVLInspector
{
    IBOutlet NSTextView *diffText;
    IBOutlet NSScrollView *diffScrollView;
    IBOutlet NSFormCell	*contextFormCell;
    IBOutlet NSPopUpButton	*outputFormatPopup;
}

- (IBAction) setOutputFormat:(id)sender;
- (IBAction) setContextLineNumber:(id)sender;

@end
