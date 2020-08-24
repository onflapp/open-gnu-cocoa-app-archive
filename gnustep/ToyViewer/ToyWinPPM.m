#import <AppKit/NSApplication.h>
#import <AppKit/AppKit.h>
#import "NSStringAppended.h"
#import <sys/file.h>
#import <stdio.h>
#import <stdlib.h>
//#import <libc.h>
#import <string.h>
#import <sys/wait.h>
#import "ToyWinPPM.h"
#import "AlertShower.h"
#import "ppm.h"
#import "strfunc.h"


static FILE *openPipe(const char *const *list, int *err)
{
	int pfd[2];
	int pid;

	/* if (*err != 0) then fork() didn't called successfully */
	*err = 0;
	if (list == NULL || access(list[0], X_OK) < 0) {
		*err = Err_FLT_EXEC;
		return NULL;	/* not executable */
	}
	(void)pipe(pfd);
	if ((pid = fork()) == 0) { /* child process */
		(void)close(1);
		dup(pfd[1]);
		(void)close(pfd[0]);
		(void)close(pfd[1]);
		execv(list[0], (char *const *)&list[1]);
		exit(1);	/* Error */
	}else if (pid < 0) {	/* ERROR */
		*err = Err_FLT_EXEC;
		(void)close(pfd[0]);
		(void)close(pfd[1]);
		return NULL;
	}
	(void)close(pfd[1]);
	return fdopen(pfd[0], "r");
}


@implementation ToyWinPPM

- (commonInfo *)drawToyWin:(NSString *)fileName type:(int)type
	map:(unsigned char **)map err:(int *)err
{
	FILE *fp = NULL;
	commonInfo *cinf = NULL;
	BOOL	waitchild = NO;
	const char *ext = NULL;
	int alert;

	*err = 0;
	if (type == Type_ppm) {
		if ((fp = fopen([fileName fileSystemRepresentation], "r")) == NULL) {
			*err = Err_OPEN;
			return NULL;
		}
	}else {
		fp = openPipe((const char *const *)execList, err);
		waitchild = (*err == 0);
		ext = (extension && *extension) ? extension : execList[1];
		free((void *)execList);
		execList = NULL;
		if (fp == NULL) {
			if (*err == 0) *err = Err_OPEN;
			if (waitchild)
				(void)wait(0);	/* openPipe() calles fork() */
			return NULL;
		}
	}

	if ((cinf = loadPpmHeader(fp, err)) == NULL) {
		(void)fclose(fp);
		if (waitchild)
			(void)wait(0);	/* openPipe() calles fork() */
		return NULL;
	}

	if (!makeMapOnly)
		[self locateNewWindow:fileName width:cinf->width height:cinf->height];

/* Bitmap data of planes in 'map[]' is one block of memory area.
   map[0] is beginning of the area, and map[1] = map[0] + (size of plane),
   and so on. But, if the image is monochrome, map[1] is NULL.
   The area of map[0] and (commonInfo *)cinf are kept in an object of
   ToyView, and freed by it.
*/
	alert = ppmGetImage(fp, cinf, map, ext);
	(void)fclose(fp);
	if (waitchild)
		(void)wait(0);	/* openPipe() calles fork() */
	if (alert) /* Warn Only */
		[WarnAlert runAlert:fileName : alert];

	if (makeMapOnly)
		return cinf;
	if ([self drawView:map info: cinf] == nil)
		*err = -1;
	return cinf;
}

- (void)setExecList: (const char **)list ext: (const char *)type
	/* list is free-ed by this obj */
{
	execList = list;
	extension = type;
}

@end
