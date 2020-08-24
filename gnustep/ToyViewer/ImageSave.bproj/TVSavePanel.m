//
//  TVSavePanel.m
//  ToyViewer
//
//  Created on Sat Jan 26 2002.
//  Copyright (c) 2001 OGIHARA Takeshi. All rights reserved.
//

#import  "TVSavePanel.h"
#import  <Foundation/NSString.h>
#import  <Foundation/NSBundle.h>
#import  <AppKit/NSNibLoading.h>
#import  <AppKit/NSControl.h>
#import  "ImageSave.h"

static BOOL withThumbnailSV = NO;
static BOOL isInteracedSV = NO;

@implementation TVSavePanel

/* Override */
+ (NSSavePanel *)savePanel
{
	NSSavePanel *newpanel = [super savePanel];
	[(TVSavePanel *)newpanel loadNib];
	return newpanel;
}

+ (NSString *)nameOfAccessory { return @"SaveAccessory.nib"; }

+ (void)setThumbnail:(BOOL)flag { withThumbnailSV = flag; }
+ (void)setInterlace:(BOOL)flag { isInteracedSV = flag; }
+ (void)setSuffix:(int)tag { /* Abstract */ }

- (BOOL)withThumbnail { return withThumbnail; }
- (BOOL)interlace { return isInteraced; }

- (void)loadNib
{
	if ([self accessoryView] == nil) {
		[NSBundle loadNibNamed:[[self class] nameOfAccessory]
			owner:self];
		[self setAccessoryView:[accessory contentView]];
	}
	[thumbnailSW setState: (withThumbnail = withThumbnailSV)];
	[interlaceSW setState: (isInteraced = isInteracedSV)];
}

- (void)setThumbnailBy:(id)sender {
	withThumbnail = [sender state];
	[[self class] setThumbnail: withThumbnail];
}

- (void)setInterlaceBy:(id)sender {
	isInteraced = [sender state];
	[[self class] setInterlace: isInteraced];
}

/* Abstract */
- (NSString *)suffix { return @"Toy"; }

/* NOTE: This method uses "_form", which is an instance variable of
   superclass NSSavePanel.  Be careful. */
- (void)changeSuffix:(id)sender
{
	NSString *name;

	suffixTag = [suffixButton selectedTag];
	[[self class] setSuffix: suffixTag];
	name = [_form stringValue];
	if (name == nil || [name length] == 0)
		return;
	name = [ImageSave tmpPath: name ext: [self suffix]];
	[_form setStringValue: name];
}

/* Abstract */
- (void)saveParameters { }

@end
