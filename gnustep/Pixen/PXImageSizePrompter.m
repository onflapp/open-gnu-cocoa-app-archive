//
//  PXImageSizePrompter.m
//  Pixel Editor
//
//  Created by Open Sword Group on Thu May 01 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import "PXImageSizePrompter.h"
#import "PXCanvasView.h"

@implementation PXImageSizePrompter

- init
{
    return [super initWithWindowNibName:@"PXImageSizePrompt"];
}

- (void)setDelegate:newDelegate
{
    delegate = newDelegate;
}

- (void)promptInWindow:window
{
    if([[[NSProcessInfo processInfo] arguments] containsObject:@"-SenTest"]) { return; }
    [NSApp beginSheet:[self window] modalForWindow:window modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (IBAction)useEnteredSize:sender
{
    [delegate prompter:self didFinishWithSize:NSMakeSize([[sizeForm cellAtIndex:0] intValue], [[sizeForm cellAtIndex:1] intValue])];
    [NSApp endSheet:[self window]];
    [self close];
}

- (void)setDefaultSize:(NSSize)size
{
    [[sizeForm cellAtIndex:0] setIntValue:size.width];
    [[sizeForm cellAtIndex:1] setIntValue:size.height];
}

@end
