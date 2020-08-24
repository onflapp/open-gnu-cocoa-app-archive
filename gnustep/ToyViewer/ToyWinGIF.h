//
//  ToyWinGIF.h
//  ToyViewer
//
//  Created by ogihara on Tue May 01 2001.
//  Copyright (c) 2001 OGIHARA Takeshi. All rights reserved.
//

#import "ToyWin.h"

typedef struct {
	int		width;
	int		height;
	int		colors;
	int		bits;		/* bits per sample */
	int		transp;		/* Transparency Index */
	unsigned short	Resolution;
	unsigned short	Background;
	unsigned short	AspectRatio;
	BOOL		colormap;
	BOOL		interlace;
//	BOOL		isgray;
	char		ver[4];
//	paltype		palette[256];
	unsigned char	*memo;
} gifHeader;


@interface ToyWinGIF : ToyWin
{
	const unsigned char	*bp;
//	const unsigned char	*bpend;
	gifHeader	gh;
}

- (void)dealloc;
/* override */
- (commonInfo *)drawToyWin:(NSString *)fileName type:(int)type
	map:(unsigned char **)map err:(int *)err;
- (void)makeComment:(commonInfo *)cinf;

@end
