//
//  ImageSvJ2K.m
//  ToyViewer
//
//  Created on Sat Aug 03 2002.
//  Copyright (c) 2002 Takeshi Ogihara. All rights reserved.
//

#import "ImageSave.h"
#import <AppKit/NSImage.h>
#import "J2kSavePanel.h"
#import "../TVController.h"
#import "../ToyView.h"
#import "../ToyWin.h"
#import "../ToyWinEPS.h"
#import "../ColorMap.h"
#import "../AlertShower.h"
#import "../strfunc.h"
#import "../common.h"
#import "../RecentFileList.h"
#import "J2kParams.h"
#import "save.h"


@implementation ImageSave (SaveJ2K)

- (void)saveAsJ2K
{
	J2kSavePanel *savePanel;
	NSString *stmp, *path;
	commonInfo *cinf = [toyView commonInfo];
        if (cinf->cspace == CS_CMYK
	// || (cinf->numcolors == 1 && cinf->bits == 1 /* BiLevel */)
	) {
		[WarnAlert runAlert:[toyWin filename] : Err_SAV_IMPL];
		return;
	}
	[self retain];	// Self is released after savePanel activate it again.

	savePanel = (J2kSavePanel *)[J2kSavePanel savePanel];
	// new panel is returned.

	path = [toyWin filename];
	stmp = [ImageSave tmpName:path ext:[savePanel suffix]];
	[savePanel beginSheetForDirectory:[[self class] saveDirectory]
		file:stmp modalForWindow:[toyWin window] modalDelegate:self
		didEndSelector:@selector(savePanelforJ2KDidEnd:returnCode:contextInfo:)
		contextInfo:NULL];
}

- (void)savePanelforJ2KDidEnd:(NSWindow *)sheet
	returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
	FILE	*fp;
	NSString *sav;
	commonInfo *cinf;
	ColorMap *colormap = nil;
	unsigned char *map[MAXPLANE];
	float	rate;
	int	progress, format;
	int	err = 0;
	const char *ap;
	J2kSavePanel *panel;

	[self autorelease];
	if (returnCode != NSFileHandlingPanelOKButton) /* canceled */
		return;
	panel = (J2kSavePanel *)sheet;
	sav = [ImageSave tmpPath:[panel filename] ext:[panel suffix]];
	if (sav == nil || [sav length] == 0)
		return;

	[[self class] setSaveDirectory:[panel directory]];
	rate = [panel compressRate];
	format = [panel formatKind];
	progress = [panel progressiveKind];
	[self removeFile: sav];

	if ((fp = fopen([sav fileSystemRepresentation], "w")) == NULL) {
		[ErrAlert runAlert:sav : Err_SAVE];
		return;
	}

	cinf = [toyView commonInfo];
	err = [toyWin getBitmap:map info: &cinf];
	if (!err) err = initGetPixel(cinf);
	if (err) goto EXIT;

	ap = [[theController resource] fileSystemRepresentation];
	resetPixel((refmap)map, 0);
	err = j2kwrite(fp, cinf, ap, format, rate, progress);
	fp = NULL;
	if ([panel withThumbnail])
		[self makeNewIconTo:sav];
	[panel saveParameters];

EXIT:
	if (fp) (void)fclose(fp);
	[colormap release];
	[toyWin freeTempBitmap];
	if (err) {
		[ErrAlert runAlert:sav : err];
		[[NSFileManager defaultManager] removeFileAtPath:sav handler:nil];
	}else {
		if (rate == Lossless)
			[toyWin resetFilename:sav]; 
		[recentlist addNewFilepath: sav];
	}
}

@end
