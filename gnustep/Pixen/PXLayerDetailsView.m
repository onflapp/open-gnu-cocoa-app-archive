//
//  PXLayerDetailsView.m
//  Pixen-XCode
//
//  Created by Joe Osborn on Thu Feb 05 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXLayerDetailsView.h"
#import "PXLayer.h"
#import "PXCanvas.h"
#import "PXCanvasController.h"
#ifndef __COCOA__
#import "PXLayerDetailsSubView.h"
#endif


@implementation PXLayerDetailsView

- initWithLayer:aLayer
{
	[super init];
	[NSBundle loadNibNamed:@"PXLayerDetailsView" owner:self];
#ifndef __COCOA__

  id myView = [[window contentView] retain];
  view = [[PXLayerDetailsSubView alloc] initWithFrame:[myView frame]];
  [view addSubview:myView];
#endif
    
	[self addSubview:view];
	[self setLayer:aLayer];
	NSLog(@"****************** thumbnail %@",thumbnail);
	[thumbnail setImage:image];
	[thumbnail setEditable:NO];
	isHidden = YES;
	changedRect = NSZeroRect;
	return self;
}

- opacityText
{
	return opacityText;
}

- (void)dealloc
{
	[self invalidateTimer];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

- (void)setLayer:aLayer
{
  [self invalidateTimer];
  //set preview, name field, and other state
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  layer = aLayer;
  [image release];
  image = [[NSImage alloc] initWithSize:[layer size]];
  [name setStringValue:[layer name]];
  [opacity setFloatValue:[layer opacity]];
  [opacityField setFloatValue:[layer opacity]];
  [self updatePreview:nil];
  [visibility setState:[layer visible]];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatePreview:) name:PXCanvasChangedNotificationName object:nil];
  timer = [[NSTimer scheduledTimerWithTimeInterval:0.8 target:self selector:@selector(shouldRedraw:) userInfo:nil repeats:YES] retain];
  [self setNeedsDisplay:YES];
  [view setLayer:layer];
}

- (void)updatePreview:notification
{
#ifdef __COCOA__
  if(((notification != nil)
      && (layer != [[notification userInfo] objectForKey:@"activeLayer"])) 
     || [self isHidden]) 
    {
      
      return; 
    }
#endif
  changedRect = NSUnionRect(changedRect, (notification == nil) ? NSMakeRect(0,0,[layer size].width,[layer size].height) : [[[notification userInfo] objectForKey:@"changedRect"] rectValue]);
}

- (IBAction)visibilityDidChange:sender
{
	[layer setVisible:([sender state] == NSOnState) ? YES : NO];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"PXCanvasShouldRedrawNotificationName" object:layer];
}

- (void)shouldRedraw:timer
{
#ifdef __COCOA__
  if (NSIsEmptyRect(changedRect)) 
    {
      return; 
    }
#endif
  NSLog(@"thumbnail %@",thumbnail);
  [image lockFocus];
  BOOL oldVisibility = [layer visible];
  int oldOpacity = [layer opacity];
  [layer setVisible:YES];
  [layer setOpacity:100];
  [[NSColor clearColor] set];
  NSRectFill(changedRect);
  [layer drawRect:changedRect fixBug:YES];
  [layer setVisible:oldVisibility];
  [layer setOpacity:oldOpacity];
  [image unlockFocus];
  [thumbnail setImage:nil];
  [thumbnail setImage:image];
  [thumbnail setNeedsDisplay:YES];
  changedRect = NSZeroRect;
}

- (void)invalidateTimer
{
	if((timer != nil) && [timer isValid])
	{
		[timer invalidate];
		[timer release];
		timer = nil;
	}
}

- (BOOL)isHidden
{
#ifdef __COCOA__
  if([super respondsToSelector:@selector(isHidden)])
    {
      return [super isHidden];
    }
  return isHidden;
#else
  return NO;
#endif
}

- (void)setHidden:(BOOL)newHidden
{
#ifdef __COCOA__
	if([self isHidden] == newHidden) { return; }
	if([super respondsToSelector:@selector(setHidden:)]) { [super setHidden:newHidden]; }
	isHidden = newHidden;
	[self updatePreview:nil];
#endif
}

- (IBAction)opacityDidChange:sender
{
  [opacity setFloatValue:[sender floatValue]];
  [opacityField setFloatValue:[sender floatValue]];
  [layer setOpacity:[sender floatValue]];
  [[NSNotificationCenter defaultCenter] postNotificationName:@"PXCanvasShouldRedrawNotificationName" object:layer];
}

- (IBAction)nameDidChange:sender
{
  [(PXLayer *)layer setName:[name stringValue]];
}

@end
