#import "ImageSave.h"
#import <AppKit/NSImage.h>
#import <stdio.h>
#import <libc.h>
#import <string.h>
#import "../ToyView.h"
#import "../ToyWin.h"
#import "../AlertShower.h"
#import "../strfunc.h"
#import "../common.h"
#import "../RecentFileList.h"
#import "TVSavePanel.h"
#import "save.h"

@implementation ImageSave (SaveXBM)

static unsigned char flipbits[256];

static void setup_table(enum ns_colorspace cspace)
{
	int i, n, nr, m;
	static enum ns_colorspace svCSpace;

	if (flipbits[1]) { /* flipbits was initialized */
		if (svCSpace != cspace)
			for (i = 0; i < 256; i++)
				flipbits[i] ^= 0xff;
	}else {
		for (n = nr = 0;  ; n++) {
			flipbits[n] = nr;
			if (n >= 255) break;
			for (i = 1; nr & (m = 0x100 >> i); i++)
				;
			nr = (nr & (0xff >> i)) | m;
		}
		if (cspace == CS_White)
			for (i = 0; i < 256; i++)
				flipbits[i] ^= 0xff;
	}
	svCSpace = cspace;
}

static char *getNickname(const char *sav)
{
	int i, j, cc, slash, period;
	char buf[256], *nick;

	period = slash = 0;
	for (i = 0; sav[i]; i++) {
		if (sav[i] == '/') slash = i + 1;
		else if (sav[i] == '.') period = i;
	}
	strcpy(buf, &sav[slash]);
	if (period > slash) buf[period - slash] = 0;
	nick = (char *)malloc(strlen(buf) + 2);
	j = 0;
	if (buf[0] >= '0' && buf[0] <= '9')
		nick[j++] = 'x';
	for (i = 0; (cc = buf[i]) != 0; i++)
		if ((cc >= 'a' && cc <= 'z')
		|| (cc >= 'A' && cc <= 'Z') || (cc >= '0' && cc <= '9'))
			nick[j++] = cc;
	if (j == 0) nick[j++] = 'x';
	nick[j] = 0;
	return nick;
}

- (void)saveAsXBM
{
	TVSavePanel *savePanel;
	NSString *stmp;
	commonInfo *cinf = [toyView commonInfo];
	if (cinf->bits > 2 || cinf->numcolors != 1 || cinf->cspace == CS_CMYK) {
		/* ignore alpha, ignore 2 bits gray. Because of EPS... */
		[WarnAlert runAlert:[toyWin filename] : Err_SAV_IMPL];
		return;
	}
	[self retain];	// Self is released after savePanel activate it again.

	savePanel = (TVSavePanel *)[TVSavePanel savePanel];
	// new panel is returned.
	stmp = [ImageSave tmpName:[toyWin filename] ext:@"xbm"];
	[savePanel beginSheetForDirectory:[[self class] saveDirectory]
		file:stmp modalForWindow:[toyWin window] modalDelegate:self
		didEndSelector:@selector(savePanelforXBMDidEnd:returnCode:contextInfo:)
		contextInfo:NULL];
}

- (void)savePanelforXBMDidEnd:(NSWindow *)sheet
	returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
	FILE	*fp;
	NSString *sav;
	char	*nickname = NULL;
	commonInfo *cinf;
	unsigned char *map[MAXPLANE];
	int	x, y, xb, xbytes, cnt, err;
	unsigned char *pp, *pmap = NULL;
	TVSavePanel *panel;

	[self autorelease];
	if (returnCode != NSFileHandlingPanelOKButton) /* canceled */
		return;
	panel = (TVSavePanel *)sheet;
	sav = [ImageSave tmpPath:[panel filename] ext:@"xbm"];
	if (sav == nil || [sav length] == 0)
		return;

	[self removeFile: sav];
	if ((fp = fopen([sav fileSystemRepresentation], "w")) == NULL) {
		[ErrAlert runAlert:sav : Err_SAVE];
		return;
	}
	[[self class] setSaveDirectory:[panel directory]];
	cinf = [toyView commonInfo];
	if ((err = [toyWin getBitmap:map info: &cinf]) != 0)
		goto EXIT;

	xbytes = xb = (cinf->width + 7) >> 3;
	if (cinf->alpha || cinf->bits != 1) {
		if ((err = initGetPixel(cinf)) != 0)
			goto EXIT;
		resetPixel((refmap)map, 0);
		pmap = pp = allocBilevelMap(cinf);
		if (!pp) {
			err = Err_MEMORY;
			goto EXIT;
		}
		setup_table(CS_Black);
	}else {
		setup_table(cinf->cspace);
		pp = map[0];
		xbytes = cinf->xbytes;
	}

	cnt = 0;
	nickname = getNickname([sav fileSystemRepresentation]);
	fprintf(fp, "#define %s_width  %d\n", nickname, cinf->width);
	fprintf(fp, "#define %s_height %d\n", nickname, cinf->height);
	fprintf(fp, "static char %s_bits[] = {\n ", nickname);
	for (y = 1; y < cinf->height; y++) {
		for (x = 0; x < xb; x++) {
			fprintf(fp, "0x%02x,", flipbits[*pp++]);
			if (++cnt >= 10) {
				fprintf(fp, "\n ");
				cnt = 0;
			}
		}
		for ( ; x < xbytes; x++) ++pp;
	}
	for (x = 0;  ; ) {
		fprintf(fp, "0x%02x", flipbits[*pp++]);
		if (++x >= xb) break;
		putc(',', fp);
		if (++cnt >= 10) {
			fprintf(fp, "\n ");
			cnt = 0;
		}
	}
	fprintf(fp, "};\n");
	(void)fclose(fp);
	fp = NULL;
	if ([panel withThumbnail])
		[self makeNewIconTo:sav];

EXIT:
	if (fp) (void)fclose(fp);
	if (err) {
		[ErrAlert runAlert:sav : err];
		[[NSFileManager defaultManager]
			removeFileAtPath:sav handler:nil];
	}else {
		[toyWin resetFilename:sav];
		[recentlist addNewFilepath: sav];
	}
	if (nickname) free((void *)nickname);
	if (pmap) free((void *)pmap); 
}

@end
