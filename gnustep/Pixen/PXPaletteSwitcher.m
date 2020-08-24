#import "PXPaletteSwitcher.h"
#import "PXPalette.h"
#import "PXNamePrompter.h"
#import "PXCanvas.h"
#import "PXDocument.h"
#import "PXColorPaletteController.h"
#import "PXGradientBuilderController.h"
#import <math.h>

#ifdef __COCOA__
static NSString *COLORPALLETTESPRESET = @"Application Support/Pixen/Palettes/Presets";
#else
static NSString *COLORPALLETTESPRESET = @"Pixen/Palettes/Presets";
#endif

/**************************/
/** Private categories ****/
/**************************/

@interface PXPaletteSwitcher (Private)
- (void) _populatePopup: (NSPopUpButton *) aPopup withDefaultPalettesUsingSelectionAction:(SEL)aSelector;
- (void) _populatePopup:(NSPopUpButton *) aPopup withUserPalettesUsingSelectionAction:(SEL)aSelector;
@end

@implementation PXPaletteSwitcher (Private)

- (void) _populatePopup:(NSPopUpButton *) aPopup withDefaultPalettesUsingSelectionAction:(SEL)aSelector
{
	if( [defaultPalettes count] == 0 )
    {
		defaultPalettes = [[[self class] defaultPalettes] deepMutableCopy];
    }
	
	id enumerator = [defaultPalettes objectEnumerator];
	id current;
	
	while ( ( current = [enumerator nextObject] ) )
    {
		id item = [[[NSMenuItem alloc] initWithTitle:[current name] action:aSelector keyEquivalent:@""] autorelease];
		[item setRepresentedObject:current];
		[item setTarget:self];
		[[aPopup menu] addItem:item];
    }
}

- (void) _populatePopup:(NSPopUpButton *)aPopup withUserPalettesUsingSelectionAction:(SEL)aSelector
{
	if([userPalettes count] == 0)
    {
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES);
		if ( [paths count] > 0 )
		{
			id current;
			NSString *path = [[paths objectAtIndex:0] stringByAppendingPathComponent:COLORPALLETTESPRESET];
			
			id enumerator = [[NSFileManager defaultManager] enumeratorAtPath:path];
			
			while( ( current = [enumerator nextObject] ) )
			{
				if([[current pathExtension] isEqualToString:@"pxpalette"])
				{
					id aPalette = [NSKeyedUnarchiver unarchiveObjectWithFile:[path stringByAppendingPathComponent:current]];
					id item = [[[NSMenuItem alloc] initWithTitle:[current stringByDeletingPathExtension] 
														  action:aSelector 
												   keyEquivalent:@""] autorelease];
					
					[item setRepresentedObject:aPalette];
					[item setTarget:self];
					[[aPopup menu] addItem:item];
					[userPalettes addObject:aPalette];
				}
			}
		}
    }
	else
    {
		id enumerator = [userPalettes objectEnumerator];
		id current;
		while ( ( current = [enumerator nextObject] ) ) 
		{
			id item = [[[NSMenuItem alloc] initWithTitle:[current name] 
												  action:aSelector
										   keyEquivalent:@""] autorelease];
			
			[item setRepresentedObject:current];
			[item setTarget:self];
			[[aPopup menu] addItem:item];
		}
    }
	
	if([userPalettes count] == 0)
    {
		[aPopup setAutoenablesItems:NO];
		id item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"NO_USER_PALETTES", @"No User Palettes")
											  action:nil keyEquivalent:@""] autorelease];
		[item setTarget:nil];
		[item setEnabled:NO];
		[[aPopup menu] addItem:item];
    }
}


@end


@implementation PXPaletteSwitcher

+ defaultPalettes
{
	static id palettes = nil;
	if(palettes == nil) 
    {
		palettes = [[NSMutableArray alloc] initWithCapacity:48];
		id enumerator = [[NSColorList availableColorLists] objectEnumerator];
		id current;
		while( ( current = [enumerator nextObject]) )
		{
			id colors = [NSMutableArray arrayWithCapacity:128];
			id colorEnumerator = [[current allKeys] objectEnumerator];
			id currentColor;
			while( ( currentColor = [colorEnumerator nextObject] )  )
			{
				[colors addObject:[current colorWithKey:currentColor]];
			}
			[palettes addObject:[[[PXPalette alloc] initWithName:[current name] colors:colors] autorelease]];
		}
		
		float rgb = 0;
		float alpha = 1;
		id grays = [NSMutableArray arrayWithCapacity:256];
		id color;
		
		int i = 0;
		for (i=0; i<64; i++) {
			rgb = (float)i / 64.0;
			color = [NSColor colorWithCalibratedRed:rgb green:rgb blue:rgb alpha:alpha];
			[grays addObject:color];
		}
		rgb = 0;
		for (i=0; i<64; i++) {
			alpha = log2(64 - i) * 0.1667;
			color = [NSColor colorWithCalibratedRed:rgb green:rgb blue:rgb alpha:alpha];
			[grays addObject:color];
		}
		rgb = .5;
		for (i=0; i<64; i++) {
			alpha = log2(64 - i) * 0.1667;
			color = [NSColor colorWithCalibratedRed:rgb green:rgb blue:rgb alpha:alpha];
			[grays addObject:color];
		}
		rgb = 1;
		for (i=0; i<64; i++) {
			alpha = log2(64 - i) * 0.1667;
			color = [NSColor colorWithCalibratedRed:rgb green:rgb blue:rgb alpha:alpha];
			[grays addObject:color];
		}
		[palettes addObject:[[[PXPalette alloc] initWithName:NSLocalizedString(@"GRAYSCALE", @"Grayscale") colors:grays] autorelease]];
    }
	return palettes;
}

