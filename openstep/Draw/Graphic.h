@class GraphicView;

#define KNOB_DY_ONCE  0x1
#define KNOB_DY_TWICE 0x2
#define KNOB_DX_ONCE  0x4
#define KNOB_DX_TWICE 0x8

/* corners */

#define LOWER_LEFT	(0x10)
#define LEFT_SIDE	(KNOB_DY_ONCE)
#define UPPER_LEFT	(LEFT_SIDE|KNOB_DY_TWICE)
#define TOP_SIDE	(UPPER_LEFT|KNOB_DX_ONCE)
#define UPPER_RIGHT	(TOP_SIDE|KNOB_DX_TWICE)
#define BOTTOM_SIDE	(KNOB_DX_ONCE)
#define LOWER_RIGHT	(BOTTOM_SIDE|KNOB_DX_TWICE)
#define RIGHT_SIDE	(LOWER_RIGHT|KNOB_DY_ONCE)

/* special corner which means upper right, but also note that we're creating */

#define CREATE		(0x20)

/* corner mask values */

#define LOWER_LEFT_MASK		(1 << LOWER_LEFT)
#define LEFT_SIDE_MASK		(1 << LEFT_SIDE)
#define UPPER_LEFT_MASK		(1 << UPPER_LEFT)
#define TOP_SIDE_MASK		(1 << TOP_SIDE)
#define UPPER_RIGHT_MASK	(1 << UPPER_RIGHT)
#define BOTTOM_SIDE_MASK	(1 << BOTTOM_SIDE)
#define LOWER_RIGHT_MASK	(1 << LOWER_RIGHT)
#define RIGHT_SIDE_MASK		(1 << RIGHT_SIDE)
#define ALL_CORNERS		0xffffffff

/* arrows */

#define ARROW_AT_START	1
#define ARROW_AT_END	2
#define ARROW_AT_BOTH	3

/* Fills - These must match up with the order in the PopUpList in the Inspector Panel */

#define FILL_NONE	0
#define FILL_EO		1
#define FILL_NZWR	2

extern id CrossCursor;

@interface Graphic : NSObject
{
    NSRect bounds;			/* the bounds */
    float linewidth;			/* linewidth */
    struct _gFlags {
#ifdef __BIG_ENDIAN__
	unsigned int selected:1;	/* whether selected */
	unsigned int active:1;		/* whether to really draw in draw: */
	unsigned int eofill:1;		/* whether eofilled */
	unsigned int fillColorSet:1;	/* whether to put frame around fill */
	unsigned int downhill:1;	/* Line: direction line goes */
	unsigned int initialized:1;	/* subclass specific */
	unsigned int linewidthSet:1;	/* used when archiving only */
	unsigned int lineColorSet:1;	/* used when archiving only */
	unsigned int linejoin:2;	/* line join */
	unsigned int linecap:2;		/* line cap */
	unsigned int fill:1;		/* whether filled */
	unsigned int locked:1;		/* locked down? */
	unsigned int arrow:2;		/* arrow position */
	unsigned int nooutline:1;	/* whether the graphic is outlined */
	unsigned int isFormEntry:1;	/* whether the graphic is a form entry (TextGraphic only) */
	unsigned int localizeFormEntry:1; /* whether to localize a form entry (TextGraphic only) */
	unsigned int mightBeLinked:1;	/* set if Graphic has ever had a link associated with it */
        unsigned int notCached:1;	/* was the graphic view cached without this graphic in it? */
	unsigned int padding:11;
#else
	unsigned int padding:11;
        unsigned int notCached:1;	/* was the graphic view cached without this graphic in it? */
	unsigned int mightBeLinked:1;	/* set if Graphic has ever had a link associated with it */
	unsigned int localizeFormEntry:1; /* whether to localize a form entry (TextGraphic only) */
	unsigned int isFormEntry:1;	/* whether the graphic is a form entry (TextGraphic only) */
	unsigned int nooutline:1;	/* whether the graphic is outlined */
	unsigned int arrow:2;		/* arrow position */
	unsigned int locked:1;		/* locked down? */
	unsigned int fill:1;		/* whether filled */
	unsigned int linecap:2;		/* line cap */
	unsigned int linejoin:2;	/* line join */
	unsigned int lineColorSet:1;	/* used when archiving only */
	unsigned int linewidthSet:1;	/* used when archiving only */
	unsigned int initialized:1;	/* subclass specific */
	unsigned int downhill:1;	/* Line: direction line goes */
	unsigned int fillColorSet:1;	/* whether to put frame around fill */
	unsigned int eofill:1;		/* whether eofilled */
	unsigned int active:1;		/* whether to really draw in draw: */
	unsigned int selected:1;	/* whether selected */
#endif
    } gFlags;
    NSColor *lineColor;
    NSColor *fillColor;
    int identifier;			/* unique identifier */
}

