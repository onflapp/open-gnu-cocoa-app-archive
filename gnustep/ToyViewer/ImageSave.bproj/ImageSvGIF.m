//
//  ImageSvGIF.m
//  ToyViewer
//
//  Created by ogihara on Sun Apr 23 2001.
//  Copyright (c) 2001 OGIHARA Takeshi. All rights reserved.
//

#import "ImageSave.h"
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSFileManager.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSBitmapImageRep.h>
#import <stdio.h>
#import <libc.h>
#import <string.h>
#import "../TVController.h"
#import "../ImageOpCtr.h"
#import "../ToyView.h"
#import "../ToyWin.h"
#import "../ColorMap.h"
#import "../AlertShower.h"
#import "../strfunc.h"
#import "../common.h"
#import "../RecentFileList.h"
#import "save.h"
#import "GifSavePanel.h"

#define  MANY_COLORS	(-1)	/* must be < 0 */
#define  PXO2GIF	@"pxo2gif"
static int hasPXO2GIF = -1;

@implementation ImageSave (SaveGIF)

- (int)getPalette:(ColorMap *)colormap info:(commonInfo *)cinf
	map:(refmap)map needAlpha:(BOOL)alflag err:(int *)code
{
	int cnum, err;
	BOOL hasalpha;

	err = 0;
	if (cinf->palette != NULL) {
		if ([colormap mallocForPaletteColor] == nil) {
			err = Err_MEMORY;
			goto EXIT;
		}
		cnum = [colormap regPalColorWithAlpha: alflag];
		if (cnum > FIXcount)
			err = MANY_COLORS;
		goto EXIT;
	}

	if ([colormap mallocForFullColor] == nil) {
		err = Err_MEMORY;
		goto EXIT;
	}
	cnum = alflag
		? [colormap getAllColor:map limit:FIXcount alpha:&hasalpha]
		: [colormap getAllColor:map limit:FIXcount];
	if (hasalpha) ++cnum;
	if (cnum > FIXcount)
		err = MANY_COLORS;
	else {
		(void)[colormap getNormalmap: &cnum];
		cinf->palette = [colormap getPalette];
		cinf->palsteps = cnum;
	}
EXIT:
	if (err) {
		*code = err;
		return 0;
	}
	return cinf->palsteps;
}

/* Local Method */
- (BOOL)checkPXO2GIF
{
	NSString *path, *title, *text;

	if (hasPXO2GIF < 0) {
	    path = [[theController resource] stringByAppendingPathComponent:PXO2GIF];
	    hasPXO2GIF = [[NSFileManager defaultManager]
			fileExistsAtPath: path] ? 1 : 0;
	}
	if (hasPXO2GIF == 1)
		return YES;
	title = NSLocalizedString(@"No GIF Filter", NO_GIF_Filter);
	text = NSLocalizedString(@"Filter pxo2gif does not exist", NO_PXO2GIF);
	(void)NSRunAlertPanel(title, text, nil, nil, nil);
	return NO;
}

- (void)saveAsGif
{
	GifSavePanel *savePanel;
	NSString *stmp;
	commonInfo *cinf;

	if ([self checkPXO2GIF] == NO)
		return;
	cinf = [toyView commonInfo];
        if (cinf->cspace == CS_CMYK) {
		[WarnAlert runAlert:[toyWin filename] : Err_SAV_IMPL];
		return;
	}
	[self retain];	// Self is released after savePanel activate it again.

	savePanel = (GifSavePanel *)[GifSavePanel savePanel];
	// new panel is returned.

	stmp = [[self class] tmpName:[toyWin filename] ext:@"gif"];
	[savePanel beginSheetForDirectory:[[self class] saveDirectory]
		file:stmp modalForWindow:[toyWin window] modalDelegate:self
		didEndSelector:@selector(savePanelforGIFDidEnd:returnCode:contextInfo:)
		contextInfo:NULL];
}

