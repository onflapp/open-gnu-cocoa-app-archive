#import <Foundation/NSObject.h>
#import <AppKit/NSResponder.h>

#define  toyviewerTAB	@"filters"
#define  toyviewerRC	@".toyviewerrc"

@class ToyWin, 	BackgCtr, PrintInfoCtrl, RecentFileList;
@class NSApplication, NSImage, NSNotification, NSPasteboard, NSData, NSMenuItem;

/* Notification */
extern NSString *NotifyAllWindowDidClosed;

@interface TVController:NSObject
{
	id	imageOpCtr;
	id	frontModeMenu;
	id	recentMenu;
	RecentFileList *recentlist;
	PrintInfoCtrl *prtInfo;
}

+ (void)setOpenedDir:(NSString *)newdir;
+ (NSString *)openedDir;

- (void)applicationDidFinishLaunching:(NSNotification *)notification;
- (void)applicationWillTerminate:(NSNotification *)aNotification;
- (NSString *)resource;
- (int)getFTypeID:(NSString *)aType;
- (id)drawFile: (NSString *)fn;
- (NSData *)openDataFromFile:(NSString *)fn;
- (void)openFile:(id)sender;
- (void)openPasteBoard:(id)sender;
- (void)autoDisplay:(id)sender;
- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)fn;
- (BOOL)openFileOrDirectory:(NSString *)fn;
- (void)addToRecentMenu:(NSString *)str;

/* To receive services, implement these methods (delegate) */
- (BOOL)readSelectionFromPasteboard:(NSPasteboard *)pb;

@end

@interface TVController (WindowManager)

- (BOOL)hasWindow;
- (void)newWindow:(ToyWin *)win;
- (BOOL)checkAndDeleteWindow:(ToyWin *)win;
- (BOOL)checkWindow:(ToyWin *)win;
- (void)deleteAllWindow:(id)sender;
- (void)showAllWindow:(id)sender;
- (id)keyWindow;
- (void)showNextWindow:(id)sender;
- (void)activateInspector:(id)sender;
- (void)activatePreferences:(id)sender;
- (id)keyParentWindow:(int)op;
- (id)winOpened:(NSString *)newfile makeKey:(BOOL)flag;
- (void)print:(id)sender;
- (void)runPageLayout:(id)sender;
- (void)saveAs:(id)sender;
- (void)attachIcon:(id)sender;
- (void)removeIcon:(id)sender;

- (void)activateWebPage:(id)sender;
- (void)attraction:(id)sender;	// Info.Panel attraction

- (void)toggleFrontMode:(id)sender;

/* NSMenuActionResponder Protocol */
- (BOOL)validateMenuItem:(NSMenuItem *)aMenuItem;

@end

/* defined in PBService */
NSString *getStringFromPB(NSPasteboard *pasteboard, NSString *currentType);

@interface TVController (PBService)

- (void)prepareServices;
/* To receive services, implement these methods (delegate) */
- (id)validRequestorForSendType:(NSString *)sendType returnType:(NSString *)returnType;

- (void)convertToTIFF:(NSPasteboard *)pasteboard userData:(NSString *)userData error:(NSString **)errorMessage;
- (void)openImageFromPasteboard:(NSPasteboard *)pasteboard userData:(NSString *)userData error:(NSString **)errorMessage;
- (void)registerFilterServiceTypes:(NSString **)typestrs withID:(short *)typeids num:(int)typenum;

@end


extern TVController *theController;
