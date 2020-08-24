
#import <AppKit/AppKit.h>
#import "DirList.h"
#import "PlayControl.h"

@interface ADController:NSObject <PlayControl>
{
	id	nextFile;
	id	panel;
	id	pauseButton;
	id	playButton;
	id	stepButton;
	id	quitButton;
	id	slider;
	id	sliderMax;
	id	slave;
	id	lButton;
	id	rButton;
	id	fscreenSW;
	id	fscreenMethod;
	id	loopSW;
	int	fileNum;
	int	currentNum;
	int	status;
	int	forwarding;
	BOOL	waiting;
	DirList *dirlist;
}

- (id)init:(id)sender dir:(NSString *)dir with:(DirList *)list;
- (void)dealloc;
- (void)sliderChange:sender;
- (void)sliderDown:sender;
- (void)sliderUp:sender;
- (BOOL)scanFixPosition;

- (void)changeFullScreen:(id)sender;
- (int)fullscreenMethod;

/* comm. slave */
- (NSString *)nextFilename;
- (void)continueLoop:(BOOL)cont;

/* Delegate of window */
- (void)windowDidResignKey:(NSNotification *)aNotification;

@end
