#import "PrefControl.h"
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSBundle.h>	/* LocalizedString */
#import <AppKit/NSColorWell.h>
#import <AppKit/NSColor.h>
#import <AppKit/NSPopUpButton.h>
#import <AppKit/NSScreen.h>
#import "AlertShower.h"
#import "ToyView.h"
#import "ToyWin.h"
#import "ToyWinPCD.h"
#import "RecentFileList.h"
#import "ppm.h"
#import "version.h"

// #define  OWNER		@"ToyViewer"
#define  cVersion	@"ToyViewerVersion"
#define  pcdSIZE	@"pcdSIZE"
#define  pcdBRIGHT	@"pcdBRIGHT"
#define  adINTERVAL	@"adINTERVAL"
#define  winINTERVAL	@"winINTERVAL"
#define  adIGNOREDOTS	@"adIGNOREDOTS"
#define  originUL	@"originUL"
#define  winPOSITION	@"winPOSITION"
#define  timedALERT	@"timedALERT"
#define  updateSVC	@"updateSVC"
#define  unixExpert	@"NSUnixExpert"
#define  transCOLOR	@"transCOLOR"
#define  topLeftPOINT	@"topLeftPOINT"
#define  fscreenCOLOR	@"fscreenCOLOR"
#define  windowMARGIN	@"windowMARGIN"
#define  RecentFileNum	@"RecentFileNumber"
#ifdef __APPLE__
#define  FixedXPos	8.0
#define  FixedYPos	22.0
#else
#define  FixedXPos	240.0
#define  FixedYPos	12.0
#endif
#define  MarginDef	24

static NSUserDefaults *usrdef = nil;
static NSSize screenSize;
static NSString *winPosKey[] = { @"Auto", @"Fix", @"ScanFix" };

static id thePreference = nil;


@implementation PrefControl

+ (void)initialize
{
	usrdef = [NSUserDefaults standardUserDefaults];
	screenSize = [[NSScreen mainScreen] frame].size;
}

+ (id)sharedPref
{
	if (thePreference == nil)
		thePreference = [[self alloc] init];
	return thePreference;
}

/* Local Method */
- (void)getDefColorWells
{
	int i;
	NSArray *ar = [usrdef arrayForKey: fscreenCOLOR];
	if (ar == nil || [ar count] < 3) {
		static float defs[3] = { 0.0, 0.0, 0.08 };
		for (i = 0; i < 3; i++)
			backg[i] = defs[i];
	}else {
		for (i = 0; i < 3; i++)
			backg[i] = [[ar objectAtIndex: i] intValue] / 255.0;
	}
}

/* Local Method */
- (void)getWindowMargin
{
	int i;
	NSArray *ar = [usrdef arrayForKey: windowMARGIN];
	marginBits = 0;
	if (ar == nil || [ar count] < 4)
		marginWidthVal = MarginDef;
	else {
		marginWidthVal = [[ar objectAtIndex: 3] intValue];
		if (marginWidthVal > 0) {
			for (i = 0; i < 3; i++)
				if ([[ar objectAtIndex: i] boolValue])
					marginBits |= (1 << i);
		}
	}
}

/* Local Method */
- (void)checkVersion
{
	NSString *s = [usrdef stringForKey: cVersion];
	NSString *cv = [NSString stringWithUTF8String: CurrentVersion];
	if (s == nil || [s compare:cv] == NSOrderedAscending) {
		/* This is New ToyViewer */
		[usrdef setObject:cv forKey:cVersion];
	}
}

- (id)init
{
	NSString *s;
	const char *p;
	NSArray *ar;

	[super init];
	[self checkVersion];
	s = [usrdef stringForKey:pcdSIZE];
	pcdSizeValue = s ? [s intValue] : 1;	/* Base/4 */
	s = [usrdef stringForKey:pcdBRIGHT];
	pcdBrightValue = s ? [s intValue] : 1; /* Normal */
	[ToyWinPCD setBase:pcdSizeValue bright:pcdBrightValue];

	s = [usrdef stringForKey:adINTERVAL];
	adIntervalValue = s ? [s intValue] : 2500; /* 2.5 sec */
	adIgnoreDots = [usrdef boolForKey:adIGNOREDOTS];

	s = [usrdef stringForKey:winINTERVAL];
	winIntervalValue = s ? [s intValue] : 1000; /* 1.0 sec */

	s = [usrdef stringForKey:RecentFileNum];
	recentFNum = s ? [s intValue] : 10; /* Recent Files */

	origSWValue = [usrdef boolForKey:originUL];	/* UpperLower */
	(void)[ToyView setOriginUpperLeft: origSWValue];

	windowPosValue = 1;	/* Fix */
	s = [usrdef stringForKey:winPOSITION];
	if (s != nil && (p = [s UTF8String]) != NULL)
		windowPosValue = (*p == 'F') ? 1 : ((*p == 'S') ? 2 : 0);
	[ToyWin setDisplayOverKeyWindow: (windowPosValue == pos_Fix)];
	ar = [usrdef arrayForKey:topLeftPOINT];
	if (ar == nil || [ar count] < 2) {
		topLeftPoint.x = FixedXPos;
		topLeftPoint.y = FixedYPos;
	}else {
		topLeftPoint.x = [[ar objectAtIndex: 0] floatValue];
		topLeftPoint.y = [[ar objectAtIndex: 1] floatValue];
	}

	transColorValue = 0;	/* Black */
	s = [usrdef stringForKey:transCOLOR];
	if (s != nil && (p = [s UTF8String]) != NULL)
		transColorValue = (*p == 'W') ? 1 : 0;
	[ToyView setAlphaAsBlack:(transColorValue == 0)];
	setGIFWrongIndexBlack(transColorValue == 0);

	ErrAlert = [[AlertShower alloc]
		initWithTitle:NSLocalizedString(@"ERROR", ERROR)];
	WarnAlert = [[AlertShower alloc]
		initWithTitle:NSLocalizedString(@"WARNING", ERROR)];
	timedAltValue = [usrdef boolForKey:timedALERT] ? 1 : 0;
	if (timedAltValue)
		[AlertShower setTimedAlert: YES];

	updateSvcValue = [usrdef boolForKey:updateSVC];
#ifndef __APPLE__
	unixExpertValue = [usrdef boolForKey:unixExpert];
#endif
	[self getDefColorWells];
	[self getWindowMargin];

	return self;
}

