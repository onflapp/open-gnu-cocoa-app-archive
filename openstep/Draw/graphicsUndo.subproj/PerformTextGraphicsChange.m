#import "drawundo.h"

@implementation PerformTextGraphicsChange

static id editText = nil;
static id editWindow = nil;

- initGraphic:aGraphic view:aGraphicView
{
    [super init];

    if (editText == nil) {
	editText = [[DrawSpellText alloc] initWithFrame:(NSRect){{0,0},{0,0}}];
	[editText setRichText:YES];
    }

    if (editWindow == nil) {
	editWindow = [[NSWindow alloc] init];
    }

    graphic = aGraphic;
    graphicView = aGraphicView;
    textChange = nil;

    return self;
}

- (void)dealloc
{
   [textChange release];
   [super dealloc];
}

- (NSString *)changeName
{
    return [textChange changeName];
}

- (void)undoChange
{
    NSRect bounds;

    [self loadGraphic];
    [textChange undoChange];
    [self unloadGraphic];
    bounds = [graphic bounds];
    [graphicView cache:bounds];
    [[graphicView window] flushWindow];

    [super undoChange]; 
}

- (void)redoChange
{
    NSRect bounds;

    [self loadGraphic];
    [textChange redoChange];
    [self unloadGraphic];
    bounds = [graphic bounds];
    [graphicView cache:bounds];
    [[graphicView window] flushWindow];

    [super redoChange]; 
}

- (BOOL)incorporateChange:aChange
{
    if (textChange == nil) {
	textChange = aChange;
	return YES;
    } else {
	return NO;
    }
}

- (void)loadGraphic
{
    NSRect graphicBounds;
    [editText replaceCharactersInRange:NSMakeRange(0, [[editText string] length]) withRTF:[graphic richTextData]];
    graphicBounds = [graphic bounds];
    [editText setFrame:graphicBounds];
    [editWindow setNextResponder:graphicView]; /* so changes can find our */
                                               /* change manager          */
    [[editWindow contentView] addSubview:editText];
    [editText selectAll:self]; 
}

- (void)unloadGraphic
{
    [editWindow setNextResponder:nil];
    [editText removeFromSuperview];
    [editText setSelectedRange:NSMakeRange(0, 0)];
    [graphic setFont:[editText font]];
    [graphic setRichTextData:[editText RTFFromRange:NSMakeRange(0, [[editText string] length])]]; 
}

- (NSText *)editText
{
    return editText;
}

@end
