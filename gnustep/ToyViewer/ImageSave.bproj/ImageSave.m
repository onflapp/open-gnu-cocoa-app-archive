#import "ImageSave.h"
#import <Foundation/NSData.h>
#import <Foundation/NSUserDefaults.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSEPSImageRep.h>
#import <AppKit/NSBitmapImageRep.h>
#import <stdio.h>
#import <libc.h>
#import <string.h>
#import <sys/file.h>
#import "TVSavePanel.h"
#import "../TVController.h"
#import "../ToyView.h"
#import "../ToyWin.h"
#import "../ToyWinEPS.h"
#import "../ToyWindow.h"
#import "../ColorMap.h"
#import "../BundleLoader.h"
#import "../AlertShower.h"
#import "../strfunc.h"
#import "../common.h"
#import "../Resize.bproj/Thumbnailer.h"
#import "../RecentFileList.h"
#import "save.h"

#define lastSaveDir	@"lastSaveDirectory"

static NSString *saveDir = nil;
static NSString *iconDir = nil;

@implementation ImageSave

+ (void)initialize
{
	static BOOL	nomore = NO;
	BOOL	isdir = NO;
	NSUserDefaults *usrdef;
	NSFileManager *manager;

	if (nomore)
		return;
	nomore = YES;
	usrdef = [NSUserDefaults standardUserDefaults];
	manager = [NSFileManager defaultManager];
	saveDir = [[usrdef stringForKey: lastSaveDir] retain];
	if (!saveDir
	|| ![manager fileExistsAtPath:saveDir isDirectory:&isdir]
	|| !isdir)
		saveDir = NSHomeDirectory();
}

+ (void)setSaveDirectory:(NSString *)dir
{
	NSUserDefaults *usrdef;

	if ([saveDir isEqualToString: dir])
		return;
	[saveDir release];
	saveDir = [dir retain];
	usrdef = [NSUserDefaults standardUserDefaults];
	[usrdef setObject:saveDir forKey:lastSaveDir];
}

+ (NSString *)saveDirectory { return saveDir; }

+ (void)setIconDirectory:(NSString *)dir
{
	[dir retain];
	[iconDir release];
	iconDir = dir;
}

- (void)setIconDirectory:(NSString *)dir
{
	NSString *path;
	path = [[toyWin filename] stringByDeletingLastPathComponent];
	if ([path isEqualToString: dir])
		dir = nil;
	[[self class] setIconDirectory: dir];
}

+ (NSString *)iconDirectory { return iconDir; }


/* Ordinary NSString operation cannot do ".../.dir" + ".tiff" as expected */

+ (NSString *)tmpPath:(NSString *)path ext:(NSString *)ex
{
	NSString *body = [path lastPathComponent];
	if ([body characterAtIndex:0] == (unichar)'.') {
		int n = [body length];
		NSString *tmp = [body substringWithRange:NSMakeRange(1, n-1)];
		return [NSString stringWithFormat:@"%@/.%@.%@",
			[path stringByDeletingLastPathComponent],
			[tmp stringByDeletingPathExtension], ex];
	}
	/* ordinary */
	return [[path stringByDeletingPathExtension]
		stringByAppendingPathExtension:ex];
}

+ (NSString *)tmpName:(NSString *)path ext:(NSString *)ex
{
	return [self tmpPath:[path lastPathComponent] ext:ex];
}


- (id)initWithWin:(id)aToyWin
{
	[super init];
	toyWin = aToyWin;
	toyView = [toyWin toyView];
	return self;
}

- (void)setRecentList:(id)obj {
	recentlist = obj;	// Refer only
}

- (void)setOpCtr:(id)obj {
	imageOpCtr = obj;	// Refer only
}

static NSString *extension(int itype)
{
	NSString *ex = nil;
	switch (itype) {
	case Type_eps: ex = @"eps";  break;
	case Type_bmp: ex = @"bmp";  break;
	case Type_gif: ex = @"gif";  break;
	case Type_ppm: ex = @"pnm";  break;
	case Type_jpg: ex = @"jpg";  break;
	case Type_xbm: ex = @"xbm";  break;
	case Type_jbg: ex = @"bie";  break;
	case Type_png: ex = @"png";  break;
	}
	return ex;
}

