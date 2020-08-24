
// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/Foundation.h>
#import "CVLInspector.h"


@interface VLStatusInspector:CVLInspector
{
    IBOutlet NSTextField *lastModifiedClock;
    IBOutlet NSTextField *lastCheckoutedClock;
    IBOutlet NSTextField *statusField;
    IBOutlet NSTextField *versionField;
    IBOutlet NSTextField *repVersionField;
    IBOutlet NSTextField *stickyTagField;
    IBOutlet NSTextField *stickyDateField;
    IBOutlet NSTextField *stickyOptionField;
}

@end
