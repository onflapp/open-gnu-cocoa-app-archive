#import <Foundation/NSObject.h>
#import <AppKit/NSGraphics.h>
#import "common.h"

@class NSNotification, NSImage, NSWindow, ToyView;

@interface ToyWin: NSObject
{
	id	thiswindow;
	id	scView;
	id	commentText;
	id	keepOpenButton;
	id	parental;
	int 	operation;
	float	scaleFactor;
	NSString  *imageFilename;
	BOOL	makeMapOnly;
	id	_tview;
}

+ (void)initialize;
+ (BOOL)displayOverKeyWindow;
+ (void)setDisplayOverKeyWindow:(BOOL)flag;
+ (NSString *)stripHistory:(NSString *)path;
- (id)init;
- (id)init:(id)parent by:(int)op;
- (id)initMapOnly;
- (void)dealloc;
- (NSString *)filename;
- (void)resetFilename:(NSString *)fileName;
- (NSWindow *)window;
- (id)toyView;
- (id)parent;
- (int)madeby;
- (void)reScale:(id)sender;
- (id)locateNewWindow:(NSString *)fileName width:(int)width height:(int)height;
- (void)scrollProperly;
- (BOOL)keepOpen;
- (void)changeKeepOpen:(id)sender;

- (NSRect)zoomedWindowFrame;
- (NSSize)properlyResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize;

/* delegate methods */
- (void)windowDidMiniaturize:(NSNotification *)notification;
- (void)windowDidDeminiaturize:(NSNotification *)notification;
- (BOOL)windowShouldClose:(id)sender;
- (void)windowDidBecomeKey:(NSNotification *)notification;
- (void)windowDidExpose:(NSNotification *)notification;
- (void)windowDidMove:(NSNotification *)notification;
- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize;
// - (NSRect)windowWillUseStandardFrame:(NSWindow *)sender defaultFrame:(NSRect)defaultFrame;

@end


@interface ToyWin (Drawing)

- (commonInfo *)drawToyWin:(NSString *)fileName type:(int)type
	map:(unsigned char **)map err:(int *)err;
- (id)drawView:(unsigned char **)map info:(commonInfo *)cinf;
- (int)drawFromFile:(NSString *)fileName or:(NSData *)data;
- (void)makeComment:(commonInfo *)cinf;
- (void)makeComment:(commonInfo *)cinf from:(const commonInfo *)originfo;

@end


@interface ToyWin (Saving)

- (NSData *)openEPSData;
- (NSData *)openPDFData;
- (NSData *)openVectorData;
- (int)getBitmap:(unsigned char **)map info:(commonInfo **)infp;
- (void)freeTempBitmap;
	/* freeTempBitmap must be called after getBitmap:info: */
#if MAC_OS_X_VERSION_10_2 > MAC_OS_X_VERSION_MAX_ALLOWED
- (ToyView *)meshView;	// Needed because of Mac OS X's BUG
#endif
- (void)printWithDPI:(int)dpi;

@end