- (void)saveAsType:(int)itype	/* BMP, PPM, or JBIG */
{
	NSString *stmp;
	TVSavePanel *savePanel;
	commonInfo *cinf = [toyView commonInfo];
        if (cinf->cspace == CS_CMYK) {
		[WarnAlert runAlert:[toyWin filename] : Err_SAV_IMPL];
		return;
	}
	if (itype == Type_jbg && (cinf->bits > 2 || cinf->numcolors != 1)) {
		/* ignore alpha, ignore 2 bits gray. Because of EPS... */
		[WarnAlert runAlert:[toyWin filename] : Err_SAV_IMPL];
		return;
	}
	imagetype = itype;
	stmp = [ImageSave tmpName:[toyWin filename] ext:extension(itype)];
	[self retain];	// Self is released after savePanel activate it again.

	savePanel = (TVSavePanel *)[TVSavePanel savePanel];
	// new panel is returned.
	[savePanel beginSheetForDirectory:[[self class] saveDirectory]
		file:stmp modalForWindow:[toyWin window] modalDelegate:self
		didEndSelector:@selector(savePanelforPPMDidEnd:returnCode:contextInfo:)
		contextInfo:NULL];
}

- (void)savePanelforPPMDidEnd:(NSWindow *)sheet
	returnCode:(int)returnCode contextInfo:(void  *)contextInfo;
{
	FILE	*fp;
	NSString *sav;
	TVSavePanel *panel;
	commonInfo *cinf;
	unsigned char *map[MAXPLANE];
	int	err = 0;
	const char *ap;
	BOOL	makeicon;

	[self autorelease];
	if (returnCode != NSFileHandlingPanelOKButton) /* canceled */
		return;
	panel = (TVSavePanel *)sheet;
	sav = [[self class] tmpPath:[panel filename] ext:extension(imagetype)];
	if (sav == nil || [sav length] == 0)
		return;
	[self removeFile: sav];
	if ((fp = fopen([sav fileSystemRepresentation], "w")) == NULL) {
		[ErrAlert runAlert:sav : Err_SAVE];
		return;
	}
	makeicon = [panel withThumbnail];

	cinf = [toyView commonInfo];
	err = [toyWin getBitmap:map info: &cinf];
	if (!err) err = initGetPixel(cinf);
	if (err) goto EXIT;

	ap = [[theController resource] fileSystemRepresentation];
	resetPixel((refmap)map, 0);
	if (imagetype == Type_ppm) {
		err = ppmwrite(fp, cinf, map);
	}else if (imagetype == Type_jbg) {
		err = jbigwrite(fp, cinf, map[0], ap);
		fp = NULL;
	}else { /* bmp only */
		ColorMap *colormap = [[ColorMap alloc] init];
		(void)[self getPalette:colormap
			info:cinf map:(refmap)map needAlpha:NO err:&err];
		resetPixel((refmap)map, 0);
		err = bmpwrite(fp, cinf, ap, map);
		fp = NULL;
		[colormap release];	// shuold be released here
	}
	if (makeicon)
		[self makeNewIconTo:sav];

EXIT:
	if (fp) (void)fclose(fp);
	[toyWin freeTempBitmap];
	if (err) {
		[ErrAlert runAlert:sav : err];
		[[NSFileManager defaultManager]
			removeFileAtPath:sav handler:nil];
	}else {
		[[self class] setSaveDirectory:[panel directory]];
		[toyWin resetFilename: sav];
		[recentlist addNewFilepath: sav];
	}
}

- (void)saveAsEPS
{
	static int	ftype = Type_eps;
	TVSavePanel *savePanel;
	NSString *stmp = [ImageSave tmpName:[toyWin filename] ext:@"eps"];
	[self retain];	// Self is released after savePanel activate it again.

	savePanel = (TVSavePanel *)[TVSavePanel savePanel];
	// new panel is returned.
	[savePanel beginSheetForDirectory:[[self class] saveDirectory]
		file:stmp modalForWindow:[toyWin window] modalDelegate:self
		didEndSelector:@selector(savePanelforEPSDidEnd:returnCode:contextInfo:)
		contextInfo: &ftype];
}

- (void)saveAsPDF
{
	static int	ftype = Type_pdf;
	TVSavePanel *savePanel;
	NSString *stmp = [ImageSave tmpName:[toyWin filename] ext:@"pdf"];
	[self retain];	// Self is released after savePanel activate it again.

	savePanel = (TVSavePanel *)[TVSavePanel savePanel];
	// new panel is returned.
	[savePanel beginSheetForDirectory:[[self class] saveDirectory]
		file:stmp modalForWindow:[toyWin window] modalDelegate:self
		didEndSelector:@selector(savePanelforEPSDidEnd:returnCode:contextInfo:)
		contextInfo: &ftype];
}

