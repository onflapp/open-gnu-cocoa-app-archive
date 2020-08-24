//
//  J2kSavePanel.h
//  ToyViewer
//
//  Created on Sat Aug 03 2002.
//  Copyright (c) 2002 Takeshi Ogihara. All rights reserved.
//

#import  "TVSavePanel.h"
#import  "J2kParams.h"

@class NSString;

@interface J2kSavePanel : TVSavePanel
{
	id	J2kSlider;
	id	J2kText;
	id	formatKindButton;
	id	losslessButton;
	id	progKindButton;
	int	progKindTag;
	int	formatKindTag;
}

+ (void)initialize;
+ (NSString *)nameOfAccessory;
+ (void)setSuffix:(int)tag;
+ (void)setFormatKind:(int)tag;
+ (void)setProgressiveKind:(int)tag;

- (void)loadNib;
- (void)changeRate:(id)sender;
- (void)changeFormatKind:(id)sender;
- (void)changeProgressiveKind:(id)sender;
- (void)changeLossless:(id)sender;
- (int)formatKind;
- (int)progressiveKind;
- (float)compressRate;
- (NSString *)suffix;
- (void)saveParameters;

@end
