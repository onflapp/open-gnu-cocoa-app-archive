#import "ImgOperatorClipped.h"
#import <AppKit/NSApplication.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSBitmapImageRep.h>
#import <AppKit/NSControl.h>
#import <AppKit/NSPanel.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import "TVController.h"
#import "ToyWin.h"
#import "ToyView.h"
#import "common.h"
#import "getpixel.h"
#import "AlertShower.h"
#import "WaitMessageCtr.h"

@implementation ImgOperatorClipped

+ (BOOL)detectParent
{
	return NO;
}

- (id)init
{
	[super init];
	selected = NO;
	outside = NO;
	return self;
}

- (void)setOutside:(BOOL)flag
{
	outside = flag;
}

/* overwrite */
- (void)setupWith:(ToyView *)tv
{
	NSRect	selrect;

	selrect = [tv selectedScaledRect];
	if (selrect.size.width <= 0 || selrect.size.height <= 0
		|| (selrect.size.width >= cinf->width &&
			selrect.size.height >= cinf->height))
		selected = NO;
	else {
		xorg = selrect.origin.x;
		xend = selrect.size.width + xorg - 1;
		yorg = cinf->height -
			(selrect.origin.y + selrect.size.height);
		yend = cinf->height - selrect.origin.y - 1;
                selected = YES;
	}
}

@end

