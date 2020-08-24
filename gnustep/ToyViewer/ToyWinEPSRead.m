#import "ToyWinEPS.h"
#import <AppKit/NSTextField.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSEPSImageRep.h>
#import <AppKit/NSBitmapImageRep.h>
#import <Foundation/NSData.h>
#import "NSStringAppended.h"
#import <stdio.h>
//#import <libc.h>
#import <string.h>
#import "ToyView.h"
#import "common.h"
#import "strfunc.h"

@implementation ToyWinEPS (Readin)

/*
 *  EPS Image File Reading...
 */
static char *titlep = NULL, *creatorp = NULL;
static BOOL inheader;

/* Overload */
- (void)makeComment:(commonInfo *)cinf
{
	sprintf(cinf->memo, "%d x %d  EPS", cinf->width, cinf->height);
	if (titlep || creatorp) { /* only one has value */
		strcat(cinf->memo, " : ");
		if (titlep) {
			comm_cat(cinf->memo, titlep);
			free((void *)titlep);
			titlep = NULL;
		}
		if (creatorp) {
			comm_cat(cinf->memo, "by ");
			comm_cat(cinf->memo, creatorp);
			free((void *)creatorp);
			creatorp = NULL;
		}
	} 
}

/* Some EPS images, especially made by tools of X-Window, have illegal
   "%%Page:" comments.  Some EPS images used by Macintosh have unnecessary
   information at the beginning of and at the tail of the file.
 */
#define  EPSLineLength	512	/* MAX should be 256+x */


static int getEPSline(FILE *fp, char *buf, int ch)
{
	int c, i;
	static char isSpace[32] = {
		0, 0, 0, 0, 0, 0, 0, 0,
		0, 1, 1, 1, 1, 1, 0, 0, /* TAB, NL, VTAB, NEWPAGE, CR */
		0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 1, 0, 0, 0, 0, /* ESC */
	};

	if (ch != '%') /* First char of current line */
		inheader = NO;
	for (i = 0, c = ch;  ; ) {
		if (c == EOF || i >= EPSLineLength - 1)
			break;
		if (c == 0x0a || c == 0x0d) {
			if (c == 0x0d) { /* Macintosh */
				if ((c = fgetc(fp)) == 0x0a) /* MS-DOS */
					c = fgetc(fp);
			}else /* c == 0x0a : UNIX */
				c = fgetc(fp);
			buf[i++] = '\n';
			break;
		}
		if ((c < ' ' && !isSpace[c]) || (c & 0x7f) == 0x7f) {
			/* Binary byte included */
			while (c != 0x0a && c != 0x0d && c != EOF)
				c = fgetc(fp);
			if (c != EOF) c = fgetc(fp);
			i = 0;
		}else {
			buf[i++] = c;
			c = fgetc(fp);
		}
	}
	buf[i] = 0;
	if (buf[0] == '%' && buf[1] == '%') {
		if (strncmp(buf, "%%Page", 6) == 0)
			return getEPSline(fp, buf, c);
		if (inheader) {
			if (!titlep && strncmp(buf, "%%Title: ", 9) == 0)
				titlep = str_dup(&buf[9]);
			else if (!creatorp
				&& strncmp(buf, "%%Creator: ", 11) == 0)
				creatorp = str_dup(&buf[11]);
		}
	}
	return c;
}

- (NSData *)openDataFromFile:(NSString *)fileName err:(int *)err
{
	FILE	*fp;
	NSMutableData *stream;
	int	c;
	char	buf[EPSLineLength];
	const char *p;

	*err = 0;
	if ((fp = fopen([fileName fileSystemRepresentation], "r")) == NULL) {
		*err = Err_OPEN;
		return NULL;
	}
	if ((stream = [NSMutableData dataWithCapacity: 0]) == nil) {
		*err = Err_MEMORY;
		return NULL;
	}

	while ((c = fgetc(fp)) != '%' && c != EOF) ;
	titlep = creatorp = NULL;
	inheader = YES;
	if (c != EOF) {
		c = getEPSline(fp, buf, c);
		if (strncmp(buf, "%!PS-Adobe", 10) == 0)
			[stream appendBytes:buf length:strlen(buf)];
		else {
			p = "%!PS-Adobe-2.0 EPSF-2.0\n";
			[stream appendBytes:p length:strlen(p)];
		}
		while (c != EOF) {
			c = getEPSline(fp, buf, c);
			[stream appendBytes:buf length:strlen(buf)];
		}
	}
	fclose(fp);
	return stream;
}

/* Overload */
- (commonInfo *)drawToyWin:(NSString *)fileName type:(int)type
	map:(unsigned char **)map err:(int *)err
{
	NSData *stream;

	if ((stream = [self openDataFromFile:fileName err:err]) == NULL)
		return NULL;
	*err = [self drawFromFile:fileName or:stream];
	return NULL;
}

@end
