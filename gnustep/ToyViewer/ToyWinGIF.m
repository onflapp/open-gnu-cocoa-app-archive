//
//  ToyWinGIF.m
//  ToyViewer
//
//  Created by ogihara on Tue May 01 2001.
//  Copyright (c) 2001 OGIHARA Takeshi. All rights reserved.
//
//  Note that this code DOES NOT use LZW compression Algorithm.

#import "ToyWinGIF.h"
#import <Foundation/NSString.h>
#import <Foundation/NSData.h>
#import <Foundation/NSBundle.h>		/* LocalizedString */
#import <stdlib.h>
#import <string.h>
#import "strfunc.h"
#import "imfunc.h"
#import "ToyView.h"

#define INTERLACE		0x40
#define LOCALCOLORMAP		0x80
#define TRANSPARENCY		0x01
#define BitSet(byte, bit)	(((byte) & (bit)) == (bit))

@implementation ToyWinGIF

/* Local Sub-Method */
- (int)get_short
{
	int c = *bp++;
	return ((*bp++ << 8) | c);
}

/* Local Sub-Method */
- (long)get_long
{
	long c = [self get_short];
	return (([self get_short] << 16) | c);
}

/* Local Sub-Method */
- (int)loadGifHeader
{
	unsigned char	buf[16];
	int i, cc;

	for (i = 0; i < 6; i++)
		buf[i] = *bp++;
	buf[6] = 0;
	if (strcmp(buf,"GIF87a") != 0 && strcmp(buf,"GIF89a") != 0)
		return Err_FORMAT;
	gh.width	= [self get_short];
	gh.height	= [self get_short];
	gh.colors	= 2 << ((cc = *bp++) & 0x07);
	gh.bits	= 8;
	gh.Resolution	= ((cc & 0x70) >> 3) + 1;
	gh.colormap	= BitSet(cc, LOCALCOLORMAP);
	gh.transp	= -1;
	gh.interlace	= BitSet(cc, INTERLACE);
	gh.Background	= *bp++;
	gh.AspectRatio	= *bp++;
	strcpy(gh.ver, buf+3);
	gh.memo	= NULL;
	return 0;
}

/* Local Sub-Method */
- (int)getDataBlock:(unsigned char *)buf
{
	int i, count;

	count = *bp++;
	for (i = 0; i < count; i++)
		buf[i] = *bp++;
	buf[count] = 0;
	return count;
}

/* Local Sub-Method */
- (int)doExtension
{
	int cc;
	unsigned char	buf[256];

	switch (cc = *bp++) {
	case 0x01:		/* Plain Text Extension */
	case 0x2c:		/* Image Descriptor */
	case 0x3b:		/* Trailer */
	case 0xff:		/* Application Extension */
		break;
	case 0xf9:		/* Graphic Control Extension */
		while ([self getDataBlock: buf] != 0) {
		    if (BitSet(buf[0], TRANSPARENCY))
			gh.transp = buf[3] & 0xff;	/* Transparent Index */
		}
		return cc;
	case 0xfe:		/* Comment Extension */
		while ([self getDataBlock: buf] != 0) {
		    if (gh.memo == NULL) {
			unsigned char *p;
			int	i;
			gh.memo = p = (unsigned char *)str_dup(buf);
			for (i = 0; *p; p++, i++) {
				if (*p < ' ') *p = ' ';
				if (i >= MAX_COMMENT-1) {
					*p = 0;
					break;
				}
			}
		    }
		}
		return cc;
	default:
		return -1;	/* ERROR */
	}
	while ([self getDataBlock: buf] != 0)
		;
	return cc;
}

/* Local Method */
- (int)getGifInformation
{
	int	c, err;

	if ((err = [self loadGifHeader]) != 0)
		return err;
	if (gh.colormap)	/* Skip Global Colormap */
		bp += gh.colors * 3;

	while ((c = *bp++) != ',' ) {	/* start character */
		if (c == EOF || c == ';')	/* GIF terminator */
			return Err_SHORT;
		if (c == '!') { 	/* Extension */
			if ([self doExtension] < 0)
				return Err_ILLG;
		}
		/* other chars are illegal... ignore */
	}

	bp += 4;  /* skip 4 bytes */
	gh.width = [self get_short];
	gh.height = [self get_short];
	c = *bp++;
	gh.interlace = BitSet(c, INTERLACE);
	if (BitSet(c, LOCALCOLORMAP)) { /* Skip Local Color Map */
		gh.colors = 2 << (c & 0x07);
		bp += gh.colors * 3;
	}
	gh.bits = 8;  /* howManyBits(gh.palette, gh.colors); */
	bp++;	/* skip code_size */
	return 0;
}


- (void)dealloc
{
	if (gh.memo) (void)free((void *)(gh.memo));
	[super dealloc];
}

/* override */
- (commonInfo *)drawToyWin:(NSString *)fileName type:(int)type
	map:(unsigned char **)map err:(int *)err
{
	NSData *stream;
	int errcode;

	if (type != Type_gif)
		return [super drawToyWin:fileName type:type map:map err:err];

	stream = [NSData dataWithContentsOfFile: fileName];
	if (stream == nil)
		return NULL;
	bp = [stream bytes];
//	bpend = bp + [stream length];
	if ((errcode = [self getGifInformation]) != 0) {
		*err = errcode;
		return NULL;
	}
#ifdef DEBUG_BOGUS
	/* Apple's GIF reader (Mac OS X Ver.10.0.1) would be based on
	   'giftoppm' or 'giftopnm' of David Koblas.
	   This routine sometimes causes fault, because of extra
	   input codes appended at the end of the stream.
	   If you want to display these GIF images, use 'gif2pxo' as
	   filter of ToyViewer.
	*/
	while (bp < bpend) {
		unsigned int k = *bp++;
		if (k == 0)
			break;
		bp += k;
	}
#endif
	*err = [self drawFromFile:fileName or:stream];
	return [[self toyView] commonInfo];
}

/* override */
- (void)makeComment:(commonInfo *)cinf
{
	int b;

	if (cinf->palette == NULL) { /* ERROR */
		sprintf(cinf->memo, "%d x %d  gif %dbit%s",
			cinf->width, cinf->height, cinf->bits,
			((cinf->bits > 1) ? "s" : ""));
		return;
	}
	b = howManyBits(cinf->palette, cinf->palsteps);
	sprintf(cinf->memo, "%d x %d  gif %dbit%s(%dcolors)",
		cinf->width, cinf->height,
		b, ((b > 1) ? "s" : ""), cinf->palsteps);
	if (isGray(cinf->palette, cinf->palsteps)) {
		strcat(cinf->memo, " ");
		strcat(cinf->memo,
			[NSLocalizedString(@"gray", gray) cString]);
	}
	if (gh.interlace)
		strcat(cinf->memo, " interlace");
	if (cinf->alpha)
		strcat(cinf->memo, " alpha");
	if (gh.memo) {
		strcat(cinf->memo, " : ");
		str_lcat(cinf->memo, gh.memo, MAX_COMMENT);
	}
}

@end
