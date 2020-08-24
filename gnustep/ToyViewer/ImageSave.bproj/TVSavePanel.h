//
//  TVSavePanel.h
//  ToyViewer
//
//  Created on Sat Jan 26 2002.
//  Copyright (c) 2001 OGIHARA Takeshi. All rights reserved.
//

#import  <AppKit/NSSavePanel.h>

@class NSString;

@interface TVSavePanel : NSSavePanel {
	id	accessory;
	id	thumbnailSW;
	id	interlaceSW;
	id	suffixButton;
	int	suffixTag;
	BOOL	withThumbnail;
	BOOL	isInteraced;
}

/* Override */
+ (NSSavePanel *)savePanel;

+ (NSString *)nameOfAccessory;
+ (void)setThumbnail:(BOOL)flag;
+ (void)setInterlace:(BOOL)flag;
+ (void)setSuffix:(int)tag;
- (BOOL)withThumbnail;
- (BOOL)interlace;

- (void)loadNib;
- (void)setThumbnailBy:(id)sender;
- (void)setInterlaceBy:(id)sender;

- (NSString *)suffix;
- (void)changeSuffix:(id)sender;
- (void)saveParameters;

@end
