#import  <AppKit/NSView.h>
#import  "common.h"

@class NSString, NSData;
@class NSImage, NSImageRep, NSTextField, PrefControl;

@interface ToyView: NSView
{
	NSImage		*image;
	NSSize		origSize;
	NSSize		curSize;
	float		scaleFactor;
	float		backgray;
	unsigned char	*rawmap;
	commonInfo	*comInfo;
	NSRect		selectRect;
	NSRect		selectStrRect;
	id		commText;	// text field
	NSString	*commStr;
}

+ (void)initialize;
+ (BOOL)alphaAsBlack;
+ (void)setAlphaAsBlack:(BOOL)flag;
- (id)initWithImage:(NSImage *)img;
- (id)initWithContentsOfFile:(NSString *)filename;
- (id)initFromData:(NSData *)data;
- (id)initDataPlanes:(unsigned char **)planes info:(commonInfo *)cinf;
- (void)setCommText:(id)text;
- (void)setCommString:(NSString *)str;
- (NSSize)originalSize;
- (NSSize)resize:(float)factor;
- (ToyView *)resizedView:(float)factor;
- (void)dealloc;
- (NSImage *)image;
- (commonInfo *)commonInfo;
- (float)scaleFactor;
- (NSRect)selectedRect;
- (BOOL)setSelectedRect:(NSRect)rect;
- (NSRect)selectedScaledRect;

#ifdef WITH_LEGACY_EPS
- (void)beginPrologueBBox:(NSRect)boundingBox creationDate:(NSString *)dateCreated createdBy:(NSString *)anApplication fonts:(NSString *)fontNames forWhom:(NSString *)user pages:(int)numPages title:(NSString *)aTitle;	/* Overload */
#endif

@end


@interface ToyView (EventHandling)

+ (void)cursor;
+ (BOOL)setOriginUpperLeft:(BOOL)flag;
- (BOOL)acceptsFirstResponder;
- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent;
- (void)resetCursorRects;			/* Overload */

- (void)setDraggedLine:(id)sender;
- (void)clearDraggedLine;
- (void)rewriteComment;
- (void)mouseDown:(NSEvent *)event;		/* Overload */
- (void)selectAll:(id)sender;			/* Overload */
- (NSData *)streamInSelectedRect:(id)sender;
- (void)copy:(id)sender;			/* Overload */
- (void)drawRect:(NSRect)r;	/* Overload */

@end
