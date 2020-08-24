#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSFileManager.h>
#import "../ColorMap.h"
#import "../common.h"
#import "../NSStringAppended.h"

@interface ImageSave:NSObject
{
	id	toyWin;
	id	toyView;
	id	imageOpCtr;	/* Used by GIF saving */
	id	recentlist;	/* RecentFileList */
	int	imagetype;
}

+ (void)initialize;
+ (void)setSaveDirectory:(NSString *)dir;
+ (NSString *)saveDirectory;
+ (void)setIconDirectory:(NSString *)dir;
- (void)setIconDirectory:(NSString *)dir;
+ (NSString *)iconDirectory;
+ (NSString *)tmpPath:(NSString *)path ext:(NSString *)ex;
+ (NSString *)tmpName:(NSString *)path ext:(NSString *)ex;

- (id)initWithWin:(id)aToyWin;
- (void)setRecentList:(id)obj;
- (void)setOpCtr:(id)obj;
- (void)saveAsType:(int)itype;
- (void)saveAsEPS;
- (void)saveAsPDF;
- (void)savePanelforEPSDidEnd:(NSWindow *)sheet
	returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (void)makeNewIconTo:(id)sav;
- (void)attachCustomIcon;	/* Attach Custom Icon Only */
- (void)openPanelforIconDidEnd:(NSOpenPanel *)sheet
	returnCode:(int)returnCode contextInfo:(void *)contextInfo;
+ (void)removeCustomIcon;	/* Remove Custom Icon Only */
- (void)removeFile:(NSString *)fname;
@end

@interface ImageSave (SaveTIFF)
- (void)saveAsTiff;
- (void)savePanelforTIFFDidEnd:(NSWindow *)sheet
	returnCode:(int)returnCode contextInfo:(void *)contextInfo;
@end

@interface ImageSave (SaveJPG)
- (void)saveAsJPG;
- (void)savePanelforJPGDidEnd:(NSWindow *)sheet
	returnCode:(int)returnCode contextInfo:(void *)contextInfo;
@end

@interface ImageSave (SaveJ2K)
- (void)saveAsJ2K;
- (void)savePanelforJ2KDidEnd:(NSWindow *)sheet
	returnCode:(int)returnCode contextInfo:(void *)contextInfo;
@end

@interface ImageSave (SaveXBM)
- (void)saveAsXBM;
- (void)savePanelforXBMDidEnd:(NSWindow *)sheet
	returnCode:(int)returnCode contextInfo:(void *)contextInfo;
@end

@interface ImageSave (SaveGIF)
- (int)getPalette:(ColorMap *)colormap info:(commonInfo *)cinf
	map:(refmap)map needAlpha:(BOOL)alflag err:(int *)code;
- (void)saveAsGif;
- (void)savePanelforGIFDidEnd:(NSWindow *)sheet
	returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)doSaveAsGIF:(NSWindow *)sheet;
/* Methods for PNG */
- (void)saveAsPng;
- (void)savePanelforPNGDidEnd:(NSWindow *)sheet
	returnCode:(int)returnCode contextInfo:(void *)contextInfo;
@end
