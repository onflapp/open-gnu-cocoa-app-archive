//
//  ColorToneView.m
//  ToyViewer
//
//  Created on Thu Jun 13 2002.
//  Copyright (c) 2002 OGIHATA Takeshi. All rights reserved.
//

#import  "ColorToneView.h"
#import  <AppKit/NSImage.h>
#import  <AppKit/NSColor.h>
#import  <AppKit/NSBezierPath.h>
#import  <stdlib.h>
#include  <AppKit/NSGraphics.h> //GNUstep only ???
#define  MaxColors	128	/* 256 */
#define  StdSaturation	0.6
#define  StdBrightness	0.9


@interface ColorToneView (Local)
- (void)drawCache;
@end

@implementation ColorToneView

/* Overload */
- (id)initWithFrame:(NSRect)frameRect
{
	NSColor *clr, *newclr;
	int height;
	int i, k;
	float cs[3];

	[super initWithFrame:frameRect];
	cache = [[NSImage alloc] initWithSize: frameRect.size];
	height = frameRect.size.height;
	eachheight = (height + (MaxColors - 1)) / MaxColors;
	colors = (height + eachheight - 1) / eachheight;
	for (i = 0; i < N_Colors; i++)
		toneParams[i] = 0.0;
	tone[0] = malloc(sizeof(t_RGB) * colors * 2);
	tone[1] = (void *)(tone[0]) + sizeof(t_RGB) * colors;
	for (i = 0; i < colors; i++) {
		clr = [NSColor colorWithCalibratedHue:(float)i / colors
			saturation: StdSaturation
			brightness: StdBrightness alpha: 1.0];
		newclr = [clr colorUsingColorSpaceName:NSDeviceRGBColorSpace];
		[newclr getRed:&cs[0] green:&cs[1] blue:&cs[2] alpha:NULL];
		for (k = 0; k < 3; k++)
			tone[0][i][k] = tone[1][i][k] = cs[k];
	}
	[self drawCache];
	return self;
}

/* Overload */
- (void)dealloc
{
	[cache release];
	free(tone[0]);		// No need to free tone[1]
	[super dealloc];
}

/* Overload */
- (void)drawRect:(NSRect)r
{
	[cache compositeToPoint:(r.origin)
		fromRect:r operation:NSCompositeSourceOver];
}

/* Local Method */
- (void)drawCache
{
	int	i, tx;
	float	left, half, y;

	[cache lockFocus];
	half = [self frame].size.width / 2.0;

	for (tx = 0; tx < 2; tx++) {
		y = [self frame].size.height - eachheight;
		left = tx * half;
		for (i = 0; i < colors; i++) {
			[[NSColor colorWithCalibratedRed:tone[tx][i][0]
				green:tone[tx][i][1] blue:tone[tx][i][2] alpha:1.0] set];
			NSRectFill(NSMakeRect(left, y, half, eachheight));
			y -= eachheight;
		}
	}
	[cache unlockFocus]; 
}

- (void)setToneParameters:(float *)param
{
	int	i, k;
	int	elm[3];
	float	*orig, *newv, v;
	BOOL	changed = NO;

	for (i = 0; i < N_Colors; i++) {
		v = (int)(param[i] * 20.0) / 20.0;
		if (v != toneParams[i]) {
			toneParams[i] = v;
			changed = YES;
		}
	}
	if (!changed)
		return;
	sat_enhance_init(1.0);
	set_ratio(param);
	for (i = 0; i < colors; i++) {
		orig = tone[0][i];
		newv = tone[1][i];
		for (k = 0; k < 3; k++)
			elm[k] = orig[k] * 255.0;
		tone_enhance(elm);
		for (k = 0; k < 3; k++)
			newv[k] = elm[k] / 255.0;
	}
	[self drawCache]; 
}

@end
