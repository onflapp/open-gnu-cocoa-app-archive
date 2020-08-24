//
//  PXDocument.m
//  Pixen
//
//  Created by Joe Osborn on Thu Sep 11 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import "PXDocument.h"
#import "PXCanvasController.h"
#import "PXCanvas.h"
#import "PXPSDHandler.h"
#import "PXPalette.h"
#import "PXCanvasView.h"
#import "PXCanvasPrintView.h"
#ifdef __COCOA__
#import "gif_lib.h"
#endif
#import "PXGifExporter.h"
#import "PXLayer.h"
#import "PXImage.h"
#import "PXPixel.h"
#ifdef __COCOA__
#import <AppKit/NSAlert.h>
#endif

#ifndef __COCOA__
#include "math.h"
#endif


NSString * PXDocumentOpened = @"PXDocumentOpenedNotificationName";
NSString * PXDocumentClosed = @"PXDocumentClosedNotificationName";


@interface NSData(GOLAdditions)

- (NSArray *)getLines;

@end

@implementation NSData(GOLAdditions)

- (NSArray *)getLines
{
	NSRange charRange, lineRange = NSMakeRange(0, 0);
	char character;
	char line[4096];
	NSMutableArray *lines = [NSMutableArray array];
	for (charRange = NSMakeRange(0, 1); charRange.location<[self length]; charRange.location++) {
		[self getBytes:&character range:charRange];
		if (character == '\n') {
			lineRange.length = charRange.location - lineRange.location;
			if (lineRange.length >= 4096) {
				NSLog(@"-[NSData getLines]: Line longer than 4K, truncating...");
				lineRange.length = 4095;
			}
			[self getBytes:&line range:lineRange];
			line[lineRange.length] = '\0';
			lineRange.location += lineRange.length + 1;
			[lines addObject:[NSString stringWithUTF8String:line]];
		}
	}
	return [[lines copy] autorelease];
}

@end

@implementation PXDocument

- (BOOL)rescheduleAutosave
{
	NSTimeInterval repeatTime = [[NSUserDefaults standardUserDefaults] floatForKey:@"PXAutosaveInterval"];
	if (repeatTime == 0.0f) {
		[[NSUserDefaults standardUserDefaults] setFloat:180.0 forKey:@"PXAutosaveInterval"];
		repeatTime = 180.0f;
	}
	if (repeatTime <= 0 || ![[NSUserDefaults standardUserDefaults] boolForKey:@"PXAutosaveEnabled"]) {
		return NO;
	}
	
	[[self retain] autorelease];
	[autosaveTimer invalidate];
	[autosaveTimer release];
	autosaveTimer = [[NSTimer scheduledTimerWithTimeInterval:repeatTime target:self selector:@selector(autosave:) userInfo:nil repeats:NO] retain];
	return YES;
}

- (id)init
{
    [super init];
	canSave = YES;
	canvas = [[PXCanvas alloc] init];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cleanUpAutosaveFile:) name:NSApplicationWillTerminateNotification object:[NSApplication sharedApplication]];
 	[self autosave:nil];
    return self;
}

- (void)updateChangeCount:(NSDocumentChangeType)changeType
{
	if (!canSave) {
		[super updateChangeCount:NSChangeCleared];
	} else {
		[super updateChangeCount:changeType];
	}
}

- (void)setCanSave:(BOOL)saveable
{
	canSave = saveable;
	if (!canSave) {
		[self updateChangeCount:NSChangeCleared];
	}
}

- (void)canCloseDocumentWithDelegate:(id)delegate shouldCloseSelector:(SEL)shouldCloseSelector contextInfo:(void *)contextInfo
{
	if (!canSave) {
		NSInvocation *closedInvocation;
		BOOL shouldClose = YES;
		closedInvocation = [NSInvocation invocationWithMethodSignature:[delegate methodSignatureForSelector:shouldCloseSelector]];
		[closedInvocation setSelector:shouldCloseSelector];
		[closedInvocation setArgument:&self atIndex:2];
		[closedInvocation setArgument:&shouldClose atIndex:3];
		[closedInvocation setArgument:&contextInfo atIndex:4];
		[closedInvocation invokeWithTarget:delegate];
	} else {
		[super canCloseDocumentWithDelegate:delegate shouldCloseSelector:shouldCloseSelector contextInfo:contextInfo];
	}
}

