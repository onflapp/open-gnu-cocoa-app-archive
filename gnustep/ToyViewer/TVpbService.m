#import "TVController.h"
#import <Foundation/NSData.h>
#import <Foundation/NSString.h>
#import <Foundation/NSException.h>
#import "NSStringAppended.h"
#import <Foundation/NSFileManager.h>
/*  Debug ... #import <Foundation/NSAutoreleasePool.h>	*/
#import <AppKit/NSApplication.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSPasteboard.h>
#import <AppKit/NSErrors.h>
#import <AppKit/NSErrors.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import "PrefControl.h"
#import "ToyWin.h"
#import "AlertShower.h"
#import "strfunc.h"
#import "common.h"

/*  Program by T. Ogihara
    This code is based on:
	GIFFilter.m, Graphics Interchange Format (GIF) image filter service.
	Author: Michael McCulloch

    2001.04.19  remove Legacy NEXTSTEP PBServices, Sorry.
    2001.06.29  new class for pb owner
*/

#define  ErrorImage	@"pberror.tiff"

@interface PBConvOwner : NSObject  // LOCAL Class
{
	id	controller;
	NSString *filename;
}
- (id)initWithController:(id)obj;
- (void)dealloc;
- (void)setFilename:(NSString *)fname;
- (void)pasteboard:(NSPasteboard *)sender provideDataForType:(NSString *)type;
- (void)pasteboardChangedOwner:(NSPasteboard *)sender;
@end

@implementation PBConvOwner

- (id)initWithController:(id)obj {
	[super init];
	controller = obj;
	filename = nil;
	return self;
}

- (void)dealloc {
	[filename release];
	[super dealloc];
}

- (void)setFilename:(NSString *)fname {
	[filename release];
	filename = [fname retain];
}

- (void)pasteboard:(NSPasteboard *)pasteboard provideDataForType:(NSString *)type
{
	NSData *tiffStream = nil;

	[AlertShower setSuppress: YES];

	if (filename) {
		NSFileManager *manager = [NSFileManager defaultManager];
		if ([manager isReadableFileAtPath:filename])
			tiffStream = [controller openDataFromFile: filename];
	}

	if (tiffStream == nil) {
		NSString *fn = [[controller resource]
			stringByAppendingPathComponent: ErrorImage];
		tiffStream = [NSData dataWithContentsOfFile:fn];
		if (tiffStream == nil) {
			NSLog(@"Error during searching ErrorImage");
			goto ErrEXIT;
		}
	}

	// NSLog(@"tiffStream = 0x%x", (unsigned)tiffStream);

    NS_DURING
	[pasteboard setData:tiffStream forType:NSTIFFPboardType];

    NS_HANDLER
	if ([[localException name]
		isEqualToString: NSPasteboardCommunicationException])
		NSLog(@"Error occurred while converting file %@:", filename);
	else {
		NSLog(@"Error: %@", [localException name]);
		[localException raise];	/* Re-raise the exception */
	}
    NS_ENDHANDLER

ErrEXIT:
	[AlertShower setSuppress: NO];
}

- (void)pasteboardChangedOwner:(NSPasteboard *)sender
{
	[self release];
	/* This object is released here... */
}

@end // PBConvOwner


NSString *getStringFromPB(NSPasteboard *pasteboard, NSString *currentType)
{
	id pp = [pasteboard propertyListForType: currentType];
	if ([pp isKindOfClass:[NSArray class]])
		pp = [pp objectAtIndex: 0];
	if ([pp isKindOfClass:[NSString class]])
		return pp;
	if ([pp isKindOfClass:[NSData class]]) {
		int i;
		char fname[MAXFILENAMELEN];
		const unsigned char *data = [(NSData *)pp bytes];
		int dataLen = [(NSData *)pp length];
		for (i = 0; i < dataLen; i++) {
			if (data[i] == 0 || data[i] == '\t') {
				fname[i] = 0;
				break;
			}
			fname[i] = data[i];
		}
		fname[dataLen] = 0;
		return [NSString stringWithCStringInFS:fname];
	}
	return nil;
}


@implementation TVController (PBService)

static NSMutableArray *pbarray = nil;
static NSMutableArray *sendTypes = nil, *returnTypes = nil;


- (void)registerFilterServiceTypes:(NSString **)typestrs withID:(short *)typeids num:(int)typenum
{
	int	i;

	pbarray = [[NSMutableArray alloc] initWithCapacity: 1];
	for (i = 0; i < typenum; i++){
		switch (typeids[i]) {
		case Type_tiff:
		case Type_eps:
		case Type_bmp:
		case Type_pict:
		case Type_gif:
		case Type_png:
		case Type_jpg:
		case Type_pdf:
			break;
		default:
			[pbarray addObject: NSCreateFilenamePboardType(typestrs[i])];
			break;
		}
	}
}

- (void)prepareServices
{
	[NSApp setServicesProvider:self];
	if ([[PrefControl sharedPref] isUpdatedServices])
		NSUpdateDynamicServices();	// service re-providing
	sendTypes = [[NSMutableArray alloc] initWithCapacity: 5];
	[sendTypes addObject: NSTIFFPboardType];
	[sendTypes addObject: NSPDFPboardType];
	[sendTypes addObject: NSPICTPboardType];
	[sendTypes addObject: NSFilenamesPboardType];
	[sendTypes addObject: NSPostScriptPboardType];
	returnTypes = [[NSMutableArray alloc] initWithCapacity: 3];
	[returnTypes addObject: NSTIFFPboardType];
	[returnTypes addObject: NSPDFPboardType];
	[returnTypes addObject: NSPostScriptPboardType];
	[NSApp registerServicesMenuSendTypes:sendTypes returnTypes:returnTypes];
}

- (id)validRequestorForSendType:(NSString *)typeSent returnType:(NSString *)typeReturned
{
	if (typeReturned != nil) {
		if ([sendTypes containsObject:typeReturned])
			return self;
	}else if ([returnTypes containsObject:typeSent])
		return self;
	return nil;
}


- (void)convertToTIFF:(NSPasteboard *)pasteboard userData:(NSString *)userData error:(NSString **)errorMessage
{
	NSString *currentType, *fn;
	id pbowner = nil;

	/* Note that method "applicationDidFinishLaunching", therefore,
	  method "startSelf" is activated before this method */

	currentType = [pasteboard availableTypeFromArray: pbarray];
	if (!currentType)
		goto ErrEXIT;
	fn = getStringFromPB(pasteboard, currentType);
	if (fn == nil || [fn length] <= 0)
		goto ErrEXIT;
	pbowner = [[PBConvOwner alloc] initWithController: self];
	[pbowner setFilename: fn];
	[pasteboard declareTypes:[NSArray arrayWithObject:NSTIFFPboardType]
		owner:pbowner];
	/* pbowner will release self in the method pasteboardChangedOwner: */

	return;

ErrEXIT:
	NSLog(@"Error occurred during filter service");
}


- (void)openImageFromPasteboard:(NSPasteboard *)pasteboard userData:(NSString *)userData error:(NSString **)errorMessage
{
	[self readSelectionFromPasteboard:pasteboard];
}

@end
