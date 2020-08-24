//
//  ImageSvTIFF.m
//  ToyViewer
//
//  Created by ogihara on Sun Apr 22 2001.
//  Copyright (c) 2001 OGIHARA Takeshi. All rights reserved.
//

#import "ImageSave.h"
#import <AppKit/NSImage.h>
#import "TiffSavePanel.h"
#import "../TVController.h"
#import "../ToyView.h"
#import "../ToyWin.h"
#import "../ToyWinVector.h"
#import "../ColorMap.h"
#import "../AlertShower.h"
#import "../strfunc.h"
#import "../common.h"
#import "../RecentFileList.h"
#import "save.h"


@implementation ImageSave (SaveTIFF)

- (void)saveAsTiff
{
	TiffSavePanel *savePanel;
	NSString *stmp, *path;

	[self retain];	// Self is released after savePanel activate it again.
	savePanel = (TiffSavePanel *)[TiffSavePanel savePanel];
	// new panel is returned.

	path = [toyWin filename];
	stmp = [ImageSave tmpName:path ext:[savePanel suffix]];
	[savePanel beginSheetForDirectory:[[self class] saveDirectory]
		file:stmp modalForWindow:[toyWin window] modalDelegate:self
		didEndSelector:@selector(savePanelforTIFFDidEnd:returnCode:contextInfo:)
		contextInfo:NULL];
}


- (void)savePanelforTIFFDidEnd:(NSWindow *)sheet
	returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
	NSData *stream;
	NSString *sav;
	TiffSavePanel *panel;
	commonInfo *cinf;
	int	type, err;

	[self autorelease];
	err = 0;
	if (returnCode != NSFileHandlingPanelOKButton) /* canceled */
		return;
	panel = (TiffSavePanel *)sheet;
	sav = [ImageSave tmpPath:[panel filename] ext:[panel suffix]];
	if (sav == nil || [sav length] == 0)
		return;

	[[self class] setSaveDirectory:[panel directory]];
	type = [panel compressType];

	cinf = [toyView commonInfo];
	if (cinf->type == Type_eps || cinf->type == Type_pdf) {
		stream = [(ToyWinVector *)toyWin openTiffDataBy:0.0
				compress:(type != NSTIFFCompressionNone)];
	}else { /* Bitmap Images */
		NSBitmapImageRep *rep;
		rep = (NSBitmapImageRep *)[[toyView image] bestRepresentationForDevice:nil];
		stream = [rep TIFFRepresentationUsingCompression:type factor:1.0];
	}
	if (stream != NULL) {
		/* BUG ?  Over Writing LZW on no-compression */
		[self removeFile: sav];
		if ([stream writeToFile:sav atomically:NO] == NO)
			err = Err_SAVE;
	}else
		err = Err_SAVE;

	if (err)
		[ErrAlert runAlert:sav : err];
	else {
		[toyWin resetFilename:sav]; 
		[recentlist addNewFilepath: sav];
		if ([panel withThumbnail])
			[self makeNewIconTo:sav];
	}
}

@end