- (void)makeKeyAndOrderFront:(id)sender
{
	int i, m;

	if (panel == nil) {
		[NSBundle loadNibNamed:@"Preference.nib" owner:self];
		[pcdSize selectItemAtIndex:pcdSizeValue];
		[pcdBright selectCellWithTag:pcdBrightValue];
		[winIntSlider setFloatValue: winIntervalValue / 1000.0];
		[adIntSlider setFloatValue: adIntervalValue / 1000.0];
		[recentFNumTX setIntValue: recentFNum];
		[adIgnoreSW setState: adIgnoreDots];
		[origSW selectCellWithTag:(origSWValue ? 1 : 0)];
		[positionSW selectCellWithTag:windowPosValue];
		[transSW selectCellWithTag: transColorValue];
		[timedAltSW setState:timedAltValue];
		[updateSvcSW setState:(updateSvcValue ? 1 : 0)];
#ifndef __APPLE__
		[unixExpertSW setState:(unixExpertValue ? 1 : 0)];
#endif
		[fscrWell setColor:
			[NSColor colorWithCalibratedRed:backg[0]
			green:backg[1] blue:backg[2] alpha:1.0]];
		for (i = 0, m = 1; i < 3; i++, m <<= 1)
			[[marginSWs cellWithTag: i] setState: ((marginBits & m) != 0)];
		[marginWidth setIntValue: marginWidthVal];
		[marginWidth setEnabled: (marginBits != 0)];
	}
	[panel makeKeyAndOrderFront:sender];
}

- (void)changeValue:sender
{
	int val;
	BOOL bval, pcdflag;

	pcdflag = NO;
	val = [pcdSize indexOfSelectedItem];
	if (val != pcdSizeValue) {
		pcdflag = YES;
                [usrdef setInteger:(pcdSizeValue = val) forKey:pcdSIZE];
	}
	val = [pcdBright selectedTag];
	if (val != pcdBrightValue) {
		pcdflag = YES;
                [usrdef setInteger:(pcdBrightValue = val) forKey:pcdBRIGHT];
	}
	if (pcdflag)
		[ToyWinPCD setBase:pcdSizeValue bright:pcdBrightValue];

	bval = ([adIgnoreSW state] != 0);
	if (bval != adIgnoreDots) {
		adIgnoreDots = bval;
		[usrdef setBool:bval forKey:adIGNOREDOTS];
	} 
	bval = ([origSW selectedTag] != 0);
	if (bval != origSWValue) {
		origSWValue = bval;
		[usrdef setBool:bval forKey:originUL];
		(void)[ToyView setOriginUpperLeft: origSWValue];
	}
	val = [positionSW selectedTag];
	if (val != windowPosValue) {
		windowPosValue = val;
		[usrdef setObject:winPosKey[windowPosValue] forKey:winPOSITION];
		[ToyWin setDisplayOverKeyWindow: (windowPosValue == pos_Fix)];
	}
	val = [transSW selectedTag];
	if (val != transColorValue) {
		transColorValue = val;
		[usrdef setObject:(transColorValue ? @"White" : @"Black")
			forKey:transCOLOR];
		[ToyView setAlphaAsBlack:(transColorValue == 0)];
		setGIFWrongIndexBlack(transColorValue == 0);
	}
	val = [timedAltSW state];
	if (val != timedAltValue) {
		timedAltValue = val;
		[usrdef setBool:(val != 0) forKey:timedALERT];
		[AlertShower setTimedAlert: timedAltValue];
	}
	bval = ([updateSvcSW state] != 0);
	if (bval != updateSvcValue) {
		updateSvcValue = bval;
		[usrdef setBool:bval forKey:updateSVC];
	} 
#ifndef __APPLE__
	bval = ([unixExpertSW state] != 0);
	if (bval != unixExpertValue) {
		unixExpertValue = bval;
		[usrdef setBool:bval forKey:unixExpert];
	}
#endif
}

