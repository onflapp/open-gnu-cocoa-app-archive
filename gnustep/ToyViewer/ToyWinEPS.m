#import "ToyWinEPS.h"
#import <AppKit/NSTextField.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSImageRep.h>
#import <AppKit/NSCachedImageRep.h>
#import <AppKit/NSEPSImageRep.h>
#import <AppKit/NSBitmapImageRep.h>
#import <Foundation/NSData.h>
#import "NSStringAppended.h"
#import <stdio.h>
//#import <libc.h>
#import <string.h>
#import <math.h>
#import "ToyView.h"
#import "ColorSpaceCtrl.h"
#import "common.h"
#import "strfunc.h"
#import "rescale.h"

@implementation ToyWinEPS

/* Overload */
- (NSData *)openEPSData
{
	NSEPSImageRep *rep;

	rep = (NSEPSImageRep *)[[[self toyView] image]
			bestRepresentationForDevice:nil];
	return [rep EPSRepresentation];
}

/* Overload */
- (NSData *)openVectorData
{
	return [self openEPSData];
}

#define  EPSLINEMAX	512

/* New */
- (NSData *)rotateEPS:(int)op to:(int)angle width:(int)lx height:(int)ly name:(NSString *)fname error:(int *)err
{
	NSMutableData *stream;
	NSEPSImageRep *rep;
        NSData	*dat;
	NSRect	rect;
	int	dx, dy;
	char buf[EPSLINEMAX * 2];

	*err = 0;
	rep = (NSEPSImageRep *)[[[self toyView] image]
			bestRepresentationForDevice:nil];
	dat = [rep EPSRepresentation];
	rect = [rep boundingBox];
	stream = [NSMutableData dataWithLength: 0];
	// stream will be autoreleased.
	if (stream == NULL || !dat) {
		*err = Err_MEMORY;
		return NULL;
	}
	dx = -(rect.origin.x + rect.size.width);
	dy = -(rect.origin.y + rect.size.height);
	if (op == Horizontal) {
		dy = -rect.origin.y;
	}else if (op == Vertical) {
		dx = -rect.origin.x;
	}else if (angle == 90) {
		dx = -rect.origin.x;
	}else if (angle == 270) {
		dy = -rect.origin.y;
	}else if (angle != 180) {
		commonInfo *cinf;
		double r, s, c;
		double th = ((double)angle * 3.14159265) / 180.0;
		cinf = [[self toyView] commonInfo];
		if (angle > 270) {
			r = cinf->width * (s = sin(th));
			dx = -r * s;
			dy = -r * cos(th);
		}else if (angle > 180) {
			r = cinf->height * (c = cos(th));
			dx = -r * sin(th) - cinf->width;
			dy = -r * c;
		}else if (angle > 90) {
			r = cinf->width * (c = cos(th));
			dx = -r * c;
			dy = r * sin(th) - cinf->height;
		}else {
			r = cinf->height * (s = sin(th));
			dx = r * cos(th);
			dy = -r * s;
		}
		dx -= rect.origin.x - 0.5;
		dy -= rect.origin.y - 0.5;
	}

	sprintf(buf, "%s\n%s: %s\n",
		"%!PS-Adobe-2.0 EPSF-2.0", "%%Title",
		[fname fileSystemRepresentation]);
        [stream appendBytes: buf length: strlen(buf)];
	sprintf(buf, "%s: 0 0 %d %d\n%s\n\ngsave\n",
		"%%BoundingBox", lx, ly, "%%EndComments");
        [stream appendBytes: buf length: strlen(buf)];
	if (op == Rotation)
		sprintf(buf, "%d rotate\n", angle);
	else
		sprintf(buf, "%s scale\n", (op == Horizontal)?"-1 1":"1 -1");
	[stream appendBytes: buf length: strlen(buf)];
	sprintf(buf, "%d %d translate\n%s\n", dx, dy, "%%BeginDocument: ");
	[stream appendBytes: buf length: strlen(buf)];
        [stream appendData: dat];
	sprintf(buf, "\n%s\ngrestore\n", "%%EndDocument");
	[stream appendBytes: buf length: strlen(buf)];
	return stream;
}

