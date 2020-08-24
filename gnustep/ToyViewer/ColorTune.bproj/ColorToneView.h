//
//  ColorToneView.h
//  ToyViewer
//
//  Created on Thu Jun 13 2002.
//  Copyright (c) 2002 OGIHATA Takeshi. All rights reserved.
//

#import  <AppKit/NSView.h>
#import  "colorEnhance.h"

typedef float	t_RGB[3];

@interface ColorToneView: NSView
{
	id	cache;
	int	colors;
	int	eachheight;
	float	toneParams[N_Colors];
	t_RGB	*tone[2];
}

- (id)initWithFrame:(NSRect)frameRect;	/* Overload */
- (void)dealloc;
- (void)drawRect:(NSRect)r;	/* Overload */
- (void)setToneParameters:(float *)param;

@end