- (void)savePanelforGIFDidEnd:(NSWindow *)sheet
	returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
	if (returnCode != NSFileHandlingPanelOKButton) { /* canceled */
		[self autorelease];
		return;
	}
	[sheet retain];
	[self performSelector:@selector(doSaveAsGIF:)
			withObject:sheet afterDelay: 5 / 1000.0];
	/* Sheet is closed here */
}

- (void)doSaveAsGIF:(NSWindow *)sheet
{
	NSString *sav;
	GifSavePanel *panel;
	commonInfo *cinf;
	ColorMap *colormap = nil;
	unsigned char *map[MAXPLANE];
	int	cnum, err;
	static BOOL	interl;

	[self autorelease];
	[sheet autorelease];
	panel = (GifSavePanel *)sheet;
	sav = [[self class] tmpPath:[panel filename] ext:@"gif"];
	if (sav == nil || [sav length] == 0)
		return;
	interl = [panel interlace];

	for ( ; ; ) { /* Watch Out!  This loop may repeat for Reduction. */
		NSString *ask, *cancel, *reduce;
		int r;

		cinf = [toyView commonInfo];
		if ((err = [toyWin getBitmap:map info: &cinf]) != 0)
			goto EXIT;
		if ((err = initGetPixel(cinf)) != 0)
			goto EXIT;

		if (colormap) [colormap release];	// should be released here.
		colormap = [[ColorMap alloc] init];
		cnum = [self getPalette:colormap
			info:cinf map:(refmap)map needAlpha:cinf->alpha err:&err];
		if (cnum != 0)
			break;

		if (err != MANY_COLORS)
			goto EXIT;
		ask = NSLocalizedString(@"Reduction Start", GIF_Reduction);
		cancel = NSLocalizedString(@"Cancel", Stop_SAVE);
		reduce = NSLocalizedString(@"Reduce", BMP_Reduce);
		r = NSRunAlertPanel(@"", ask, reduce, cancel, nil);
		if (r != NSOKButton) {
			err = 0;
			goto EXIT;
		}
		[toyWin freeTempBitmap];
		if (cinf->type == Type_eps || cinf->type == Type_pdf)
			[imageOpCtr newBitmap:self];
		[imageOpCtr reduce:self];
		toyWin = (ToyWin *)[theController keyWindow];
		toyView = [toyWin toyView];
		cinf = [toyView commonInfo];
	}

	[self removeFile: sav];
	if (hasPXO2GIF == 1) {
		FILE	*fp;
		int	transp;
		const char *ap;

		transp = (cinf->alpha && cinf->palette) ? cinf->palsteps : -1;
		if ((fp = fopen([sav fileSystemRepresentation], "w")) == NULL) {
			[ErrAlert runAlert:sav : Err_SAVE];
			[toyWin freeTempBitmap];
			return;	// Don't goto EXIT.
		}
		resetPixel((refmap)map, 0);
		ap = [[theController resource] fileSystemRepresentation];
		gifwrite(fp, cinf, ap, interl);
		/* fp is closed in gifwrite */
	}else {
#if 0 /* --------------------------------------------------------- */
		NSData *stream;
		NSMutableData *pal;
		NSBitmapImageRep *rep;
		NSDictionary *dic;
		int plen;

		rep = (NSBitmapImageRep *)[[toyView image]
				bestRepresentationForDevice:nil];
		cinf = [toyView commonInfo];
		plen = cinf->palsteps * 3;
		pal = [NSMutableData dataWithBytes:(const void *)(cinf->palette)
			length:plen];
		if (plen < 256 * 3)
			[pal setLength: 256 * 3];
		dic = [NSDictionary dictionaryWithObjectsAndKeys:
			pal, NSImageRGBColorTable,
	//		[NSNumber numberWithBool:NO], NSImageDitherTransparency,
	//		[NSNumber numberWithBool:NO], NSImageInterlaced,
			nil
		];
		stream = [rep representationUsingType:NSGIFFileType properties:dic];
		if (stream == nil) {
			err = Err_SAVE;
			goto EXIT;
		}
		[stream writeToFile:sav atomically:NO];
#endif /* --------------------------------------------------------- */
	}
	[[self class] setSaveDirectory:[panel directory]];
	[toyWin resetFilename:sav];
	[recentlist addNewFilepath: sav];
	if ([panel withThumbnail])
		[self makeNewIconTo:sav];

EXIT:
	if (colormap) [colormap release];
	[toyWin freeTempBitmap];
	if (err) {
		[ErrAlert runAlert:sav : err];
		[[NSFileManager defaultManager]
			removeFileAtPath:sav handler:nil];
	}
}


