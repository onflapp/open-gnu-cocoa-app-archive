//
//  PXImageBackground.m
//  Pixen-XCode
//
//  Created by Joe Osborn on Tue Oct 28 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import "PXImageBackground.h"
#import "PXCanvas.h"

@implementation PXImageBackground

- defaultName
{
    return NSLocalizedString(@"IMAGE_BACKGROUND", @"Image Background");
}

- nibName
{
    return @"PXImageBackgroundConfigurator";
}

- (void)setConfiguratorEnabled:(BOOL)enabled
{
    [browseButton setEnabled:enabled];
    [super setConfiguratorEnabled:enabled];
}

- init
{
    [super init];
    if(![[NSFileManager defaultManager] fileExistsAtPath:[@"~/Library/Application Support/Pixen/Backgrounds/Images/Iso.pxi" stringByExpandingTildeInPath]])
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:[@"~/Library/Application Support/Pixen" stringByExpandingTildeInPath] attributes:nil];
        [[NSFileManager defaultManager] createDirectoryAtPath:[@"~/Library/Application Support/Pixen/Backgrounds" stringByExpandingTildeInPath] attributes:nil];
        [[NSFileManager defaultManager] createDirectoryAtPath:[@"~/Library/Application Support/Pixen/Backgrounds/Images" stringByExpandingTildeInPath] attributes:nil];
        [[NSFileManager defaultManager] copyPath:[[NSBundle mainBundle] pathForResource:@"Iso" ofType:@"pxi"] toPath:[@"~/Library/Application Support/Pixen/Backgrounds/Images/Iso.pxi" stringByExpandingTildeInPath] handler:nil];
    }
    image = [[NSKeyedUnarchiver unarchiveObjectWithFile:[@"~/Library/Application Support/Pixen/Backgrounds/Images/Iso.pxi" stringByExpandingTildeInPath]] retain];
    [self setColor:[NSColor colorWithCalibratedRed:0 green:0 blue:1 alpha:1]];
    return self;
}

- (IBAction)configuratorBrowseForImageButtonClicked:sender
{
    id panel = [NSOpenPanel openPanel];
	// fixed!  I'm reading the document types directly from the Info.plist, though...
	NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
	NSArray *documentTypes = [infoDictionary objectForKey:@"CFBundleDocumentTypes"];
	NSMutableArray *fileExtensions = [NSMutableArray array];
	id enumerator = [documentTypes objectEnumerator], object;
	while  ( ( object = [enumerator nextObject] ) ) {
		[fileExtensions addObjectsFromArray:[object objectForKey:@"CFBundleTypeExtensions"]];
	}
    if([panel runModalForDirectory:[@"~/Library/Application Support/Pixen/Backgrounds/Images" stringByExpandingTildeInPath] file:nil types:fileExtensions] == NSOKButton)
    {
        [self setImage:[PXCanvas withContentsOfFile:[[panel filenames] objectAtIndex:0]]];
        [imageNameField setStringValue:[[[panel filenames] objectAtIndex:0] lastPathComponent]];
    }
}

- (void)setImage:anImage
{
    [anImage retain];
    [image release];
    image = anImage;
    if(![[self name] isEqualToString:[self defaultName]]) { [imageNameField setStringValue:[self name]]; }
    [self changed];
}

- (void)drawRect:(NSRect)rect withinRect:(NSRect)wholeRect withTransform:aTransform onCanvas:aCanvas
{
    //get the appropriate rect in 'canvas coordinates' of aCanvas, not screen ones.
    [aTransform invert];
    NSPoint origin = [aTransform transformPoint:rect.origin];
    NSSize size = [aTransform transformSize:rect.size];
    //match our canvas's frame to the other's.
    id newTransform = [NSAffineTransform transform];
    [newTransform scaleXBy:[aCanvas size].width/[image size].width yBy:[aCanvas size].height/[image size].height];
    [newTransform invert];
    origin = [newTransform transformPoint:origin];
    size = [newTransform transformSize:size];
	origin.x = floorf(origin.x);
	origin.y = floorf(origin.y);
	size.width = ceilf(size.width)+1;
	size.height = ceilf(size.height)+1;
    [newTransform invert];
    [newTransform concat];
    //draw -- we rightly ignore the whole rect parameter, and rather than transform it, we can just say it's zero.
    [self drawRect:NSMakeRect(origin.x, origin.y, size.width, size.height) withinRect:NSZeroRect];    
    //clean up
    [newTransform invert];
    [newTransform concat];
    [aTransform invert];
}

- (void)drawRect:(NSRect)rect withinRect:(NSRect)wholeRect
{
    [super drawRect:rect withinRect:wholeRect];
    [image drawRect:rect fixBug:NO];
    id rgbColor = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    [[NSColor colorWithCalibratedRed:[rgbColor redComponent] green:[rgbColor greenComponent] blue:[rgbColor blueComponent] alpha:.3] set];
    NSRectFillUsingOperation(rect, NSCompositeSourceOver);
}

- copyWithZone:(NSZone *)zone
{
    id copy = [super copyWithZone:zone];
    [copy setImage:image];
    return copy;
}

- (void)encodeWithCoder:coder
{
    [coder encodeObject:image forKey:@"image"];
    [super encodeWithCoder:coder];
}

- initWithCoder:coder
{
    [super initWithCoder:coder];
    [self setImage:[coder decodeObjectForKey:@"image"]];
    return self;
}

@end
