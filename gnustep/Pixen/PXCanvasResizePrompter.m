//
//  PXCanvasResizePrompter.m
//  Pixen-XCode
//
//  Created by Ian Henderson on Wed Jun 09 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXCanvasResizePrompter.h"
#import "PXCanvasResizeView.h"


@implementation PXCanvasResizePrompter

- init
{
    return [super initWithWindowNibName:@"PXCanvasResizePrompt"];
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

- (IBAction)updateBgColor:sender
{
	[resizeView setBackgroundColor:[backgroundColor color]];
}

- (IBAction)useEnteredFrame:sender
{
    [delegate prompter:self didFinishWithSize:[resizeView newSize] position:[resizeView position] backgroundColor:[backgroundColor color]];
    [NSApp endSheet:[self window]];
    [self close];
}

- (IBAction)cancel:sender
{
    [NSApp endSheet:[self window]];
    [self close];
}

- (IBAction)updateSize:sender
{
	[resizeView setNewImageSize:NSMakeSize([[sizeForm cellAtIndex:0] intValue], [[sizeForm cellAtIndex:1] intValue])];
}

- (void)setCurrentSize:(NSSize)size
{
    [[sizeForm cellAtIndex:0] setIntValue:size.width];
    [[sizeForm cellAtIndex:1] setIntValue:size.height];
	[resizeView setNewImageSize:size];
	[resizeView setOldImageSize:size];
}

- (void)setCachedImage:(NSImage *)image
{
	[resizeView setCachedImage:image];
}


@end
