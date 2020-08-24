#import "TVController.h"
#import <AppKit/NSOpenPanel.h>
#import <AppKit/NSApplication.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSPasteboard.h>
#import <Foundation/NSData.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSPathUtilities.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSFileManager.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
//#import <libc.h>
#import "NSStringAppended.h"
#import "BundleLoader.h"
#import "PrefControl.h"
#import "ImageOpCtr.h"
#import "ToyWin.h"
#import "ToyWinPPM.h"
//#import "ToyWinEPS.h" //GNUstep
//#import "ToyWinPDF.h"
#import "ToyWinPict.h"
#import "ToyWinPCD.h"
#import "ToyWinGIF.h"
#import "ToyWindow.h"
#import "DirList.h"
#import "ADController.h"
#import "ColorSpaceCtrl.h"
#import "AlertShower.h"
#import "WaitMessageCtr.h"
#import "RecentFileList.h"
#import "strfunc.h"
#import "Exttab.h"
#import "common.h"

#define RecentFiles	@"RecentFiles"

TVController *theController = NULL;
AlertShower *ErrAlert, *WarnAlert;

static NSString *resourcePath = nil;

@implementation TVController


#define  typeNumber	24
/* ToyViewer treats these extensions as pre-defined */
static NSString *fileType[typeNumber + 1] = {
	@"tiff", @"tif", @"TIFF", @"TIF",
	@"eps", @"EPS",
	@"gif", @"GIF",
	@"bmp", @"BMP", @"dib", @"DIB",
	@"ppm", @"pgm", @"pbm", @"pnm",
	@"pcd", @"PCD",
	@"pict", @"PICT", @"pic", @"PIC",
	@"pdf", @"PDF",
	NULL };
static const char fileTypeID[typeNumber] = {
	Type_tiff, Type_tiff, Type_TIFF, Type_TIFF,
	Type_eps, Type_eps,	/* ".EPS" is recognised */
	Type_gif, Type_gif,
	Type_bmp, Type_bmp, Type_bmp, Type_bmp,	/* ".BMP" is recognised */
	Type_ppm, Type_ppm, Type_ppm, Type_ppm,
	Type_pcd, Type_pcd,
	Type_pict, Type_pict, Type_pict, Type_pict,
	Type_pdf, Type_pdf
};


static NSString **ftypeBuf = NULL;
static short *ftypeID;
static int ftypeNum;
static NSArray *fileTypeArray;
static id openPanel = nil;
static NSString *odir = nil;	/* Last Opened Directory */
static Exttab *extTable;
static NSBundle *TVbundle = nil;

+ (void)setOpenedDir:(NSString *)newdir
{
	[newdir retain];
	[odir release];
	odir = newdir;
}

+ (NSString *)openedDir { return odir; }

/* If file has no extension, this func. recognize its file type */
static int discriminate(const char *fn)
{
	int maybe = Type_none;
	int cc;
	FILE *fp;

	if ((fp = fopen(fn, "r")) == NULL)
		return Type_none;
	switch (cc = getc(fp)) {
	case 0x00: {
		int	i;
		for (i = 1; i < 512; i++)
			if ((cc = getc(fp)) != 0) break;
		if (i == 3 && cc == 0x0c)
			maybe = Type_jp2;
		else if (i >= 512)
			maybe = Type_pict;
	    }
	    break;
	case 0x0a: maybe = Type_pcx;  break;
	case '%':
		maybe = ((cc = getc(fp)) == 'P' || cc == 'p')
			? Type_pdf : Type_eps;
		break;
	case 'B':  maybe = Type_BMP;  break;
	case 'G':  maybe = Type_gif;  break;
	case 'I':  maybe = Type_TIFF;  break;
	case 'M':  maybe = Type_mag;  break;
	case 'P':  maybe = Type_ppm;  break;
	case 'Y':  maybe = Type_ras;  break;
	case 0x89:  maybe = Type_png;  break;
	case 0xff:
		cc = getc(fp);
		if (cc == 0xd8)
			maybe = Type_jpg;
		else if (cc == 0x4f)
			maybe = Type_jpc;
		break;
	default: break;
	}
	fclose(fp);
	return maybe;
}