-(id) init
{
	if (! ( self = [super init] )  )
		return nil;
	
	namePrompter = [[PXNamePrompter alloc] init];
	[namePrompter setDelegate:self];
	defaultPalettes = [[NSMutableArray alloc] initWithCapacity:32];
	userPalettes = [[NSMutableArray alloc] initWithCapacity:32];
	gradientBuilder = [[PXGradientBuilderController alloc] initWithPaletteSwitcher:self];
	
	return self;
}


- (void)dealloc
{
	[userPalettes release];
	[defaultPalettes release];
	[namePrompter release];
	[super dealloc];
}


- (void) populateMenuForCanvas: (id) aCanvas
{
	[paletteChooser setEnabled:YES];
	canvas = aCanvas;
	id selected = [[[paletteChooser titleOfSelectedItem] retain] autorelease];
	[paletteChooser removeAllItems];
	id menu = [paletteChooser menu];
	[self _populatePopup:paletteChooser withDefaultPalettesUsingSelectionAction:@selector(selectPalette:)];
	[menu addItem:[NSMenuItem separatorItem]];
	[self _populatePopup:paletteChooser withUserPalettesUsingSelectionAction:@selector(selectPalette:)];
	[menu addItem:[NSMenuItem separatorItem]];
	id canvasPalette = [canvas palette];    
	
	if(canvasPalette != nil)
    {
		id item = [[[NSMenuItem alloc] initWithTitle:[canvasPalette name]
											  action:@selector(selectPalette:) 
									   keyEquivalent:@""] autorelease];
		
		[item setRepresentedObject:canvasPalette];
		[item setTarget:self];
		[[paletteChooser menu] addItem:item];
		[menu addItem:[NSMenuItem separatorItem]];
    }
	
	[menu addItemWithTitle:NSLocalizedString(@"PALETTE_SAVE_AS", @"Palette Save As") 
					action:@selector(saveCurrentPalette:) 
			 keyEquivalent:@""];
	[[menu itemWithTitle:NSLocalizedString(@"PALETTE_SAVE_AS", @"Palette Save As")] setTarget:self];
	
	[menu addItemWithTitle:NSLocalizedString(@"PALETTE_SET_DEFAULT", @"Set As Default") 
					action:@selector(setCurrentPaletteAsDefault:) 
			 keyEquivalent:@""];
	[[menu itemWithTitle:NSLocalizedString(@"PALETTE_SET_DEFAULT", @"Set As Default")] setTarget:self];
	
	[menu addItemWithTitle:NSLocalizedString(@"PALETTE_DELETE", @"Palette Delete")
					action:@selector(deleteCurrentPalette:) 
			 keyEquivalent:@""];
	[[menu itemWithTitle:NSLocalizedString(@"PALETTE_DELETE", @"Palette Delete")] setTarget:self];
	
	[menu addItemWithTitle:NSLocalizedString(@"PALETTE_MAKE_GRADIENT", @"Make Gradient")
					action:@selector(makeGradient:) 
			 keyEquivalent:@""];
	[[menu itemWithTitle:NSLocalizedString(@"PALETTE_MAKE_GRADIENT", @"Make Gradient")] setTarget:self];
	
	if(![[paletteChooser itemTitles] containsObject:selected] 
	   || [[paletteChooser titleOfSelectedItem] isEqualToString:NSLocalizedString(@"PALETTE_DELETE", @"Palette Delete")] 
	   || (selected == nil) 
	   || [selected isEqual:@""]) 
    { 
		[self selectDefaultPalette];
#warning safer ? 
		if ( ! [paletteChooser selectedItem] ) 
			[self performSelector:[[paletteChooser itemAtIndex:0] action] withObject:[paletteChooser selectedItem]]; 
		else
			[self performSelector:[[paletteChooser selectedItem] action] withObject:[paletteChooser selectedItem]]; 
    }
	
	else if(![selected isEqualToString:NSLocalizedString(@"PALETTE_SAVE_AS", @"Palette Save As")] 
			&& ![selected isEqualToString:NSLocalizedString(@"PALETTE_MAKE_GRADIENT", @"Make Gradient")])
    {
		[paletteChooser selectItemWithTitle:selected];
		[self performSelector:[[paletteChooser selectedItem] action] withObject:[paletteChooser selectedItem]]; 
    }
}