- (void)saveAsPng
{
	GifSavePanel *savePanel;
	NSString *stmp;
	commonInfo *cinf = [toyView commonInfo];
        if (cinf->cspace == CS_CMYK) {
		[WarnAlert runAlert:[toyWin filename] : Err_SAV_IMPL];
		return;
	}
	[self retain];	// Self is released after savePanel activate it again.

	savePanel = (GifSavePanel *)[GifSavePanel savePanel];
	// new panel is returned.

	stmp = [[self class] tmpName:[toyWin filename] ext:@"png"];
	[savePanel beginSheetForDirectory:[[self class] saveDirectory]
		file:stmp modalForWindow:[toyWin window] modalDelegate:self
		didEndSelector:@selector(savePanelforPNGDidEnd:returnCode:contextInfo:)
		contextInfo:NULL];
}

- (void)savePanelforPNGDidEnd:(NSWindow *)sheet
	returnCode:(int)returnCode contextInfo:(void  *)contextInfo;
{
	commonInfo *cinf;
	commonInfo copyinf;
	GifSavePanel *panel;
	FILE	*fp;
	ColorMap *colormap = nil;
	NSString *sav;
	unsigned char *map[MAXPLANE];
	int	err;
	static BOOL	interl;
	const char *ap;

	[self autorelease];
	if (returnCode != NSFileHandlingPanelOKButton) /* canceled */
		return;
	panel = (GifSavePanel *)sheet;
	sav = [[self class] tmpPath:[panel filename] ext:@"png"];
	if (sav == nil || [sav length] == 0)
		return;
	[self removeFile: sav];
	interl = [panel interlace];
	if ((fp = fopen([sav fileSystemRepresentation], "w")) == NULL) {
		[ErrAlert runAlert:sav : Err_SAVE];
		return;
	}

	[[self class] setSaveDirectory:[panel directory]];
	cinf = [toyView commonInfo];
	err = [toyWin getBitmap:map info: &cinf];
	if (!err) err = initGetPixel(cinf);
	if (err) goto EXIT;
	if (cinf->cspace != CS_RGB) { /* Monochrome */
		copyinf = *cinf;
		copyinf.palette = NULL;	/* No need to allocate palette */
		copyinf.palsteps = 0;
		cinf = &copyinf;
	}else {
		colormap = [[ColorMap alloc] init];
		(void) [self getPalette:colormap
			info:cinf map:(refmap)map needAlpha:YES err:&err];
		err = 0;	/* Error is ignored */
	}
	resetPixel((refmap)map, 0);
	ap = [[theController resource] fileSystemRepresentation];
	pngwrite(fp, cinf, ap, interl);
	/* fp is closed in pngwrite */
	if ([panel withThumbnail])
		[self makeNewIconTo:sav];
EXIT:
	if (colormap) [colormap release];	// should be released here.
	[toyWin freeTempBitmap];
	if (err) {
		[ErrAlert runAlert:sav : err];
		[[NSFileManager defaultManager]
			removeFileAtPath:sav handler:nil];
	}else {
		[toyWin resetFilename:sav];
		[recentlist addNewFilepath: sav];
	}
}

@end
