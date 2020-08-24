//
//  PXColorPaletteController.m
//  Pixen-XCode
//
// Copyright (c) 2004 Open Sword Group

// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, 
//copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
// to whom the Software is furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "PXColorPaletteController.h"
#import "SubviewTableViewCell.h"
#import "PXColorWellCell.h"
#import "PXColorWell.h"
#import "PXDocument.h"
#import "PXCanvas.h"
#import "PXPalette.h"
#import "PXPaletteSwitcher.h"

#import <AppKit/NSNibLoading.h>


static PXColorPaletteController *singleInstance = nil;
//TODO Define  notification here

@interface PXColorPaletteController (Private)
- (void) _replaceColor:(NSColor *) oldColor withColor:(NSColor*) newColor atPaletteIndex:(unsigned)index swapping:(BOOL)swap;
- (void) _colorWellSelected: (NSNotification *) aNotification;
- (void) _colorAdded:(NSNotification*) aNotification;
- (void)_colorWellColorChanged:(NSNotification *) aNotification;
@end

@implementation PXColorPaletteController (Private)

- (void) _replaceColor:(NSColor *) oldColor withColor:(NSColor*) newColor atPaletteIndex:(unsigned)index swapping:(BOOL)swap
{
	if ([newColor isEqual:oldColor]) 
		return;
	
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:@"PXImageColorAddedNotification" 
												  object:nil];
	
	if( ( swap )  && ([oldColor alphaComponent] > .00125) )
    {
		[canvas replacePixelsOfColor:oldColor withColor:newColor];
    }
	
	[palette setColor:newColor atIndex:index];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:@"PXColorWellColorChanged" 
												  object:nil];
	
	[(PXColorWell *)[/*[*/[matrix cells] objectAtIndex:index] /*view]*/ setColor:newColor];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(_colorWellColorChanged:) 
												 name:@"PXColorWellColorChanged" 
											   object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(_colorAdded:) 
												 name:@"PXImageColorAddedNotification" 
											   object:nil];
}

- (void)_colorWellSelected:(NSNotification *) aNotification
{
	NSDictionary *userInfoDict = [NSDictionary dictionaryWithObjectsAndKeys:[[aNotification object] color], @"color", nil];
	
    if([[aNotification name] isEqualToString:@"PXColorWellLeftSelected"])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"PXPaletteLeftColorChosen"
															object:self
														  userInfo:userInfoDict];
		[leftMatrixWell setColor:[[aNotification object] color]];
	}
    else
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"PXPaletteRightColorChosen" 
															object:self 
														  userInfo:userInfoDict];
		[rightMatrixWell setColor:[[aNotification object] color]];
	}
}


- (void)_colorAdded:(NSNotification*) aNotification
{
	if (! [canvas isKindOfClass:[PXCanvas class]] )  
		return;
	
	if([canvas hasImage:[aNotification object]])
    {	
		int index = [palette addColor:[[aNotification userInfo] objectForKey:@"color"]];
		if(index != -1)
		{	
			[[[matrix cells] objectAtIndex:index] setColor:[palette colorAtIndex:index]];
		}
    }
}


- (void)_colorWellColorChanged:(NSNotification *) aNotification
{
	//if( ([aNotification object] != leftMatrixWell ) && ([aNotification object] != rightMatrixWell) ) 
	//	return; 
	
	NSColor *oldColor = [[aNotification userInfo] objectForKey:@"oldColor"];
	NSColor *newColor = [[aNotification object] color];
	
	if ([oldColor isEqual:newColor]) 
		return;
	
	
	if ([[palette colors] containsObject:newColor]) {
		[[aNotification object] _setColorNoVerify:oldColor];
#ifdef __COCOA__
		NSBeep();
#endif
		return;
	}
	
	if( ![[[matrix cells] valueForKey:@"view"] containsObject:[aNotification object]])  
		return; 
	//TODO factorisation
	if([aNotification object] == leftMatrixWell)
    {
		[[NSNotificationCenter defaultCenter] postNotificationName:@"PXPaletteLeftColorChosen"
															object:self
														  userInfo:[NSDictionary dictionaryWithObjectsAndKeys:newColor, @"color", nil]];
    }
	else
    {
		[[NSNotificationCenter defaultCenter] postNotificationName:@"PXPaletteRightColorChosen"
															object:self 
														  userInfo:[NSDictionary dictionaryWithObjectsAndKeys:newColor, @"color", nil]];
    }
	
	[self _replaceColor:oldColor 
			  withColor:newColor
		 atPaletteIndex:[[[matrix cells] valueForKey:@"view"] indexOfObject:[aNotification object]] 
			   swapping:[[NSUserDefaults standardUserDefaults] boolForKey:@"PXSmartPaletteEnabled"]];
}