/* Local Method */
- (void)startSelf
{
	int i, j, w, n;
	char	**q;
	NSString *tabpath, *home;
	NSArray *types = [NSImage imageFileTypes];

	if (theController)
		return;

	theController = self;
	TVbundle = [NSBundle mainBundle];
	home = NSHomeDirectory();
	srandom(getpid());
#ifdef Legacy
	resourcePath = [[[TVbundle bundlePath]
		stringByAppendingPathComponent:@"Resources"] retain];
#else
	resourcePath = [[[TVbundle bundlePath]
		stringByAppendingPathComponent:@"Contents/Resources"] retain];
#endif
        [Exttab setHome:home andPath:resourcePath];
	extTable = [[Exttab alloc] init];
	tabpath = [TVbundle pathForResource: toyviewerTAB ofType: @""];
	[extTable readExtData: tabpath];
	[extTable readExtData:
		[home stringByAppendingPathComponent:toyviewerRC]];
#ifdef __ARCHITECTURE__
	[extTable readExtData:
		[NSString stringWithFormat:@"%@/Library/ToyViewer/rc.%s",
			home, __ARCHITECTURE__]];
#else
	[extTable readExtData:
		[NSString stringWithFormat:@"%@/Library/ToyViewer/rc.ppc", home]];
#endif
	n = [extTable entry] + [types count] + typeNumber + 1;
	ftypeBuf = (NSString **)malloc(sizeof(NSString *) * n);
	ftypeID = (short *)malloc(sizeof(short) * n);
	i = 0;
	if ((q = [extTable table]) != NULL)
		for (j = 0; q[j]; j++) {
		    ftypeBuf[i] = [[NSString stringWithCStringInFS:q[j]] retain];
		    ftypeID[i++] = Type_user;
		}
	for (j = 0; fileType[j]; j++) {
		ftypeBuf[i] = fileType[j];
		ftypeID[i++] = fileTypeID[j];
	}
	[self registerFilterServiceTypes:ftypeBuf withID:ftypeID num:i];

	w = [types count];
	for (j = 0; j < w; j++) {
		ftypeBuf[i] = [types objectAtIndex: j];
		ftypeID[i++] = Type_other;
	}
        fileTypeArray = [[NSArray alloc] initWithObjects: ftypeBuf count: i];
        ftypeBuf[ftypeNum = i] = NULL;
	[DirList setExtList: fileTypeArray];

	[self prepareServices];
}

/* Local Method */
- (void)openRecentFile:(NSString *)str
{
	NSFileManager *manager = [NSFileManager defaultManager];
	BOOL isdir = NO;
	if (![manager fileExistsAtPath:str isDirectory:&isdir]) {
		[ErrAlert runAlert:str : Err_NOFILE];
		return;
	}
	if (![self openFileOrDirectory:str])
		[ErrAlert runAlert:str : Err_OPEN];
}

/* Local Method */
- (void)setupRecentMenu
{
	NSUserDefaults *usrdef = [NSUserDefaults standardUserDefaults];
	NSArray *ar = [usrdef arrayForKey: RecentFiles];
	recentlist = [RecentFileList sharedList];
	[recentlist setMaxFiles:[[PrefControl sharedPref] recentFileNumber]];
	[recentlist setPropertyList: ar];
	[recentlist setTarget:self andAction:@selector(openRecentFile:)];
	[recentMenu setAutoenablesItems:NO];
	[recentlist makeSubMenuOf: recentMenu];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	[self startSelf];
	[self setupRecentMenu];
}

// - (void)applicationWillFinishLaunching:(NSNotification *)notification
// {
//	NSLog(@"@ applicationWillFinishLaunching");
// }

- (void)applicationWillTerminate:(NSNotification *)notification
{
	NSUserDefaults *usrdef = [NSUserDefaults standardUserDefaults];
	[imageOpCtr saveData];
	if (recentlist)
		[usrdef setObject:[recentlist array] forKey: RecentFiles];
	[usrdef synchronize];
}

- (NSString *)resource
{
	return resourcePath;
}

- (int)getFTypeID:(NSString *)aType
{
	int	i;

	if (!aType)
		return Type_none;
	for (i = 0; i < ftypeNum; i++)
		if ([aType isEqualToString: ftypeBuf[i]])
			return ftypeID[i];
	return Type_none;
}


