#import <AppKit/NSApplication.h>
#import <AppKit/AppKit.h>
#import <Foundation/NSString.h>
#import "NSStringAppended.h"
#import <Foundation/NSBundle.h>
#import <sys/file.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import "ToyWinPCD.h"
#import "PrefControl.h"
#import "strfunc.h"

#define pcdCOMMAND @"hpcdtoppm"

static int prefBase = 0;
static int prefBright = 0;

@implementation ToyWinPCD

+ (void)setBase:(int)base bright:(int)bright
{
	prefBase = base;
	prefBright = bright;
}

- (commonInfo *)drawToyWin:(NSString *)fileName type:(int)type
	map:(unsigned char **)map err:(int *)err
{
	int x;
	NSString *str;
	static const char *const brightTab[] = { ":+", "", ":-" };
	static const char *const baseTab[] = {
		"B-16", "B-4", "B", "B+4", "B+16", "B+64" };

	for (x = 0; execList[x]; x++) ;
	execList[x] = (const char *)[fileName fileSystemRepresentation];
	str = [NSString stringWithFormat:@"%@(%s%s)",
		fileName, baseTab[prefBase], brightTab[prefBright]];
	return [super drawToyWin:str type:type map:map err:err];
}

- (void)setting
{
	const char **list;
	static char *pathp = NULL, *pathn = NULL;
	static char *brightTab[] = { "-c+", "-c0", "-c-" };
	static char *baseTab[] = {
		"-1", "-2", "-3", "-4", "-5", "-6" };

	list = (const char **)malloc(sizeof(const char *) * 6);
	if (pathp == NULL) {
		int n;	
		NSBundle *bundle = [NSBundle mainBundle];
		NSString *path = [bundle pathForResource:pcdCOMMAND ofType:@""];
		pathp = str_dup([path fileSystemRepresentation]);
		for (n = strlen(pathp) - 1; n >= 0 && pathp[n] != '/'; n--)
			;
		pathn = &pathp[n + 1];
	}
	list[0] = pathp;
	list[1] = pathn;
	list[2] = brightTab[prefBright];
	list[3] = baseTab[prefBase];
	list[4] = NULL;	/* filename */
	list[5] = NULL;
	[self setExecList: list ext: "pcd"]; /* list is free-ed by self */
}

@end