- (IBAction)saveDocument:(id)sender
{
	if (!canSave) {
		[self close];
	} else {
		[super saveDocument:sender];
	}
}

- (IBAction)saveDocumentAs:(id)sender
{
	if (!canSave) {
#ifdef __COCOA__
		NSBeep();
#endif
	} else {
		[super saveDocumentAs:sender];
	}
}

- (IBAction)saveDocumentTo:(id)sender
{
	if (!canSave) {
#ifdef __COCOA__
		NSBeep();
#endif
	} else {
		[super saveDocumentTo:sender];
	}
}

- (NSString *)displayName
{
	if (!canSave) {
		return @"";
	}
	return [super displayName];
}

- (void)changeDirtyFileFromFilename:(NSString *)from toFilename:(NSString *)to
{
	NSMutableArray *dirtyFiles = [[[[NSUserDefaults standardUserDefaults] objectForKey:@"PXDirtyFiles"] mutableCopy] autorelease];
	
	if (dirtyFiles == nil) {
		dirtyFiles = [NSMutableArray arrayWithCapacity:8];
	}
	
	if ((from != nil) && !NSEqualSizes([canvas size], NSZeroSize)) {
		if (![[NSFileManager defaultManager] removeFileAtPath:from handler:nil]) {
			NSLog(@"Could not delete backup file \"%@\"", from);
		}
		[dirtyFiles removeObject:from];
	}
	
	if (to != nil) {
		[dirtyFiles addObject:to];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:dirtyFiles forKey:@"PXDirtyFiles"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)cleanUpAutosaveFile:(NSNotification *)aNotification
{
	[self changeDirtyFileFromFilename:autosaveFilename toFilename:nil]; // this will remove our dirty autosave file from the user defaults, so it doesn't complain on the next start of Pixen and freak out the user
	autosaveFilename = nil;
}


- (void)updateAutosaveFilename
{
	NSString *oldFilename = autosaveFilename;
	
	if ([self fileName] != nil) {
		autosaveFilename = [[[[[self fileName] stringByDeletingPathExtension] stringByAppendingString:@"~"] stringByAppendingPathExtension:@"pxi"] retain];
	} else {
		autosaveFilename = [@"/tmp/PixenAutosave.pxi" retain];
	}
	if (![oldFilename isEqualToString:autosaveFilename]) {
		[self changeDirtyFileFromFilename:oldFilename toFilename:autosaveFilename];
	}
	
	[oldFilename release];
}

- (void)setFileName:(NSString *)path
{
	[super setFileName:path];
	[self autosave:nil];
}

- (void)autosave:(NSTimer *)timer
{
	if (![self rescheduleAutosave]) {
		return;
	}
	[self updateAutosaveFilename];
	if (canvas && !NSEqualSizes([canvas size], NSZeroSize)) {
		[[self dataRepresentationOfType:@"Pixen Image"] writeToFile:autosaveFilename atomically:YES];
	}
}

- (void)dealloc
{
	[autosaveFilename release];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[autosaveTimer invalidate];
	[autosaveTimer release];
    [[self windowControllers] makeObjectsPerformSelector:@selector(close)];
    [canvasController release];
    [canvas release];
    [super dealloc];
}

- (void)makeWindowControllers
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    canvasController = [[PXCanvasController alloc] init];
    [canvasController setCanvas:canvas];
    [self addWindowController:canvasController];
    [canvasController window];
	[[NSNotificationCenter defaultCenter] postNotificationName:PXDocumentOpened object:self];
}

- (void)windowControllerDidLoadNib:aController
{
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
}

