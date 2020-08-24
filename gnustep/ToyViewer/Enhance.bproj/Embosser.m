#import "Embosser.h"
#import <Foundation/NSBundle.h>	/* LocalizedString */
#import "../WaitMessageCtr.h"
#import "../common.h"
#import "../getpixel.h"

#define  DirectionKind	6

static void set_factor(int num, float fac, float bri, int ucn);
static void emboss_sub(int *pix, int totalw, int *totalv);
static void emboss_mono_sub(int *pix, int totalw, int *totalv);


@implementation Embosser

+ (int)opcode {
	return Emboss;
}

+ (NSString *)oprString {
	return NSLocalizedString(@"Emboss", Effects);
}

/* ignore clipping */
- (void)setupWith:(ToyView *)tv
{
	selected = NO;
}

- (BOOL)isMono {
	return (bright <= 0.005);
}

- (f_enhance)enhanceFunc {
	return [self isMono] ? emboss_mono_sub : emboss_sub;
}

#define  Tab3Num	4

- (t_weight)weightTabel:(int *)size
{
	static const char emboss3Tabs[Tab3Num][9] = {
	    {
		-2, -1,  0,
		-1,  0,  1,
		 0,  1,  2
	    },
	    {
		 0, -1, -2,
		 1,  0, -1,
		 2,  1,  0
	    },
	    {
		 0,  1,  2,
		-1,  0,  1,
		-2, -1,  0
	    },
	    {
		 2,  1,  0,
		 1,  0, -1,
		 0, -1, -2
	    }
	};
	static const char emboss5Tabs[][25] = {
	    {
		 0, -1, -1, -1,  0,
		-1, -1, -1, -1, -1,
		-1, -1,  0, -1, -1,
		-1, -1, -1, -1, -1,
		 0, -1, -1, -1,  0
	    },
	    {
		 0,  1,  1,  1,  0,
		 1,  1,  1,  1,  1,
		 1,  1,  0,  1,  1,
		 1,  1,  1,  1,  1,
		 0,  1,  1,  1,  0
	    }
	};

	if (embossDirection < Tab3Num) {
		*size = 1;
		return emboss3Tabs[embossDirection];
	}
	*size = 2;
	return emboss5Tabs[embossDirection - Tab3Num];
}


- (id)init
{
	[super init];
	embossDirection = 0;
	return self;
}

- (id)waitingMessage
{
	return [theWaitMsg messageDisplay:
		NSLocalizedString(@"Embossing...", Embossing)];
}

- (void)setFactor:(float)fval andBright:(float)bval
{
	factor = fval;
	bright = bval;
}

- (void)setEmbossDirection:(int)tag {
	embossDirection = tag;
}

- (void)prepareCommonValues:(int)num
{
	static const int uCenter[DirectionKind] = {
		0, 0, 0, 0, 1, -1 };
	set_factor(num, factor, bright, uCenter[embossDirection]);
}

- (BOOL)makeNewPlane:(unsigned char **)newmap with:(commonInfo *)newinf
{
	if (![super makeNewPlane:newmap with:newinf])
		return NO;
	if ([self isMono] && newinf->numcolors > 1) {
		size_t	w = newinf->width * newinf->height;
		newinf->numcolors = 1;	/* Mono */
		newinf->cspace = CS_White;
		newmap[0] = (unsigned char *)realloc(newmap[0], w);
		newmap[1] = NULL;
	}
	return YES;
}

@end


#define  MagicNumber	5.0

static int cnum;
static float strength, colness;
static int useCenter;

static void set_factor(int num, float fac, float bri, int ucn)
{
	cnum = num;
	strength = MagicNumber * fac;
	colness = bri;
	useCenter = ucn;
}

static void emboss_sub(int *pix, int totalw, int *totalv)
{
	int	n;
	double	val;

	// should be totalw > 0 always
	if (cnum == 1) {
		val = (double)totalv[0] / (double)totalw;
		if (useCenter)
			val = (val + useCenter * pix[0]) / 2.0;
		pix[0] = val * strength + 128 + (pix[0] - 128) * colness;
		return;
	}
	val = (double)Bright255(totalv[0], totalv[1], totalv[2]) / (double)totalw;
	if (useCenter) {
		int w = Bright255(pix[0], pix[1], pix[2]);
		val = (val + useCenter * w) / 2.0;
	}
	for (n = 0; n < cnum; n++)
		pix[n] = val * strength + 128 + (pix[n] - 128) * colness;
}

static void emboss_mono_sub(int *pix, int totalw, int *totalv)
{
	int	n;
	double	val;

	// should be totalw > 0 always
	if (cnum == 1) {
		val = (double)totalv[0] / (double)totalw;
		if (useCenter)
			val = (val + useCenter * pix[0]) / 2.0;
		pix[0] = val * strength + 128;
		return;
	}
	val = (double)Bright255(totalv[0], totalv[1], totalv[2]) / (double)totalw;
	if (useCenter) {
		int w = Bright255(pix[0], pix[1], pix[2]);
		val = (val + useCenter * w) / 2.0;
	}
	for (n = 0; n < cnum; n++)
		pix[n] = val * strength + 128;
}