- (void)changeWell:(id)sender
{
	NSColor *cl;
	float	buf[4];
	int	i, v;
	NSMutableArray *ar;

	cl = [sender color];
	cl = [cl colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	[cl getRed:&buf[0] green:&buf[1] blue:&buf[2] alpha:NULL];
	for (i = 0; i < 3; i++)
		if (buf[i] != backg[i]) break;
	if (i >= 3)
		return;
	ar = [NSMutableArray arrayWithCapacity: 3];
	for (i = 0; i < 3; i++) {
		backg[i] = buf[i];
		v = buf[i] * 255.0;
		[ar addObject:[NSString localizedStringWithFormat:@"%d", v]];
	}
	[usrdef setObject:ar forKey: fscreenCOLOR];
}

- (void)changeMargin:(id)sender
{
	int i, tag, bit, w;
	BOOL cngflag = NO;

	tag = [sender tag];
	if (tag < 3) { /* by SW */
		bit = 0;
		for (i = 0; i < 3; i++)
			if ([[marginSWs cellWithTag: i] state])
				bit |= (1 << i);
		if (bit != marginBits) {
			cngflag = YES;
			marginBits = bit;
		}
		[marginWidth setEnabled: (marginBits != 0)];
	}else { /* by width */
		w = [marginWidth intValue];
		if (w < 0) {
			[marginWidth setIntValue: marginWidthVal];
			return; /* Illegal value */
		}
		if (w != marginWidthVal) {
			cngflag = YES;
			marginWidthVal = w;
		}
		if (marginWidthVal <= 0) {
			for (i = 0; i < 3; i++)
				[[marginSWs cellWithTag: i] setState: NO];
			marginBits = 0;
			[marginWidth setEnabled: NO];
		}
	}
	if (cngflag) {
		NSMutableArray *ar = [NSMutableArray arrayWithCapacity: 4];
		for (i = 0; i < 3; i++)
			[ar addObject: [NSNumber numberWithBool:
				((marginBits & (1 << i)) != 0)]];
		[ar addObject: [NSNumber numberWithInt: marginWidthVal]];
		[usrdef setObject:ar forKey: windowMARGIN];
	}
}

- (void)changeRecentFileNumber:(id)sender
{
	int v = [recentFNumTX intValue];
	if (v < 2)
		v = 2;
	else if (v > 64)
		v = 64;
	else {
		recentFNum = v;
		v = 0;
	}
	if (v) [recentFNumTX setIntValue: (recentFNum = v)];
	[[RecentFileList sharedList] setMaxFiles: recentFNum];
	[usrdef setInteger:recentFNum forKey:RecentFileNum];
}

- (int)autoDisplayInterval { return adIntervalValue; }

- (int)allWinDisplayInterval { return winIntervalValue; }

- (BOOL)ignoreDottedFiles { return adIgnoreDots; }

- (int)recentFileNumber { return recentFNum; }

- (int)windowPosition { return windowPosValue; }

- (NSPoint)topLeftPoint { return topLeftPoint; }

- (void)setPosition:(id)sender
{
	int tag = [sender tag];
	NSRect rect = [positionPanel frame];
	if (tag == 0) {
		NSArray *ar;
		topLeftPoint.x = rect.origin.x;
		topLeftPoint.y
		    = screenSize.height - (rect.origin.y + rect.size.height);
		ar = [NSArray arrayWithObjects:
			[NSString stringWithFormat:@"%d", (int)topLeftPoint.x],
			[NSString stringWithFormat:@"%d", (int)topLeftPoint.y],
			nil];
		[usrdef setObject:ar forKey:topLeftPOINT];
	}
	[positionPanel close];
}

- (void)showPositionPanel:(id)sender
{
	NSPoint pnt;

	pnt.x = topLeftPoint.x;
	pnt.y = screenSize.height - topLeftPoint.y;
	[positionPanel setFrameTopLeftPoint:pnt];
	[positionPanel makeKeyAndOrderFront:self];
	[positionPanel setFloatingPanel:YES];
}

- (BOOL)isUpdatedServices { return updateSvcValue; }

- (void)backgroungColor:(float *)colors
{
	int i;
	for (i = 0; i < 3; i++)
		colors[i] = backg[i];
}

- (unsigned char)windowMarginBits { return marginBits; }
- (int)windowMarginWidth { return marginWidthVal; }

- (void)windowWillClose:(NSNotification *)aNotification
{
	int	val;

	val = (int)([adIntSlider floatValue] * 1000.0);
	if (val != adIntervalValue)
                [usrdef setInteger:(adIntervalValue=val) forKey:adINTERVAL];
	val = (int)([winIntSlider floatValue] * 1000.0);
	if (val != winIntervalValue)
                [usrdef setInteger:(winIntervalValue=val) forKey:winINTERVAL];
}

@end