/* New */
- (NSData *)clipEPS:(NSRect)select error:(int *)err
{
	NSMutableData	*stream = nil;
	NSData	*dat = nil;
	NSEPSImageRep *rep;
	NSRect	rect;
	const unsigned char	*eps;
	unsigned char	tmpstr[EPSLINEMAX];
	int	i, n, bp, bflag;
	int	loc[4];
	char buf[EPSLINEMAX * 2];

	*err = 0;
	rep = (NSEPSImageRep *)[[[self toyView] image] bestRepresentationForDevice:nil];
	if ((dat = [rep EPSRepresentation]) == nil) {
		*err = Err_MEMORY;
		return NULL;
	}
	rect = [rep boundingBox];
	loc[0] = rect.origin.x + select.origin.x;
	loc[1] = rect.origin.y + select.origin.y;
	loc[2] = loc[0] + (int)select.size.width;
	loc[3] = loc[1] + (int)select.size.height;
        stream = [NSMutableData dataWithCapacity:(n = [dat length])];
	// stream will be autoreleased.
	if (stream == NULL) {
		*err = Err_MEMORY;
		return nil;
	}
	eps = [dat bytes];
	bflag = 1;
	for (i = 0, bp = 0; i < n; i++) {
		if ((tmpstr[bp++] = *eps++) >= ' ')
			continue;
		tmpstr[bp] = 0;
                if (bflag && strncmp(tmpstr, "%%BoundingBox", 13) == 0) {
			sprintf(buf, "%s: %d %d %d %d\n", "%%BoundingBox",
				loc[0], loc[1], loc[2], loc[3]);
			[stream appendBytes: buf length: strlen(buf)];
			bflag = 0;
		}else
			[stream appendBytes: tmpstr length: bp];
		bp = 0;
	}
	return stream;
}


/* New */
- (NSData *)resizeEPS:(float)factor name:(NSString *)fname error:(int *)err
{
	NSMutableData	*stream = nil;
	NSEPSImageRep *rep;
	NSData *dat;
	NSRect	rect;
	unsigned char	tmpstr[EPSLINEMAX];
	int	loc[4];

	*err = 0;
	rep = (NSEPSImageRep *)[[[self toyView] image] bestRepresentationForDevice:nil];
	dat = [rep EPSRepresentation];
	rect = [rep boundingBox];
	loc[0] = rect.origin.x * factor;
	loc[1] = rect.origin.y * factor;
	calcWidthAndHeight(&loc[2], &loc[3], rect.size.width, rect.size.height, factor);
	loc[2] += loc[0];
	loc[3] += loc[1];
	stream = [NSMutableData dataWithCapacity: [dat length]];
	// stream will be autoreleased.
	if (stream == NULL || !dat) {
		// [dat release];
		*err = Err_MEMORY;
		return NULL;
	}
        sprintf(tmpstr, "%s\n%s: %s\n",
		"%!PS-Adobe-2.0 EPSF-2.0", "%%Title",
		[fname fileSystemRepresentation]);
	[stream appendBytes: tmpstr length: strlen(tmpstr)];
	sprintf(tmpstr, "%s: %d %d %d %d\n%s\n\n", "%%BoundingBox",
		loc[0], loc[1], loc[2], loc[3], "%%EndComments");
	[stream appendBytes: tmpstr length: strlen(tmpstr)];
	sprintf(tmpstr, "gsave\n%f %f scale\n%s\n",
		factor, factor, "%%BeginDocument: ");
	[stream appendBytes: tmpstr length: strlen(tmpstr)];
	[stream appendData: dat];
        sprintf(tmpstr, "\n%s\ngrestore\n", "%%EndDocument");
	[stream appendBytes: tmpstr length: strlen(tmpstr)];
	return stream;
}

@end