/* Local Method */
- (id)makeNewWinFromFile:(NSString *)fn :(NSString *)aType
		type:(int *)ftype display:(BOOL)display
	/* Return Value:  nil: Error,  id: New ToyWin */
{
	id twtmp = nil;
	int itype = Type_none;
	const char *key = NULL;

	itype = [self getFTypeID:aType];
	if (itype == Type_none) { /* Unknown Extension */
		if ((itype = discriminate([fn fileSystemRepresentation])) == Type_none)
			return nil;
		key = NULL;
	}else
		key = [aType UTF8String];

	if (viaPipe(itype)) { /* Type_user and ... */
		if (key == NULL)
			switch (itype) {
			case Type_pcx:	key = "pcx"; break;
			case Type_mag:	key = "mag"; break;
			case Type_jpg:	key = "jpg"; break;
			case Type_xbm:	key = "xbm"; break;
			case Type_jbg:	key = "bie"; break;
			case Type_ras:	key = "ras"; break;
			case Type_png:	key = "png"; break;
                        case Type_jp2:	key = "jp2"; break;
                        case Type_jpc:	key = "jpc"; break;
                        case Type_BMP:	key = "bmp"; break;
			}
		twtmp = display ? [[ToyWinPPM alloc] init:nil by:0]
			: [[ToyWinPPM alloc] initMapOnly];
		[twtmp setExecList:
			[extTable execListAlloc: key with: fn] ext: key]; 
	}else if (itype == Type_gif) {
		twtmp = display ? [[ToyWinGIF alloc] init:nil by:0]
			: [[ToyWinGIF alloc] initMapOnly];
	}else if (itype == Type_pcd) {
		twtmp = display ? [[ToyWinPCD alloc] init:nil by:0]
			: [[ToyWinPCD alloc] initMapOnly];
		[twtmp setting];
	}else {
		switch (itype) {
		case Type_bmp:
		  //twtmp = [ToyWinBMP alloc]; break;
		  //		    twtmp = [ToyWin alloc]; 
		  NSLog(@"TODO");
		  break;
		  //		case Type_eps:
		  //			twtmp = [ToyWinEPS alloc];
		  //			display = YES;
		  
		case Type_ppm:
			twtmp = [ToyWinPPM alloc]; break;
		case Type_pict:
			twtmp = [ToyWinPict alloc];
			break;
		case Type_pdf:
		  //twtmp = [ToyWinPDF alloc];
			break;
		case Type_tiff:
		case Type_TIFF:
		case Type_other:
		default:
			twtmp = [ToyWin alloc];
			display = YES;
			break;
		}
		if (display) [twtmp init:nil by:0];
		else [twtmp initMapOnly];
	}
	*ftype = itype;
	return twtmp;	// return New ToyWin
}

- (id)drawFile: (NSString *)fn
	/* Return Value:  nil: Error,  id: New ToyWin */
{
	unsigned char *map[MAXPLANE];
	id newtw;
	commonInfo *cinf;
	int itype, err = 0;

	newtw = [self makeNewWinFromFile: fn
		:[fn pathExtension] type:&itype display:YES];
	if (!newtw)
		return nil;
	cinf = [newtw drawToyWin:fn type:itype map:map err:&err];
	if (cinf == NULL && err) {
		if (err > 0) [ErrAlert runAlert:fn : err];
		[newtw release];
		return nil;
	}
	[self newWindow:newtw];
	return newtw;
}

/* Local Method */
/* This method is NOT used for EPS and TIFF */
- (NSBitmapImageRep *)imageFromFile: (NSString *)fn :(NSString *)aType map:(unsigned char **)map
{
	id	newtw;
	commonInfo *cinf;
	NSBitmapImageRep *img;
	NSString *cs;
	int	itype, err = 0, spp;

	map[0] = NULL;
	newtw = [self makeNewWinFromFile:fn : aType type:&itype display:NO];
	if (!newtw)
		return nil;
        cinf = [newtw drawToyWin:fn type:itype map:map err:&err];
	if (cinf == NULL && err) {
		if (err > 0) [ErrAlert runAlert:fn : err];
		[newtw release];
		return nil;
	}

	cs = [ColorSpaceCtrl colorSpaceName: cinf->cspace];
	spp = cinf->numcolors;
	if (cinf->alpha) spp++;
	img = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:map
		pixelsWide:cinf->width pixelsHigh:cinf->height
		bitsPerSample:cinf->bits samplesPerPixel:spp
		hasAlpha:cinf->alpha isPlanar:YES colorSpaceName:cs
		bytesPerRow:cinf->xbytes bitsPerPixel:cinf->bits];

	[newtw release];
	if (cinf->palette)
		free((void *)cinf->palette);
	free((void *)cinf);
		/* An instance of ToyWin initialized by "initMapOnly"
			does not have instances of ToyView in it.
			So, "cinf" must be freed here. */
	return img;
}