/* Factory methods */

+ (void)showFastKnobFills;
+ (void)initClassVars;
+ (BOOL)isEditable;
+ (NSCursor *)cursor;

+ (int)currentGraphicIdentifier;
+ (int)nextCurrentGraphicIdentifier;
+ (void)updateCurrentGraphicIdentifier:(int)newMaxIdentifier;

/* Initialization method */

- (id)init;


/* Private methods (for subclassers only) */

- (void)setGraphicsState;
- (void)setLineColor;
- (void)setFillColor;
- (int)cornerMask;

/* Data link methods */

- (void)setLink:(NSDataLink *)aLink;
- (NSDataLink *)link;
- (Graphic *)graphicLinkedBy:(NSDataLink *)aLink;
- (void)reviveLink:(NSDataLinkManager *)linkManager;
- (NSSelection *)selection;
- (BOOL)mightBeLinked;
- (void)readLinkFromPasteboard:(NSPasteboard *)pboard usingManager:(NSDataLinkManager *)linkManager useNewIdentifier:(BOOL)useNewIdentifier;

/* Notification from GraphicView */

- (void)wasRemovedFrom:(GraphicView *)sender;
- (void)wasAddedTo:(GraphicView *)sender;

/* Methods for uniquely identifying a Graphic. */

- (void)resetIdentifier;
- (int)identifier;
- (NSString *)identifierString;
- (Graphic *)graphicIdentifiedBy:(int)anIdentifier;

/* Event handling */

- (BOOL)handleEvent:(NSEvent *)event at:(NSPoint)p inView:(NSView *)view;

/* Public routines (called mostly by a GraphicView or subclassers). */

- (NSString *)title;
- (BOOL)isSelected;
- (BOOL)isActive;
- (BOOL)isCached;
- (BOOL)isLocked;
- (void)select;
- (void)deselect;
- (void)activate;
- (void)deactivate;
- (void)lockGraphic;
- (void)unlockGraphic;

- (BOOL)isFormEntry;
- (void)setFormEntry:(int)flag;
- (BOOL)hasFormEntries;
- (BOOL)writeFormEntryToMutableString:(NSMutableString *)aString;
- (BOOL)writesFiles;
- (void)writeFilesToDirectory:(NSString *)directory;

- (void)setCacheable:(BOOL)flag;
- (BOOL)isCacheable;

- (NSRect)bounds;
- (void)setBounds:(NSRect)aRect;
- (NSRect)extendedBounds;

- (int)knobHit:(NSPoint)point;

- (void)draw:(NSRect)rect;

- (BOOL)canEmitEPS;
- (BOOL)canEmitTIFF;

- (void)moveLeftEdgeTo:(const float *)x;
- (void)moveRightEdgeTo:(const float *)x;
- (void)moveTopEdgeTo:(const float *)y;
- (void)moveBottomEdgeTo:(const float *)y;
- (void)moveHorizontalCenterTo:(const float *)x;
- (void)moveVerticalCenterTo:(const float *)y;
- (void)moveBaselineTo:(const float *)y;
- (float)baseline;

- (void)moveBy:(const NSPoint *)offset;
- (void)moveTo:(NSPoint)p;
- (void)centerAt:(NSPoint)center;
- (void)sizeTo:(const NSSize *)size;
- (void)sizeToNaturalAspectRatio;
- (void)alignToGrid:(GraphicView *)graphicView;
- (void)sizeToGrid:(GraphicView *)graphicView;

/* Public routines (called mostly by inspectors and the like). */

