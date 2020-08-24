//
//  PrintInfoCtrl.h
//  ToyViewer
//
//  Created by OGIHARA Takeshi on Tue Feb 05 2002.
//  Copyright (c) 2001 OGIHARA Takeshi. All rights reserved.
//

#import <Foundation/NSObject.h>

@class NSPrintInfo, NSPageLayout;

@interface PrintInfoCtrl : NSObject
{
	int	dpi;
	int	margin;
	id	dpiText;
	id	dpiSlider;
	id	marginText;
	id	boxview;
	NSPrintInfo	*printInfo;
	NSPageLayout	*pageLayout;
}

- (id)init;
- (void)runPageLayout:(id)sender;
- (void)changeSlider:(id)sender;
- (void)changeMargin:(id)sender;
- (int)dpiOfPrinter;

@end
