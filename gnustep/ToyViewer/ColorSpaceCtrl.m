#import  <AppKit/NSGraphics.h>
#import  "ColorSpaceCtrl.h"
#import  "common.h"

#define  TABLESIZE	10

struct cs_entry{
	NSString		*csname;
	enum ns_colorspace	cspace;
};

static struct cs_entry	table[TABLESIZE];

@implementation ColorSpaceCtrl

+ (void)initialize
{
	table[0].csname = NSCalibratedWhiteColorSpace;	/* 1.0 == white */
	table[0].cspace = CS_White;
	table[1].csname = NSCalibratedBlackColorSpace;	/* 1.0 == black */
	table[1].cspace = CS_Black;
	table[2].csname = NSCalibratedRGBColorSpace;
	table[2].cspace = CS_RGB;
	table[3].csname = NSDeviceWhiteColorSpace;	/* 1.0 == white */
	table[3].cspace = CS_White;
	table[4].csname = NSDeviceBlackColorSpace;	/* 1.0 == black */
	table[4].cspace = CS_Black;
	table[5].csname = NSDeviceRGBColorSpace;
	table[5].cspace = CS_RGB;
	table[6].csname = NSDeviceCMYKColorSpace;
	table[6].cspace = CS_CMYK;
	table[7].csname = NSNamedColorSpace;	/* Used for "catalog" colors */
	table[7].cspace = CS_Other;
	table[8].csname = NSCustomColorSpace;
			/* Used to indicate a custom gstate in images */
	table[8].cspace = CS_Other;
	table[9].csname = nil;
	table[9].cspace = CS_Other;
        return;
}

+ (enum ns_colorspace)colorSpaceID:(NSString *)name
{
	int	i;

	for (i = 0; table[i].csname; i++)
		if (table[i].csname == name)
			return table[i].cspace;
	for (i = 0; table[i].csname; i++)
		if ([name isEqualToString: table[i].csname])
			return table[i].cspace;
	return CS_Other;
}

+ (NSString *)colorSpaceName:(enum ns_colorspace)csid
{
	int	i;

	for (i = 0; table[i].csname; i++)
		if (table[i].cspace == csid)
			return table[i].csname;
	return CS_White;
}

@end
