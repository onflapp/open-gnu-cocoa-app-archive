#import <AppKit/NSControl.h>
#import <AppKit/NSTextField.h>
#import <AppKit/NSScrollView.h>
/* #import <AppKit/tiff.h>		 NXImageBitmap */
#import <AppKit/NSGraphics.h>
#import <AppKit/AppKit.h>
#import <Foundation/NSBundle.h>		/* LocalizedString */
#import "NSStringAppended.h"
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import "ToyWin.h"
#import "ToyView.h"
#import "TVController.h"
#import "strfunc.h"


@implementation ToyWin (Drawing)

- (id)drawView:(unsigned char **)map info:(commonInfo *)cinf
{
	ToyView *view;

	if ((view = [[ToyView alloc] initDataPlanes:map info:cinf]) == nil)
		return nil;
        [view setCommText:commentText];
	if (scView) {
		[scView setDocumentView:view];
		// [scView setCopiesOnScroll:YES];
		[[scView contentView] setCopiesOnScroll:YES]; //GNUstep only
		[view release];
	}else // makeMapOnly == YES
		_tview = view;
	[self scrollProperly];
	[thiswindow display];
	[thiswindow makeKeyAndOrderFront:self];
	[view setCommString: [NSString stringWithCString:cinf->memo]];
	return self;
}


- (int)drawFromFile:(NSString *)fileName or:(NSData *)data
{
	id view;
	commonInfo *cinf;

	view = data
		? [[ToyView alloc] initFromData: data]
		: [[ToyView alloc] initWithContentsOfFile:fileName];
	if (view == nil)
		return Err_OPEN;
	[view setCommText:commentText];
	cinf = [view commonInfo];
	[self locateNewWindow:fileName width:cinf->width height:cinf->height];
	[self makeComment:cinf];
	[view setCommString: [NSString stringWithCString:cinf->memo]];
	if (scView) {
		[scView setDocumentView:view];
		[[scView contentView] setCopiesOnScroll:YES]; //GNUstep only ???
		[view release];
	}else // makeMapOnly == YES
		_tview = view;
	[self scrollProperly];
	[thiswindow display];
	[thiswindow makeKeyAndOrderFront:self];
	return 0;
}

- (void)makeComment:(commonInfo *)cinf
{
	const char *alp = cinf->alpha ? "  Alpha" : "";
	const char *bilv;

	if (cinf->bits == 1 && cinf->numcolors <= 2) {
		bilv = [NSLocalizedString(@"Bilevel", Bilevel) cString];
		sprintf(cinf->memo, "%d x %d  %s%s",
			cinf->width, cinf->height, bilv, alp);
	}else {
		sprintf(cinf->memo, "%d x %d  %dbit%s",
			cinf->width, cinf->height, cinf->bits,
			((cinf->bits > 1) ? "s" : ""));
		if (cinf->numcolors <= 2) {
			strcat(cinf->memo, " ");
			strcat(cinf->memo,
			[NSLocalizedString(@"gray", gray) cString]);
		}else if (cinf->cspace == CS_CMYK)
			strcat(cinf->memo, " CMYK");
		strcat(cinf->memo, alp);
	}
}

- (void)makeComment:(commonInfo *)cinf from:(const commonInfo *)originfo
{
	const char *p;

	[self makeComment:cinf];
	if ((p = begin_comm(originfo->memo, YES)) != NULL) {
		strcat(cinf->memo, " : ");
		comm_cat(cinf->memo, p);
	} 
}

- (commonInfo *)drawToyWin:(NSString *)fileName type:(int)type
	map:(unsigned char **)map err:(int *)err
{
	if (type == Type_TIFF) {
		NSData *stream = [NSData dataWithContentsOfFile: fileName];
		if (stream == nil)
			return NULL;
		*err = [self drawFromFile:fileName or:stream];
	}else
		*err = [self drawFromFile:fileName or:NULL];
	if (*err)
		return NULL;
	return [[self toyView] commonInfo];
}

@end