- (unsigned)indexOfPalette:aPalette
{
	unsigned index = [userPalettes indexOfObject:aPalette];
	if (index != NSNotFound) 
		return index;
	
	
	for (index = 0; index < [userPalettes count]; index++)
    {
		if ( [[aPalette name] isEqualToString:[[userPalettes objectAtIndex:index] name]] ) 
		{
			return index;
		}
	}
	
	return NSNotFound;
}

- (void)addNewPalette:(id) newPalette withName:(NSString *) name replacingPaletteAtIndex:(unsigned)index
{
	[(PXPalette *)newPalette setName:name];
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES);
	
	if ( [paths count] ==  0 )
		return;
	
    //Construct the file path
	NSString *path = [[paths objectAtIndex:0] stringByAppendingPathComponent:COLORPALLETTESPRESET];
	path = [[path  stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"pxpalette"];
	
	[NSKeyedArchiver archiveRootObject:newPalette toFile:path];
	if ( index == NSNotFound )
    {
		[userPalettes addObject:newPalette];
    }
	else
    {
		[userPalettes replaceObjectAtIndex:index withObject:newPalette];
    }
	
	[self populateMenuForCanvas:canvas];
	[paletteChooser selectItemWithTitle:name];
	
	[self performSelector:[[paletteChooser itemWithTitle:name] action] withObject:[paletteChooser itemWithTitle:name]];
	
}



- (void)selectDefaultPalette
{
	if ([[NSUserDefaults standardUserDefaults] stringForKey:@"PXDefaultPalette"] == nil)
    {
		[[NSUserDefaults standardUserDefaults] setObject:@"Crayons" forKey:@"PXDefaultPalette"];
    }
	
	NSString *defaultPaletteName = [[NSUserDefaults standardUserDefaults] objectForKey:@"PXDefaultPalette"];
	
	if ([paletteChooser itemWithTitle:defaultPaletteName] == nil) 
    {
		[self selectPaletteNamed:@"Crayons"];
    } 
	else
    {
		[self selectPaletteNamed:defaultPaletteName];
    }
}

- (void)selectPaletteNamed:(NSString *) aName
{
	[paletteChooser setEnabled:YES];
	
	if([paletteChooser itemWithTitle:aName] == nil)
		return;
	
	[paletteChooser selectItemWithTitle:aName];
	
	[self performSelector:[[paletteChooser selectedItem] action] withObject:[paletteChooser selectedItem]];
}

- (void)setDelegate: (id) aDelegate
{
	_delegate = aDelegate;
}


//
// IBActions 
//

- (IBAction)deleteCurrentPalette:sender
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES);
	//Should never happen
	if ( [paths count] == 0 )
		return;
	
	NSString *apath = [[paths objectAtIndex:0] stringByAppendingPathComponent:COLORPALLETTESPRESET];
	NSString *path = [[apath stringByAppendingPathComponent:[palette name]] stringByAppendingPathExtension:@"pxpalette"];
	
#warning Should check if readable ? Should check if isDirectory ?
	
	if( ! [[NSFileManager defaultManager] fileExistsAtPath:path] ) 
    { 
		[self selectDefaultPalette]; 
		return; 
    }
	
	[[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
	[userPalettes removeObject:palette];
	[self populateMenuForCanvas:canvas];
}


- (IBAction)makeGradient:(id)sender
{
	[gradientBuilder beginSheetInWindow:[[PXColorPaletteController sharedPaletteController] palettePanel]];
}


- (IBAction)selectPalette:(id) sender
{
	palette = [sender representedObject];
	[_delegate setPalette:palette];
}

- (IBAction)saveCurrentPalette:(id) sender
{
	[namePrompter promptInWindow:[_delegate palettePanel] context:palette
					promptString:NSLocalizedString(@"NEW_PALETTE_PROMPT", @"New Palette Prompt") 
					defaultEntry:[palette name]];
}

- (IBAction)setCurrentPaletteAsDefault:(id) sender
{
	[[NSUserDefaults standardUserDefaults] setObject:[palette name] forKey:@"PXDefaultPalette"];
	[self selectDefaultPalette];
}

@end



@implementation PXPaletteSwitcher ( NamePrompterDelegate )

- (void)prompter:aPrompter didFinishWithName:name context:contextObject
{
	[self addNewPalette:[[contextObject copy] autorelease]
			   withName:name 
replacingPaletteAtIndex:[self indexOfPalette:contextObject]];
}

- (void)prompter:aPrompter didCancelWithContext:contextObject
{
	[paletteChooser selectItemWithTitle:[palette name]];
	
	[self performSelector:[[paletteChooser itemWithTitle:[palette name]] action]
			   withObject:[paletteChooser itemWithTitle:[palette name]]];
}


@end