@end


@implementation PXColorPaletteController

-(id) init
{
	if ( singleInstance ) 
    {
		[self dealloc];
		return singleInstance;
    }
	
	if ( ! (self = [super init] ) ) 
		return nil;
	
	if ( ! [NSBundle loadNibNamed:@"PXColorPalette" owner:self] )
    {
		//NSLog(@"warm the user here !!?!");
		[self dealloc];
		return nil;
    }
	
	singleInstance = self;
	
	return singleInstance;
}

-(void) awakeFromNib
{
	[panel setBecomesKeyOnlyIfNeeded:YES];
	[panel setFrameAutosaveName:@"PXColorPaletteFrame"];
	
	//Create our matrix and put it in the scrollView
	{
		int swatchWidth = 32;
		int swatchHeight = 32;
		int swatchesAcross = 8;
		int swatchesDown = 32;
		
		NSRect matrixRect = NSMakeRect(0, -(swatchesDown*swatchHeight),
									   (swatchWidth + 1) * swatchesAcross, (swatchHeight + 1) * swatchesDown);
		
		id prototype = [[PXColorWellCell alloc] init];
		
		[[NSColorPanel sharedColorPanel] setShowsAlpha:YES];
		
		//Put it elsewhere
		
		
		matrix = [[NSMatrix alloc] initWithFrame:matrixRect 
											mode:NSTrackModeMatrix 
									   prototype:prototype
									numberOfRows:swatchesDown
								 numberOfColumns:swatchesAcross];
		
		[matrix setSelectionByRect:NO];
		[matrix setDrawsBackground:YES];
		[matrix setDrawsCellBackground:YES];
		[matrix setAutosizesCells:YES];
		[matrix setAutoresizingMask:NSViewMaxYMargin];
		[matrix setAutosizesCells:NO];
		
		[scrollView setDocumentView:matrix];
	}
	
	//Add observers
	{
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(_colorWellSelected:) 
													 name:@"PXColorWellLeftSelected" 
												   object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(_colorWellSelected:) 
													 name:@"PXColorWellRightSelected" 
												   object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(_colorWellColorChanged:) 
													 name:@"PXColorWellColorChanged" 
												   object:nil]; 
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(_colorAdded:) 
													 name:@"PXImageColorAddedNotification" 
												   object:nil];
		
	}
}


+ (id) sharedPaletteController
{
	if( ! singleInstance)
		singleInstance = [[self alloc] init]; 
    
	return singleInstance;
}


- (void)selectPaletteNamed:(id)aName
{
	[switcher selectPaletteNamed:aName];
}

- (void)selectDefaultPalette
{
	[switcher selectDefaultPalette];
}

- (BOOL)runReloadWarning
{
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"PXColorPaletteDeletionWarningHasRun"];
#ifdef __COCOA__
	return ([[NSAlert alertWithMessageText:@"Discard Palette Changes?" defaultButton:@"Yes" alternateButton:@"No" otherButton:nil informativeTextWithFormat:@"Every time you switch documents, your palette changes are not automatically saved.  To prevent palette data loss, please save any modified palettes that you want to keep.  Would you really like to switch palettes?  If you choose \"No,\" you'll have to switch away and back when you're done to get it to update properly to the new canvas.  This warning will not be given again."] runModal] == NSOKButton);