/* Get stream from file without actual window.
   This method is used to provide Pasteboard-Services.
 */
- (NSData *)openDataFromFile:(NSString *)fn
{
	unsigned char *map[MAXPLANE];
	NSBitmapImageRep *img = nil;
	NSData *pbStream = nil;
	int	itype, err;
	NSString *atype;

	atype = [fn pathExtension];
	if ([atype length] == 0)
	  return nil; /* No Extension */
	itype = [self getFTypeID:atype];
	/*	if (itype == Type_eps) {
		ToyWinEPS *tweps = [[ToyWinEPS alloc] initMapOnly];
		pbStream = [tweps openDataFromFile:fn err:&err];
		[tweps release];
		if (pbStream == nil && err > 0) {
			[ErrAlert runAlert:fn : err];
			return nil;
		}
		return pbStream;
		}*/

	if (itype == Type_tiff || itype == Type_TIFF
	|| itype == Type_pdf || itype == Type_gif) {
		pbStream = [NSData dataWithContentsOfFile:fn];
		return pbStream;
	}

	map[0] = NULL;
	img = [self imageFromFile: fn : atype map: map];
//	NSLog(@"bitmap image created\n");
	if (img) {
		pbStream = [img TIFFRepresentation];
		[img release];
	}
	if (map[0])
		free((void *)map[0]);
//	NSLog(@"stream image created\n");
	return pbStream;
}

/* Local Method */
- (void)setOpenPanelForDirectory:(BOOL)flag
{
	// if (!odir)
	//	odir = [NSHomeDirectory() copyWithZone:[self zone]];
	// Because value of NSDefaultOpenDirectory is automatically set.
	if (openPanel == nil)
		openPanel = [[NSOpenPanel openPanel] retain];
	[openPanel setCanChooseDirectories:flag];
	[openPanel setCanChooseFiles: !flag];	/// R.B 3.13.99
	[openPanel setAllowsMultipleSelection:!flag];
	[openPanel setTreatsFilePackagesAsDirectories: YES];
}

- (void)openFile:(id)sender
{
	NSArray *files;
	NSString *s;
	NSEnumerator	*en;

	[ToyWindow setZoomedWindow: nil];  // Cancel Zoom Mode
	[self setOpenPanelForDirectory: NO];
	if ([openPanel runModalForDirectory:[[self class] openedDir]
			file: nil types: fileTypeArray] != NSOKButton)
		return;

	files = [openPanel filenames];
	[[self class] setOpenedDir: [openPanel directory]];
	en = [files objectEnumerator];
	while ((s = [en nextObject]) != nil) {
		if ([self winOpened:s makeKey:YES] == nil) {
			id pool = [[NSAutoreleasePool alloc] init];
			if ([self drawFile: s] != nil)
				[recentlist addNewFilepath: s];
			[pool release];
		}
	}
}

#define  AutoThreshold	2

/* Local Method */
- openDirectory: (NSString *)dir
{
	int	n, i;
	id	dirlist;

	dirlist = [[DirList alloc] init];
	[dirlist setIgnoreDottedFiles:
		[[PrefControl sharedPref] ignoreDottedFiles]];
	n = [dirlist getDirList: dir];
	if (n <= 0) {
		[ErrAlert runAlert:dir : Err_NOFILE];
		[dirlist release];
	}else if (n < AutoThreshold) {
		for (i = 0; i < n; i++) {
			NSString *str, *cmp;
			cmp = [dirlist filenameAt:i];
			str = [dir newStringByAppendingPathComponent:cmp];
			if ([self winOpened:str makeKey:YES] == nil)
				[self drawFile:str];
		}
		[dirlist release];
	}else { /* Auto Display */
		id ad = [[BundleLoader loadClass:b_ADController] alloc];
		[ad init:self dir:dir with:dirlist];
	}

	return self;
}

