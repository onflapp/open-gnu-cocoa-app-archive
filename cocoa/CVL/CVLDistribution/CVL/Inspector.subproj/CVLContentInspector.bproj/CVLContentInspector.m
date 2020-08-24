/* CVLContentInspector.m created by stephanec on Mon 13-Dec-1999 */
/* Copyright (c) 1997, Sen:te Ltd.  All rights reserved. */

#import "CVLContentInspector.h"
#import "CVLFile.h"
#import <SenFoundation/SenFoundation.h>


@implementation CVLContentInspector

- (id) init
{
    if ( (self = [super init]) ) {
        NSTextContainer	*textContainer= [textView textContainer];

        [[textView enclosingScrollView] setHasHorizontalScroller:YES];

        [textContainer setWidthTracksTextView:NO];
        [textContainer setHeightTracksTextView:NO];
        [textContainer setContainerSize:NSMakeSize(1.0e7, 1.0e7)];

        [textView setMaxSize:NSMakeSize(1.0e7, 1.0e7)];
        [textView setHorizontallyResizable:YES];
        [textView setVerticallyResizable:YES];
        [textView setAutoresizingMask:NSViewNotSizable];
        
        [noContentView retain];
        [contentView retain];
        [view retain];
    }

    return self;
}

- (void) update
{
    NSView		*displayedView;
    CVLFile		*inspectedFile;
    NSString	*extension;

    NSAssert1([[self inspected] count] == 1, @"Inspected file count is different than 1 (%d)", [[self inspected] count]);
    
    inspectedFile = (CVLFile *)[CVLFile treeAtPath:[[self inspected] lastObject]];
    extension = [[[inspectedFile path] pathExtension] lowercaseString];

    if(![extension isEqualToString:@"rtfd"] && ([inspectedFile flags].isDir || [inspectedFile flags].isWrapper || [inspectedFile isBinary]/* || ![inspectedFile flags].isInWorkArea*/))
        displayedView = noContentView;
    else{
        displayedView = contentView;

        // Will read rtf, rtfd and html files correctly, as well as any text file
        if(![textView readRTFDFromFile:[inspectedFile path]]){
            // If previous call failed, it means that file does not exist??
            NSString	*aString = [[NSString alloc] initWithContentsOfFile:[inspectedFile path]];

            if(!aString)
                displayedView = noContentView;
            else{
                [textView setString:aString];
                [textView setFont:[NSFont userFixedPitchFontOfSize:10]];
                [aString release];
            }
        }
        else{
            if(![extension isEqualToString:@"rtf"] && ![extension isEqualToString:@"rtfd"] && ![extension isEqualToString:@"htm"] && ![extension isEqualToString:@"html"])
                [textView setFont:[NSFont userFixedPitchFontOfSize:10]];
        }
    }
    
    if(view != displayedView){
        [displayedView setFrame:[view frame]];
        [[view superview] replaceSubview:view with:displayedView];
        ASSIGN(view, displayedView);
    }
    [view setNeedsDisplay:YES];
}

@end