- (void)savePanelforEPSDidEnd:(NSWindow *)sheet
	returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	NSData *stream;
	NSString *sav;
	TVSavePanel *panel;
	commonInfo *cinf;
	int	ftype, err = 0;

	[self autorelease];
	ftype = *(int *)contextInfo;
	if (returnCode != NSFileHandlingPanelOKButton) /* canceled */
		return;
	panel = (TVSavePanel *)sheet;
	sav = [[self class] tmpPath:[panel filename]
		ext: ((ftype == Type_eps) ? @"eps" : @"pdf")];
	if (sav == nil || [sav length] == 0)
		return;
	stream = (ftype == Type_eps)
		? [toyWin openEPSData] : [toyWin openPDFData];
	if (stream == nil) {
		err = Err_MEMORY;
		goto ErrEXIT;
	}
	[self removeFile: sav];
	if ([stream writeToFile:sav atomically:NO]) {
		if ([panel withThumbnail])
			[self makeNewIconTo:sav];
	}else
		err = Err_SAVE;
ErrEXIT:
	if (err) {
		[ErrAlert runAlert:sav : err];
		return;
	}
	[[self class] setSaveDirectory:[panel directory]];
	cinf = [toyView commonInfo];
	if (cinf->type == ftype)
		[toyWin resetFilename:sav]; 
	[recentlist addNewFilepath: sav];
}


- (void)makeNewIconTo:(id)sav
{
	const char *ap, *target;
	unsigned char *map[MAXPLANE];
	int n, err = 0;
	id sitem = nil;
	Class thumbnailer = [BundleLoader loadClass:b_Thumbnail];
	id aThumb = [[thumbnailer alloc] initWithToyWin: toyWin];
	commonInfo *info = [aThumb makeThumbnail:map];
	ap = [[theController resource] fileSystemRepresentation];
	if ([sav isKindOfClass:[NSArray class]]) {
	    for (n = [sav count]-1; n >= 0; n--) {
		sitem = [sav objectAtIndex:n];
		target = [sitem fileSystemRepresentation];
		err = customIconWrite(info, map, ap, target);
		if (err) break;
	    }
	}else {
		target = [(sitem = sav) fileSystemRepresentation];
		err = customIconWrite(info, map, ap, target);
	}

	if (err)
		[WarnAlert runAlert:sitem : err];
	[aThumb release];
}

- (void)attachCustomIcon	/* Attach Custom Icon Only */
{
	NSOpenPanel *openPanel;
	NSString *dir, *name, *path, *fn;
	commonInfo *cinf = [toyView commonInfo];
	name = [toyWin filename];
        if (cinf->cspace == CS_CMYK) {
		[WarnAlert runAlert:name : Err_SAV_IMPL];
		return;
	}
	[self retain];
	openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setCanChooseFiles:YES];
	[openPanel setAllowsMultipleSelection:YES];
	[openPanel setTreatsFilePackagesAsDirectories: NO];

	dir = [[self class] iconDirectory];
	path = [name stringByDeletingLastPathComponent];
	if (dir == nil || [dir isEqualToString: path]) {
		dir = path;
		fn = [name lastPathComponent];
	}else
		fn = nil;
	[openPanel beginSheetForDirectory:dir file:fn types:nil
		modalForWindow:[toyWin window] modalDelegate:self
		didEndSelector:@selector(
			openPanelforIconDidEnd:returnCode:contextInfo:)
		contextInfo:NULL];
}

- (void)openPanelforIconDidEnd:(NSOpenPanel *)sheet
	returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
	[self autorelease];
	if (returnCode != NSFileHandlingPanelOKButton) /* canceled */
		return;
	[self makeNewIconTo:[sheet filenames]];
	[self setIconDirectory: [sheet directory]];
}

+ (void)removeCustomIcon	/* Remove Custom Icon Only */
{
	int n, err;
	NSArray *narry;
	id target;
	const char *ap;
	NSOpenPanel *openPanel;

	[ToyWindow setZoomedWindow: nil];  // Cancel Zoom Mode
	ap = [[theController resource] fileSystemRepresentation];
	openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setCanChooseFiles:YES];
	[openPanel setAllowsMultipleSelection:YES];
	[openPanel setTreatsFilePackagesAsDirectories: NO];
	if ([openPanel runModalForDirectory:[self iconDirectory]
		file:nil types:nil] != NSOKButton)
		return;
	narry = [openPanel filenames];
	for (n = [narry count] - 1; n >= 0; n--) {
		target = [narry objectAtIndex:n];
		err = customIconRemove(ap, [target fileSystemRepresentation]);
		if (err) {
			[WarnAlert runAlert:target : err];
			break;
		}
	}
	[[self class] setIconDirectory: [openPanel directory]];
}

- (void)removeFile:(NSString *)fname
{
	NSFileManager *manager = [NSFileManager defaultManager];
	if ([manager isWritableFileAtPath:fname])
		[manager removeFileAtPath:fname handler:nil];
}

@end
