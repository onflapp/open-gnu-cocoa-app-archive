#import <AppKit/AppKit.h>
#import <AppKit/NSWindow.h>

enum {
	pos_Automatic	= 0,
	pos_Fix		= 1,
	pos_FixScan	= 2
};

enum {
	margin_L	= 1,	// 1 << 0
	margin_R	= 2,	// 1 << 1
	margin_B	= 4	// 1 << 2
};

@interface PrefControl:NSObject
{
	id	panel;
	id	pcdBright;
	id	pcdSize;
	id	origSW;
	id	positionSW;
	id	positionPanel;
	id	transSW;
	id	adIntSlider;
	id	winIntSlider;
	id	adIgnoreSW;
	id	timedAltSW;
	id	updateSvcSW;
	id	unixExpertSW;
	id	fscrWell;
	id	marginSWs;
	id	marginWidth;
	id	recentFNumTX;
	unsigned char marginBits;
	int	marginWidthVal;
	int	pcdBrightValue;
	int	pcdSizeValue;
	BOOL	origSWValue;
	int	winIntervalValue;
	int	adIntervalValue;
	BOOL	adIgnoreDots;
	int	windowPosValue;
	int	transColorValue;
	int	timedAltValue;
	int	recentFNum;
	BOOL	updateSvcValue;		/* call NSUpdateDynamicServices() ? */
	BOOL	unixExpertValue;	/* See all Unix files ? */
		/* Because of bug(?) of Preferences of OPENSTEP 4.1. */
	float	backg[4];
	NSPoint	topLeftPoint;
}

+ (void)initialize;
+ (id)sharedPref;
- (id)init;
- (void)makeKeyAndOrderFront:(id)sender;
- (void)changeValue:(id)sender;
- (void)changeWell:(id)sender;
- (void)changeMargin:(id)sender;
- (void)changeRecentFileNumber:(id)sender;

- (int)autoDisplayInterval;
- (int)allWinDisplayInterval;
- (BOOL)ignoreDottedFiles;
- (int)recentFileNumber;

- (int)windowPosition;
- (NSPoint)topLeftPoint;
- (void)setPosition:(id)sender;
- (void)showPositionPanel:(id)sender;

- (BOOL)isUpdatedServices;
- (void)backgroungColor:(float *)colors;

- (unsigned char)windowMarginBits;
- (int)windowMarginWidth;

/* delegate of NSPanel */
- (void)windowWillClose:(NSNotification *)aNotification;

@end
