//
//  PXScaleController.m
//  Pixen-XCode
//
//  Created by Ian Henderson on Thu Jun 10 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXScaleController.h"
#import "PXCanvas.h"
#import "PXCanvasController.h"
#import "PXNearestNeighborScaleAlgorithm.h"
#import "PXScale2xScaleAlgorithm.h"
#import "PXBicubicScaleAlgorithm.h"


@implementation PXScaleController

- init
{
	[super initWithWindowNibName:@"PXScalePrompt"];
	algorithms = [[NSArray alloc] initWithObjects:[PXNearestNeighborScaleAlgorithm algorithm], [PXBicubicScaleAlgorithm algorithm], [PXScale2xScaleAlgorithm algorithm], nil];
	return self;
}

- (void)scaleCanvasFromController:(PXCanvasController *)controller modalForWindow:(NSWindow *)theWindow
{
	canvasController = controller;
	if ([self isWindowLoaded]) {
		newSize = [[canvasController canvas] size];
		[[newWidthForm cellWithTag:0] setFloatValue:newSize.width];
		[[newHeightForm cellWithTag:0] setFloatValue:newSize.height];
		[[newWidthForm cellWithTag:1] setFloatValue:100.0f];
		[[newHeightForm cellWithTag:1] setFloatValue:100.0f];
	}
    [NSApp beginSheet:[self window] modalForWindow:theWindow modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (void)awakeFromNib
{
    [algorithmButton removeAllItems];
	NSEnumerator *algorithmEnumerator = [algorithms objectEnumerator];
	PXScaleAlgorithm *algorithm;
	while (algorithm = [algorithmEnumerator nextObject]) {
		[algorithmButton addItemWithTitle:[algorithm name]];
	}
	if ([[NSUserDefaults standardUserDefaults] objectForKey:@"PXSelectedScaleAlgorithm"] != nil) {
		[algorithmButton selectItemWithTitle:[[NSUserDefaults standardUserDefaults] objectForKey:@"PXSelectedScaleAlgorithm"]];
	}
	[self setAlgorithm:algorithmButton];
	newSize = [[canvasController canvas] size];
	[self synchronizeForms:self];
}

- (PXScaleAlgorithm *)currentAlgorithm
{
	return [algorithms objectAtIndex:[algorithmButton indexOfSelectedItem]];
}

- (IBAction)setAlgorithm:sender
{
	static BOOL lastAlgorithmHadParameterView = YES;
	
	NSSize newBoxSize = [scaleParameterView frame].size;
	if ([[self currentAlgorithm] hasParameterView]) {
		NSSize margins = [scaleParameterView contentViewMargins];
		newBoxSize.height = [[[self currentAlgorithm] parameterView] frame].size.height + margins.height * 2;
	} else {
		newBoxSize.height = 0;
	}
	
	NSRect newWindowFrame = [[self window] frame];
	newWindowFrame.size.height += newBoxSize.height - [scaleParameterView frame].size.height;
	if (![[self currentAlgorithm] hasParameterView] && lastAlgorithmHadParameterView) {
		newWindowFrame.size.height -= 8;
	}
	[[self window] setFrame:newWindowFrame display:YES animate:YES];
	
	if ([[self currentAlgorithm] hasParameterView]) {
		[scaleParameterView setContentView:[[self currentAlgorithm] parameterView]]; // Don't move this to the top of the method or it breaks.  No, I don't know why.
	}
	[scaleParameterView setFrameSize:newBoxSize];
	[algorithmInfoView setString:[[self currentAlgorithm] algorithmInfo]];
	
	lastAlgorithmHadParameterView = [[self currentAlgorithm] hasParameterView];

	[[NSUserDefaults standardUserDefaults] setObject:[[sender selectedItem] title] forKey:@"PXSelectedScaleAlgorithm"];
}

- (IBAction)cancel:sender
{
    [NSApp endSheet:[self window]];
    [self close];
}

- (NSSize)directSizeInput
{
	NSSize oldSize = [[canvasController canvas] size];
	NSSize directSizeInput;
	float xScale = [[newWidthForm cellWithTag:1] floatValue] / 100.0f, yScale = [[newHeightForm cellWithTag:1] floatValue] / 100.0f;
	directSizeInput.width = [[newWidthForm cellWithTag:0] floatValue];
	if (fabs(oldSize.width * xScale - newSize.width) > .01) {
		directSizeInput.width = oldSize.width * xScale;
	}
	directSizeInput.height = [[newHeightForm cellWithTag:0] floatValue];
	if (fabs(oldSize.height * yScale - newSize.height) > .01) {
		directSizeInput.height = oldSize.height * yScale;
	}
	return directSizeInput;
}

- (IBAction)synchronizeForms:sender
{
	NSSize oldSize = [[canvasController canvas] size];
	NSSize directSizeInput = [self directSizeInput];
	float xScale = [[newWidthForm cellWithTag:1] floatValue] / 100.0f, yScale = [[newHeightForm cellWithTag:1] floatValue] / 100.0f;
	BOOL scaleProportionally = ([scaleProportionallyCheckbox state] == NSOnState);
	directSizeInput.width = [[newWidthForm cellWithTag:0] floatValue];
	if (fabs(oldSize.width * xScale - newSize.width) > .01) {
		directSizeInput.width = oldSize.width * xScale;
	}
	directSizeInput.height = [[newHeightForm cellWithTag:0] floatValue];
	if (fabs(oldSize.height * yScale - newSize.height) > .01) {
		directSizeInput.height = oldSize.height * yScale;
	}
	if (directSizeInput.width != 0 && directSizeInput.width != newSize.width) {
		if (scaleProportionally) {
			newSize.height = directSizeInput.width * oldSize.height / oldSize.width;
		} else {
			newSize.height = directSizeInput.height;
		}
		newSize.width = directSizeInput.width;
	} else if (directSizeInput.height != 0 && directSizeInput.height != newSize.height) {
		if (scaleProportionally) {
			newSize.width = directSizeInput.height * oldSize.width / oldSize.height;
		} else {
			newSize.width = directSizeInput.width;
		}
		newSize.height = directSizeInput.height;
	}
	[[newWidthForm cellWithTag:0] setFloatValue:newSize.width];
	[[newHeightForm cellWithTag:0] setFloatValue:newSize.height];
	[[newWidthForm cellWithTag:1] setFloatValue:newSize.width / oldSize.width * 100.0f];
	[[newHeightForm cellWithTag:1] setFloatValue:newSize.height / oldSize.height * 100.0f];
}

- (IBAction)updateToScalePropotionally:sender
{
	if ([sender state] != NSOnState) {
		return;
	}
	NSSize directSizeInput = [self directSizeInput];
	NSSize oldSize = [[canvasController canvas] size];
	newSize.width = directSizeInput.height * oldSize.width / oldSize.height;
	newSize.height = directSizeInput.height;
	[self synchronizeForms:sender];
}

- (IBAction)scale:sender
{
	if ([[self currentAlgorithm] canScaleCanvas:[canvasController canvas] toSize:newSize]) {
		[[self currentAlgorithm] scaleCanvas:[canvasController canvas] toSize:newSize];
		[NSApp endSheet:[self window]];
		[canvasController updateCanvasSize];
		[self close];
	} else {
#ifdef __COCOA__
		NSBeep();
#endif
	}
}

@end
