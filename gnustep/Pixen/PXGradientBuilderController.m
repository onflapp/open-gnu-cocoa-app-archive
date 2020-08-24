//
//  PXGradientBuilderController.m
//  Pixen-XCode
//
//  Created by Ian Henderson on 26.08.04.
//  Copyright 2004 Open Sword Group. All rights reserved.
//

#import "PXGradientBuilderController.h"
#import "PXPaletteSwitcher.h"
#import "PXPalette.h"

@implementation PXGradientBuilderController

- init
{
	return [super initWithWindowNibName:@"PXGradientBuilder"];
}

- initWithPaletteSwitcher:(PXPaletteSwitcher *)aSwitcher
{
	[self init];
	switcher = aSwitcher;
	return self;
}

- (void)beginSheetInWindow:window
{
    [NSApp beginSheet:[self window] modalForWindow:window modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (IBAction)create:sender
{
	NSMutableArray *colors = [NSMutableArray arrayWithCapacity:[colorsField intValue]];
	int i;
	float r, g, b, a, deltaR, deltaG, deltaB, deltaA;
	int colorCount = [colorsField intValue];
	NSColor *startColor = [[startColorWell color] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	NSColor *endColor = [[endColorWell color] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	r = [startColor redComponent];
	g = [startColor greenComponent];
	b = [startColor blueComponent];
	a = [startColor alphaComponent];
	deltaR = ([endColor redComponent] - r) / colorCount;
	deltaG = ([endColor greenComponent] - g) / colorCount;
	deltaB = ([endColor blueComponent] - b) / colorCount;
	deltaA = ([endColor alphaComponent] - a) / colorCount;
	
	for (i=0; i<colorCount; i++) {
		[colors addObject:[NSColor colorWithCalibratedRed:r green:g blue:b alpha:a]];
		r += deltaR;
		g += deltaG;
		b += deltaB;
		a += deltaA;
	}
	
	PXPalette *palette = [[[PXPalette alloc] initWithName:[nameField stringValue] colors:colors] autorelease];
	
	[switcher addNewPalette:palette withName:[nameField stringValue] replacingPaletteAtIndex:[switcher indexOfPalette:palette]]; 
    [NSApp endSheet:[self window]];
    [self close];
}

- (IBAction)cancel:sender
{
    [NSApp endSheet:[self window]];
    [self close];
}

@end