#else
#warning TODO GNUstep
	return NO;
#endif
}


- (void)reloadDataForCanvas:(id)aCanvas
{
	canvas = aCanvas;
	
	if ( ( [[NSUserDefaults standardUserDefaults] boolForKey:@"PXColorPaletteDeletionWarningHasRun"] )
		 || ([self runReloadWarning]) ) 
		[switcher populateMenuForCanvas:canvas];
}


- (void)keyDown:(NSEvent *)event
{
	int column = -1, row = 0;
	NSString * chars = [[event charactersIgnoringModifiers] lowercaseString];
	
	if([[NSScanner scannerWithString:chars] scanInt:&column])
    {
		column--;
		if(column < 0) 
			column = 9; 
    }
	else
    {
		//the characters change when shift is held down, so we can't just do a modifier check
		//this won't work for international keyboards, either, will it?
		NSArray * symbols = [NSArray arrayWithObjects:@"!", @"@", @"#", @"$", @"%", @"^", @"&", @"*", @"(", @")", nil];
		if([symbols containsObject:chars])
		{	
			column = [symbols indexOfObject:chars];
			row = 1;
			if([event modifierFlags] & (NSAlternateKeyMask))
			{
				row = 2;
			}
		}
    }
	if (column == -1)
		return; 
    
	if ( ([event modifierFlags]) & ( NSControlKeyMask ) )
    {
		[[matrix cellAtRow:row column:column] rightSelect];
    }
	else
    {
		[[matrix cellAtRow:row column:column] leftSelect];
    }
}




- (void)palette:(id) aPalette foundDuplicateColorsAtIndex:(unsigned)first andIndex:(unsigned)second
{
	NSColor *oldColor = [[palette colorAtIndex:first] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	NSColor *newColor = [NSColor colorWithCalibratedRed:[oldColor redComponent] green:[oldColor greenComponent] blue:[oldColor blueComponent] alpha:[oldColor alphaComponent] - 0.000001];
	
	[self _replaceColor:oldColor
			  withColor:newColor
		 atPaletteIndex:second
			   swapping:[[NSUserDefaults standardUserDefaults] boolForKey:@"PXSmartPaletteEnabled"]];
}

- (void)setPalette:(id)newPalette
{
	if( palette == newPalette ) 
		return; 
	
	id old = palette;
	palette = [newPalette retain];
	[old autorelease];
	[palette setDelegate:self];
	unsigned int i;
	
	for(i = 0; ((i < [[palette colors] count]) || (i < [[old colors] count])) && (i < 256); i++)
    {
		NSColor *oldColor = (i < [[old colors] count]) ? [[old colors] objectAtIndex:i] : [NSColor clearColor];
		NSColor  *newColor = (i < [[palette colors] count]) ? [[palette colors] objectAtIndex:i] : [[NSColor clearColor] colorWithAlphaComponent:.001];
		
		//When ObjC looks like Perl :) 
		// STFU N00B, I WILL WRITE A COMMENT
		// Replace the old color with the new color, determining whether to swap by:
		// 1) Is the index less than the number of old colors?  If not, there's no point in trying to replace it, since it's out of the bounds anyway.
		// 2) Is the new palette the generated palette?
		// 3) Is the old palette the generated palette?
		// 4) Has the user enabled this functionality?
		
		[self _replaceColor:oldColor
				  withColor:newColor
			 atPaletteIndex:i
				   swapping:(i < [[old colors] count]) &&
			![[palette name] isEqual:NSLocalizedString(@"GENERATED_PALETTE", @"Generated Palette")] &&
			![[old name] isEqual:NSLocalizedString(@"GENERATED_PALETTE", @"Generated Palette")] &&
			[[NSUserDefaults standardUserDefaults] boolForKey:@"PXSmartPaletteEnabled"]];
    }
	//[[[matrix cells] objectAtIndex:0] leftSelect];
}


//Accessor
-(NSPanel *) palettePanel
{
	return panel;
}

@end