- (void)autoDisplay:(id)sender
{
	NSString *dir;

	[ToyWindow setZoomedWindow: nil];  // Cancel Zoom Mode
	[self setOpenPanelForDirectory: YES];
	if (![openPanel runModalForDirectory:nil file:nil])
		return;

	dir = [[openPanel filenames] objectAtIndex: 0];
	[[self class] setOpenedDir: [openPanel directory]];
	[recentlist addNewFilepath: dir];
	[self openDirectory: dir]; 
}


/* To receive services, implement these methods (delegate) */
- (BOOL)readSelectionFromPasteboard:(NSPasteboard *)pb
{
	NSArray	*pbtypes;
	NSString *fn, *typ = nil;
	NSData	*st;
	id	twtmp = nil;
	char *ext;
	int	i, count, err;
	static int	untitledCount = 0;

	ext = NULL;
	pbtypes = [pb types];
	count = [pbtypes count];
	for (i = 0; i < count; i++) {
		typ = [pbtypes objectAtIndex: i];
		if ([typ isEqualToString: NSTIFFPboardType]) {
			twtmp = [[ToyWin alloc] init:nil by:FromPasteBoard];
			ext = "tiff";
			break;
		}
		/*if ([typ isEqualToString: NSPDFPboardType]) {
			twtmp = [[ToyWinPDF alloc] init:nil by:FromPasteBoard];
			ext = "pdf";
			break;
			}*/ //GNUstep
		if ([typ isEqualToString: NSPICTPboardType]) {
			twtmp = [[ToyWinPict alloc] init:nil by:FromPasteBoard];
			ext = "pict";
			break;
		}
		if ([typ isEqualToString: NSFilenamesPboardType]) {
			NSString *s = getStringFromPB(pb, typ);
			BOOL res = ([self drawFile: s] != nil);
			if (res)
				[recentlist addNewFilepath: s];
			return res;
		}
		// Because Mac OS X 10.1.x does not support EPS drawing,
		// the priority of EPS is lower.
		/*		if ([typ isEqualToString: NSPostScriptPboardType]) {
			twtmp = [[ToyWinEPS alloc] init:nil by:FromPasteBoard];
			ext = "eps";
			break;
			}*/
	}
	if (ext == NULL) {
		NSBeep();
		return YES;
	}
	st = [pb dataForType:typ];

	fn = [NSString stringWithFormat:
		@"%s/Untitled%d.%s", getenv("HOME"), ++untitledCount, ext];
	err = [twtmp drawFromFile:fn or:st];
	if (err == 0)
		[self newWindow:twtmp];
	else {
		if (err > 0)
			[ErrAlert runAlert:fn : err];
		[twtmp release];
	}
	return YES;
}

- (void)openPasteBoard:(id)sender
{
	NSPasteboard  *pb = [NSPasteboard generalPasteboard];  // don't free it
	[self readSelectionFromPasteboard:pb];
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)fn
{
	[recentlist addNewFilepath: fn];
	return [self openFileOrDirectory: fn];
}

- (BOOL)openFileOrDirectory:(NSString *)fn
{
	BOOL	isdir;
	id	res = nil;
	NSFileManager *manager;

	if (theController == nil)
		[self startSelf];
	manager = [NSFileManager defaultManager];
	isdir = NO;
	if (![manager fileExistsAtPath:fn isDirectory:&isdir])
		return NO;
	if (isdir) {
		if (![manager isExecutableFileAtPath:fn])
			return NO;
		res = [self openDirectory: fn];
	}else {
		if ([self winOpened:fn makeKey:YES] != nil)
			return YES;
		res = [self drawFile: fn];
	}
	return (res != nil);
}

- (void)addToRecentMenu:(NSString *)str
{
	NSFileManager *manager;
	BOOL isdir;

	if (str == nil || [str length] == 0)
		return;
	manager = [NSFileManager defaultManager];
	isdir = NO;
	if ([manager fileExistsAtPath:str isDirectory:&isdir])
		[recentlist addNewFilepath: str];
}

@end
