#import "PXToolSwitcher.h"
#import "PXPencilTool.h"
#import "PXEraserTool.h"
#import "PXEyedropperTool.h"
#import "PXZoomTool.h"
#import "PXFillTool.h"
#import "PXLineTool.h"
#import "PXRectangularSelectionTool.h"
#import "PXMoveTool.h"
#import "PXRectangleTool.h"
#import "PXEllipseTool.h"
#import "PXMagicWandTool.h"
#import "PXLassoTool.h"

NSString *PXToolDidChangeNotificationName = @"PXToolDidChangeNotification";
NSMutableArray * toolNames;

@implementation PXToolSwitcher

+(NSArray *) toolClasses
{
	return [NSArray arrayWithObjects:[PXPencilTool class], [PXEraserTool class], [PXEyedropperTool class], [PXZoomTool class], [PXFillTool class], [PXLineTool class], [PXRectangularSelectionTool class], [PXMoveTool class], [PXRectangleTool class], [PXEllipseTool class], [PXMagicWandTool class], [PXLassoTool class], nil];
}

+(id) toolNames
{
    return [[self toolClasses] valueForKey:@"description"];
}

- (void)lock:(NSNotification *)aNotification
{
    _locked = YES;
}

- (void)unlock:(NSNotification *)aNotification
{
    _locked = NO;
}

-(id) init
{
	[super init];
	tools = [[NSMutableArray alloc] initWithCapacity:[[[self class] toolClasses] count]];
	id enumerator = [[[self class] toolClasses] objectEnumerator];
	id current;
	while (( current = [enumerator nextObject] ) )
    {
		[tools addObject:[[current alloc] init]];
    }
	[tools makeObjectsPerformSelector:@selector(setSwitcher:) withObject:self];
	[self setColor:[NSColor blackColor]];
	[self useToolTagged:PXPencilToolTag];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(lock:) name:@"PXLockToolSwitcher" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(unlock:) name:@"PXUnlockToolSwitcher" object:nil];
	_locked = NO;
	[self checkUserDefaults];
	return self;
}

- (void)checkUserDefaults
{
  //should find a way to factor this into the tools' classes.
  id defaults = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"p", @"e", @"d", @"z", @"f", @"l", @"s", @"m", @"r", @"o", @"w", @"a", nil]
			      forKeys:[NSArray arrayWithObjects:[NSNumber numberWithInt:PXPencilToolTag], [NSNumber numberWithInt:PXEraserToolTag], [NSNumber numberWithInt:PXEyedropperToolTag], [NSNumber numberWithInt:PXZoomToolTag], [NSNumber numberWithInt:PXFillToolTag], [NSNumber numberWithInt:PXLineToolTag], [NSNumber numberWithInt:PXRectangularSelectionToolTag], [NSNumber numberWithInt:PXMoveToolTag], [NSNumber numberWithInt:PXRectangleToolTag], [NSNumber numberWithInt:PXEllipseToolTag], [NSNumber numberWithInt:PXMagicWandToolTag], [NSNumber numberWithInt:PXLassoToolTag], nil]];
  id enumerator = [defaults keyEnumerator], current;
  while ( ( current = [enumerator nextObject] ) )
    {
      if ([[NSUserDefaults standardUserDefaults] objectForKey:[[[self class] toolNames] objectAtIndex:[current intValue]]] == nil)
	[[NSUserDefaults standardUserDefaults] setObject:[defaults objectForKey:current] forKey:[[[self class] toolNames] objectAtIndex:[current intValue]]];
    }
}

- (void)dealloc
{
    [tools release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (id) tool
{
    return _tool;
}

-(id) toolWithTag:(PXToolTag)tag
{
    return [tools objectAtIndex:tag];
}

- (PXToolTag)tagForTool:(id) aTool
{
    return [tools indexOfObject:aTool];
}

- (void)setIcon:(NSImage *)anImage forTool:(id)aTool
{
    [[toolsMatrix cellWithTag:[self tagForTool:aTool]] setImage:anImage];
}

- (void)useTool:(id) aTool
{
    [self useToolTagged:[self tagForTool:aTool]];
}

- (void)useToolTagged:(PXToolTag)tag
{
    if ( _locked ) 
		return;
	
    _lastTool = _tool;
    _tool = [self toolWithTag:tag];
    [toolsMatrix selectCellWithTag:tag];
    [[NSNotificationCenter defaultCenter] postNotificationName:PXToolDidChangeNotificationName 
														object:self 
													  userInfo:[NSDictionary dictionaryWithObjectsAndKeys:_tool, @"newTool",nil]];
}

- (void)requestToolChangeNotification
{
	[[NSNotificationCenter defaultCenter] postNotificationName:PXToolDidChangeNotificationName 
														object:self 
													  userInfo:[NSDictionary dictionaryWithObjectsAndKeys:_tool, @"newTool",nil]];
}

- (NSColor *) color
{
    return _color;
}

- (void)setColor:(NSColor *)aColor
{
    id enumerator = [tools objectEnumerator];
    id current;
    [aColor retain];
    [_color release];
    _color = aColor;
	
    while ( (current = [enumerator nextObject] )  )
    {
        if([current respondsToSelector:@selector(setColor:)]) { [current setColor:_color]; }
    }
    [colorWell setColor:aColor];
}

- (IBAction)colorChanged:(id)sender
{
    [self setColor:[colorWell color]];
}

- (IBAction)toolClicked:(id)sender
{
    [self useToolTagged:[[toolsMatrix selectedCell] tag]];
}

- (IBAction)toolDoubleClicked:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"PXToolDoubleClicked" object:self];
}

- (void)keyDown:(NSEvent *)event
{
	NSString * chars = [[event charactersIgnoringModifiers] lowercaseString];
	id enumerator = [[PXToolSwitcher toolNames] objectEnumerator], current;
	while  ( ( current = [enumerator nextObject] ) )
    {
		if ([chars characterAtIndex:0] == [[[NSUserDefaults standardUserDefaults] objectForKey:current] characterAtIndex:0])
		{
			[self useToolTagged:[[PXToolSwitcher toolNames] indexOfObject:current]];
			break;
		}
    }
}

- (void)optionKeyDown
{
    if( ! [_tool optionKeyDown] ) { 
		[self useToolTagged:PXEyedropperToolTag];
    }
}

- (void)optionKeyUp
{
    if( ! [_tool optionKeyUp] ) { 
		[self useTool:_lastTool];
    }
}
- (void)shiftKeyDown
{
    [_tool shiftKeyDown];
}

- (void)shiftKeyUp
{
    [_tool shiftKeyUp];
}

@end