- (void)close
{
	[[NSNotificationCenter defaultCenter] postNotificationName:PXDocumentClosed object:self];
	[autosaveTimer invalidate];
	[self cleanUpAutosaveFile:nil];
	[super close];
}

BOOL isPowerOfTwo(int num)
{
	double logResult = log2(num);
	return (logResult == (int)logResult);
}

- (NSData *)dataRepresentationOfType:(NSString *)aType
{
	if (!canSave) {
		return nil;
	}
	
	if([aType isEqualToString:@"Pixen Image"])
    {
		return [NSKeyedArchiver archivedDataWithRootObject:canvas];
    }
	if([aType isEqualToString:@"Portable Network Graphic (PNG)"])
    {
		return [canvas imageDataWithType:NSPNGFileType properties:nil];
    }
	if([aType isEqualToString:@"Tagged Image File Format (TIFF)"])
    {
		return [canvas imageDataWithType:NSTIFFFileType properties:nil];
    }
	
#ifdef __COCOA__
	if([aType isEqualToString:@"Compuserve Graphic (GIF)"])
    {		
		id image = [[NSImage alloc] initWithSize:[canvas size]];
		[image lockFocus];
		[canvas drawRect:NSMakeRect(0,0,[canvas size].width,[canvas size].height) fixBug:YES];
		[image unlockFocus];
		return [PXGifExporter gifDataForImage:image];
    }
	if([aType isEqualToString:@"Windows Bitmap (BMP)"])
    {
		return [canvas imageDataWithType:NSBMPFileType properties:nil];
    }
	if([aType isEqualToString:@"Apple PICT Graphic"])
    {
		return [canvas PICTData];
    }
	if([aType isEqualToString:@"Encapsulated PostScript (EPS)"])
    {
		return [[(PXCanvasController *)canvasController view] dataWithEPSInsideRect:[[(PXCanvasController *)canvasController view] frame]];
    }
	
	if([aType isEqualToString:@"Game of Life File (LIF)"])
    {
		NSMutableString *fileString = [NSMutableString stringWithString:@"#Life 1.05\r\n#D Generated by "];
		[fileString appendString:[[[NSBundle mainBundle] localizedInfoDictionary] objectForKey:@"CFBundleName"]];
		[fileString appendString:@" "];
		[fileString appendString:[[[NSBundle mainBundle] localizedInfoDictionary] objectForKey:@"CFBundleShortVersionString"]];
		[fileString appendString:@"\r\n#N\r\n#P 0 0\r\n"];
		NSPoint point;
		int spaces=0, i;
		BOOL lineFilled;
		for (point.y=0; point.y<[canvas size].height; point.y++) {
			lineFilled = NO;
			for (point.x=0; point.x<[canvas size].width; point.x++) {
				if ([[canvas colorAtPoint:point] alphaComponent] > .5) {
					for (i=0; i<spaces; i++) {
						[fileString appendString:@"."];
					}
					spaces = 0;
					[fileString appendString:@"*"];
					lineFilled = YES;
				} else {
					spaces++;
				}
			}
			spaces = 0;
			if (!lineFilled) {
				[fileString appendString:@"."];
			}
			[fileString appendString:@"\r\n"];
		}
		
		return [fileString dataUsingEncoding:NSUTF8StringEncoding];		
    }
#else
#warning implement that without Quicktime !!
#endif
	
	return nil;
}

- (BOOL)checkSize:(NSSize)size
{
	if (size.width * size.height <= 256 * 256) {
		return YES;
	}
#ifdef __COCOA__
	return [[NSAlert alertWithMessageText:@"Large Image Warning" defaultButton:@"Yes" alternateButton:@"No" otherButton:nil informativeTextWithFormat:@"This image is %d by %d pixels in size, which is large enough that manipulation might be noticably slow.  Pixen is designed for images under 256 by 256 pixels.  Would you still like to open this image?", (int)size.width, (int)size.height] runModal] == NSOKButton;
#else
#warning GNUstep TODO
	return YES;
#endif
	
}


- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)aType
{
	// Insert code here to read your document from the given data.  You can also choose to override -loadFileWrapperRepresentation:ofType: or -readFromFile:ofType: instead.
	if([aType isEqualToString:@"Pixen Image"])
    {
		PXCanvas *tempCanvas = [NSKeyedUnarchiver unarchiveObjectWithData:data];
		if (![self checkSize:[tempCanvas size]]) {
			return NO;
		}
		[canvas release];
		canvas = [tempCanvas retain];
    }
	/*	else if([aType isEqualToString:@"Photoshop Graphic (PSD)"])
	{
		canvas = [[PXCanvas alloc] initWithPSDData:data];
	} */
	else if([aType isEqualToString:@"Game of Life File (LIF)"]) {
#ifdef __COCOA__
		NSMutableSet *points = [NSMutableSet set];
#else
		NSMutableSet *points = [[NSMutableSet alloc] init];
#warning GNUstep strange error during compilation
#endif
		NSRect rect = NSZeroRect;
		NSArray *lines = [data getLines];
		NSPoint startingPoint;
		NSPoint offset;
		NSEnumerator *lineEnumerator = [lines objectEnumerator];
		NSString *line;
		BOOL firstLine = YES;
		while ( ( line = [lineEnumerator nextObject] ) ) {
			if (firstLine) {
				if (![line isEqualToString:@"#Life 1.05\r"]) {
#ifdef __COCOA__
					[[NSAlert alertWithMessageText:@"Invalid file!" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Only life v1.05 files are supported.  This is a v%@ life file.", [line substringFromIndex:6]] runModal];
#else
#warning GNUstep : TODO
#endif
					return NO;
				}
				firstLine = NO;
				continue;
			}
			
			if ([line length] <= 0) {
				continue;
			}
			
			NSScanner *lineScanner = [NSScanner scannerWithString:line];
			
			if ([lineScanner scanString:@"#" intoString:NULL]) {
				if ([lineScanner scanString:@"P" intoString:NULL]) {
					if (![lineScanner scanFloat:&startingPoint.x]) {
						return NO;
					}
					if (![lineScanner scanFloat:&startingPoint.y]) {
						return NO;
					}
					offset.y = startingPoint.y;
				}
				continue;
			}
			
			int i=0;
			offset.x=startingPoint.x;
			for (i=0; i<[line length]-1; i++) {
				if ([line characterAtIndex:i]=='*') {
					[points addObject:[NSValue valueWithPoint:offset]];
					rect = NSUnionRect(rect, NSMakeRect(offset.x, offset.y, 1, 1));
				}
				offset.x++;
			}
			offset.y++;
		}
		[canvas setSize:rect.size];
		NSEnumerator *pointEnumerator = [points objectEnumerator];
		NSValue *point;
		NSPoint pointValue;
		while ( (point = [pointEnumerator nextObject]) ) {
			pointValue = [point pointValue];
			pointValue.x -= rect.origin.x;
			pointValue.y -= rect.origin.y;
			[[[canvas activeLayer] image] setPixel:[PXPixel withColor:[NSColor blackColor]] atPoint:pointValue]; // so the notification doesn't get sent
		}
	}
	else
    {
		NSImage *image = [[[NSImage alloc] initWithData:data] autorelease];
		if (![self checkSize:[image size]]) {
			return NO;
		}
		[canvas release];
		canvas = [[PXCanvas alloc] initWithImage:image];
    }
	if(canvas)
    {
		[canvasController setCanvas:canvas];
		return YES;
    }
	return NO;
}

- (void)setLayers:layers fromLayers:oldLayers
{
	[canvas setLayers:layers fromLayers:oldLayers];
	//[[[self undoManager] prepareWithInvocationTarget:self] setLayers:oldLayers fromLayers:layers];
	//[canvas setLayers:layers];
	//[canvas setSize:[[layers objectAtIndex:0] size]];
}

- (IBAction)cut:sender
{
	[[self undoManager] beginUndoGrouping];
	[self setLayers:[[canvas layers] deepMutableCopy] fromLayers:[canvas layers]];
	[self copy:sender];
	[self delete:sender];
	[[self undoManager] setActionName:@"Cut"];
	[[self undoManager] endUndoGrouping];
	[canvas changedInRect:NSMakeRect(0, 0, [canvas size].width, [canvas size].height)];
}

- (IBAction)copy:sender
{
	id board = [NSPasteboard generalPasteboard];
	[board declareTypes:[NSArray arrayWithObject:@"PXLayer"] owner:self];	
	if(![[board types] containsObject:@"PXLayer"]) 
	{ 
		[board addTypes:[NSArray arrayWithObject:@"PXLayer"] owner:self]; 
	}
	[board setData:[canvas selectionData] forType:@"PXLayer"];
}

- (IBAction)paste:sender
{
	[[self undoManager] beginUndoGrouping];
	[[self undoManager] setActionName:@"Paste"];
	[self setLayers:[[canvas layers] deepMutableCopy] fromLayers:[canvas layers]];
	[[[self undoManager] prepareWithInvocationTarget:canvasController] canvasSizeDidChange:nil];
	[[self undoManager] endUndoGrouping];
	id board = [NSPasteboard generalPasteboard];	
	if([[board types] containsObject:@"PXLayer"])
	{	
		[canvas pasteFromPasteboard:board type:@"PXLayer"];
	}
	id enumerator = [[NSImage imagePasteboardTypes] objectEnumerator], current;
	while (( current = [enumerator nextObject] ) )
	{
		if ([[board types] containsObject:current])
		{
			[canvas pasteFromPasteboard:board type:@"NSImage"];
		}
	}
	[canvas changedInRect:NSMakeRect(0, 0, [canvas size].width, [canvas size].height)];
}

- (IBAction)delete:sender
{
	if (![canvas hasSelection]) { return; }
	[[self undoManager] beginUndoGrouping];
	[[self undoManager] setActionName:@"Delete"];
	[self setLayers:[[canvas layers] deepMutableCopy] fromLayers:[canvas layers]];
	[[self undoManager] endUndoGrouping];
	[canvas deleteSelection];
	[canvas changedInRect:NSMakeRect(0, 0, [canvas size].width, [canvas size].height)];
}

- (IBAction)selectAll:sender
{
	[canvas selectAll];
	[canvas changedInRect:NSMakeRect(0, 0, [canvas size].width, [canvas size].height)];
}

- (IBAction)selectNone:sender
{
	[[self undoManager] beginUndoGrouping];
	[[self undoManager] setActionName:@"Deselect"];
	[self setLayers:[[canvas layers] deepMutableCopy] fromLayers:[canvas layers]];
	[[self undoManager] endUndoGrouping];
	[canvas deselect];
	[canvas changedInRect:NSMakeRect(0, 0, [canvas size].width, [canvas size].height)];
}

- (void)printShowingPrintPanel:(BOOL)showPanels 
{
	if(printableView == nil) { printableView = [[PXCanvasPrintView viewForCanvas:[self canvas]] retain]; }
	
	float scale = [[[[self printInfo] dictionary] objectForKey:NSPrintScalingFactor] floatValue];
	id transform = [NSAffineTransform transform];
	[transform scaleXBy:scale yBy:scale];
	[printableView setBoundsOrigin:[transform transformPoint:[printableView frame].origin]];
	[printableView setBoundsSize:[transform transformSize:[printableView frame].size]];
	
    NSPrintOperation *op = [NSPrintOperation printOperationWithView:printableView printInfo:[self printInfo]];
    [op setShowPanels:showPanels];
	
#ifdef __COCOA__
	[self runModalPrintOperation:op delegate:nil didRunSelector:NULL contextInfo:NULL];
#else
#warning GNUstep TODO
#endif
}

- canvas
{
	return canvas;
}

@end
