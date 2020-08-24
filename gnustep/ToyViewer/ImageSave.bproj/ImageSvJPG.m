//
//  ImageSvJPG.m
//  ToyViewer
//
//  Created by ogihara on Sat Apr 21 2001.
//  Copyright (c) 2001 OGIHARA Takeshi. All rights reserved.
//

#import "ImageSave.h"
#import <AppKit/NSImage.h>
#import "JpegSavePanel.h"
#import "../TVController.h"
#import "../ToyView.h"
#import "../ToyWin.h"
#import "../ToyWinEPS.h"
#import "../ColorMap.h"
#import "../AlertShower.h"
#import "../strfunc.h"
#import "../common.h"
#import "../RecentFileList.h"
#import "save.h"


@implementation ImageSave (SaveJPG)

- (void)saveAsJPG
{
	JpegSavePanel *savePanel;
	NSString *stmp, *path;
	commonInfo *cinf = [toyView commonInfo];
        if (cinf->cspace == CS_CMYK) {
		[WarnAlert runAlert:[toyWin filename] : Err_SAV_IMPL];
		return;
	}
	[self retain];	// Self is released after savePanel activate it again.

	savePanel = (JpegSavePanel *)[JpegSavePanel savePanel];
	// new panel is returned.

	path = [toyWin filename];
	stmp = [ImageSave tmpName:path ext:[savePanel suffix]];
	[savePanel beginSheetForDirectory:[[self class] saveDirectory]
		file:stmp modalForWindow:[toyWin window] modalDelegate:self
		didEndSelector:@selector(savePanelforJPGDidEnd:returnCode:contextInfo:)
		contextInfo:NULL];
}

- (void)savePanelforJPGDidEnd:(NSWindow *)sheet
	returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
	FILE	*fp;
	NSString *sav;
	commonInfo *cinf;
	ColorMap *colormap = nil;
	unsigned char *map[MAXPLANE];
	int	factor;
	BOOL	progress;
	int	err = 0;
	const char *ap;
	JpegSavePanel *panel;

	[self autorelease];
	if (returnCode != NSFileHandlingPanelOKButton) /* canceled */
		return;
	panel = (JpegSavePanel *)sheet;
	sav = [ImageSave tmpPath:[panel filename] ext:[panel suffix]];
	if (sav == nil || [sav length] == 0)
		return;

	[[self class] setSaveDirectory:[panel directory]];
	factor = (int)[panel compressFactor];
	progress = [panel interlace];
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
	if (factor < 0) factor = 0;
	else if (factor > 100) factor = 100;
	err = jpgwrite(fp, cinf, ap, factor, progress);
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
	}else
		[recentlist addNewFilepath: sav];
}

@end
