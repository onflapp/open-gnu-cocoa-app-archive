/* CVLContentInspector.h created by stephanec on Mon 13-Dec-1999 */
/* Copyright (c) 1997, Sen:te Ltd.  All rights reserved. */

#import <CVLInspector.h>


@interface CVLContentInspector : CVLInspector
{
    IBOutlet NSTextView	*textView;
    IBOutlet NSView		*contentView;
    IBOutlet NSView		*noContentView;
}

@end
