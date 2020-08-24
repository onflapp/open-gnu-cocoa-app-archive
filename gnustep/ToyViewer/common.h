/*
	common.h	image independent information
*/

#ifndef _COMMON_h_
#define _COMMON_h_

#include <stdio.h>

enum {
	Err_OPEN	= 1,
	Err_FORMAT,
	Err_MEMORY,
	Err_SHORT,
	Err_ILLG,
	Err_IMPLEMENT,
	Err_SAVE,
	Err_SAV_IMPL,
	Err_EPS_IMPL,
	Err_EPS_ONLY,
	Err_PDF_IMPL,
	Err_PDF_ONLY,
	Err_EPS_PDF_IMPL,
	Err_EPS_PDF_ONLY,
	Err_OPR_IMPL,
	Err_NOFILE,
	Err_FLT_EXEC,
	Err_ACCESS
};

enum {
	Type_none	= -1,
	Type_other	= 0,	/* Filter service */
	Type_tiff	= 1,
	Type_eps	= 2,
	Type_bmp	= 3,
	Type_gif	= 4,
	Type_ppm	= 5,
	Type_pcd	= 6,
	Type_pict	= 7,
	Type_pdf	= 8,
	Type_user	= 0x11,	/* User-specified pipe */
	Type_png	= 0x12,
	Type_pcx	= 0x13,
	Type_mag	= 0x14,
	Type_jpg	= 0x15,
	Type_xbm	= 0x16,
	Type_jbg	= 0x17,
	Type_ras	= 0x18,
	Type_jp2	= 0x19,	// JPEG2000
	Type_jpc	= 0x1a,	// JPEG2000
	Type_TIFF	= 0x21, /* unknown Suffix for TIFF */
	Type_EPS	= 0x22,			/* but, ".EPS" is OK */
	Type_BMP	= 0x33
};
#define  viaPipe(t)		((t) > 0 && (0x10 & (t)))
#define  unknownSuffix(t)	((t) > 0 && (0x20 & (t)))

#define  isAlphaOpaque(x)	((x) >= 255)
#define  isAlphaTransp(x)	((x) < 255)
#define  AlphaOpaque		255
#define  AlphaTransp		0
#define  Bright255(r, g, b)	(((r)*30 + (g)*59 + (b)*11 + 50) / 100)

#define  RED		0
#define  GREEN		1
#define  BLUE		2
#define  ALPHA		3
#define  FIXcount	256
#define  MAXPLANE	5

enum ns_colorspace {
	CS_White, CS_Black, CS_RGB, CS_CMYK, CS_Other
};

/* Operations */
enum {
	NoOperation	= 0,
	FromPasteBoard	= 1,
	Rotation,
	SmoothRotation,
	Horizontal,
	Vertical,
	Clip,
	Negative,
	NewBitmap,
	ResizeEPS,
	SmoothResize,
	SimpleResize,
	Monochrome,
	BiLevel,
	Brightness,
	ColorTone,
	Reduction,
	HalfToning,
	Dithering,
	ColorChange,
	Enhance,
	Blur,
	Emboss,
	Contour,
	RandomPttn,
	Mosaic,
	SoftFrame,
	Posterize,
	CutDown,
	CMYKtoRGB
};

#define  MAXWidth	4096	/* MAX width that ToyViewer can display */
#define  MAX_COMMENT	256
#define	 MAXFILENAMELEN	512

typedef unsigned char	paltype[3];
typedef const unsigned char *const *refmap;

typedef struct {
	int	width, height;
	short	xbytes;		/* (number of bytes)/line */
	short	palsteps;	/* colors of palette */
	unsigned char	type;	/* Type_??? */
	unsigned char	bits;
	unsigned char	pixbits;	/* bits/pixel (mesh) */
	unsigned char	numcolors;	/* color elements without alpha */
	BOOL	isplanar, alpha;
        enum ns_colorspace cspace;
	paltype	*palette;
	unsigned char	memo[MAX_COMMENT];
} commonInfo;
/* If ( commonInfo.alpha == YES && commonInfo.palette != NULL) then
   the image has one transparent entry in the palette as GIF.
   The index of transparence should be the last of the palette.
 */
/* Rule for "memo" string:
    memo  :=  Dim [Kind] Attr{[,] Attr} : COMMENT
	Dim	Ex. "560 x 300" or "560x300"
	Kind	Ex. "jpg", "EPS", "GIF87a"
	Attr	Ex. "16colors", "gray", "alpha", ...
    Don't use ':' in Dim ,Kind, or Attr.
    Format of comments in pnm, pxo, or pao:
	[Attr{[,] Attr}] : COMMENT
*/

#endif /* _COMMON_h_ */