- (void)setLineWidth:(const float *)value;
- (float)lineWidth;
- (void)setLineColor:(NSColor *)color;
- (Graphic *)colorAcceptorAt:(NSPoint)point;
- (NSColor *)lineColor;
- (void)setFillColor:(NSColor *)color;
- (NSColor *)fillColor;
- (void)changeFont:(id)sender;
- (NSFont *)font;
- (void)setGray:(const float *)value;
- (float)gray;
- (void)setFill:(int)mode;
- (int)fill;
- (void)setOutlined:(BOOL)outlinedFlag;
- (BOOL)isOutlined;
- (void)setLineCap:(int)capValue;
- (int)lineCap;
- (void)setLineArrow:(int)arrowValue;
- (int)lineArrow;
- (void)setLineJoin:(int)joinValue;
- (int)lineJoin;

/* Archiving (must be overridden by subclasses with instance variables) */

- (void)convertSelf:(ConversionDirection)direction propertyList:(id)plist;
- (id)propertyList;
- initFromPropertyList:(id)plist inDirectory:(NSString *)directory;

/* Routines intended to be subclassed for different types of Graphics. */

/*
 * Can be overridden to provide more sophisticated size constraining
 * than an aspect ratio (though that is almost always sufficient).
 * For example, Line overrides this to constrain to closes 15 degree angle.
 * constrainByDefault says whether constraining is the default or not for
 * the receiving kind of Graphic.
 */

- (BOOL)constrainByDefault;
- (void)constrainCorner:(int)corner toAspectRatio:(float)aspect;

/*
 * Can be overridden to resize the Graphic differently than the
 * default (which is to drag out the bounds), or to do something
 * before and/or after the subclass is resized.  This is called
 * during the default creation method as well (create:in:).
 */

- (void)resize:(NSEvent *)event by:(int)corner in:(GraphicView *)view;

/*
 * Possible override candidate for different types of Graphics.
 * Should return YES if the Graphic got created okay.
 * The most common need to override this method is if the creation
 * of the Graphic requires multiple mouseUps and mouseDowns (for
 * an arbitrary arc, for example).
 */

- (BOOL)create:(NSEvent *)event in:(GraphicView *)view;

/*
 * Override hit: if you want your subclass to only get selected when the
 * mouse goes down in certain parts of the bounds (not the whole bounds).
 * e.g. Lines only get selected if you click close to them.
 */

- (BOOL)hit:(NSPoint)point;

/*
 * Returns YES if this Graphic can't be seen through.
 * Default behaviour is to return YES if the Graphic isFilled.
 */

- (BOOL)isOpaque;

/*
 * Returns YES if the Graphic is properly formed (usually this just
 * refers to whether it is big enough to be a real graphic during creation).
 * This is called by create:in:.  By default it returns YES if the Graphic
 * is at least 10.0 by 10.0 pixels in size.
 */

- (BOOL)isValid;

/*
 * This is the Graphic's natural aspect ratio.  If it doesn't have a natural
 * aspect ratio, then this method should return zero (the default return).
 */

- (float)naturalAspectRatio;

/*
 * Called repeatedly as the user drags the mouse to create or resize
 * the Graphic.  The default implementation does the right thing.
 * The specified corner should be moved to the specified point.
 */

- (int)moveCorner:(int)corner to:(NSPoint)point constrain:(BOOL)flag;

/*
 * This routine actually draws the graphic.  It should be draw to fit the
 * bounds instance variable.  Be sure to use all the parameters listed in
 * the instance variable list (e.g. linewidth, fillgray, etc.) that are
 * appropriate to this object.  It is probably a good idea to do a newpath
 * and a closepath at the beginning and the end of draw.
 * If a sublcass just wants to draw a unit-sized version of itself
 * (i.e. it draws itself in a bounding box of {{0.0,0.0},{1.0,1.0}})
 * it can just override unitDraw (and not draw).
 */

- (void)unitDraw;
- draw;

/*
 * Should return YES iff the Graphic can be "edited."  It is up to the
 * subclass of Graphic to determine what this means for it.  Usually
 * it means that it has text and allows that text to be edited by the
 * user (e.g. TextGraphic).  Default is to do nothing and return NO.
 */

- (BOOL)edit:(NSEvent *)event in:(NSView *)view;

@end
