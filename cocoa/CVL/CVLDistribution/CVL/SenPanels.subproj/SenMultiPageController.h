
// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <AppKit/AppKit.h>

@class SenFormPanelController;

@interface SenMultiPageController : NSObject <NSCoding>
{
    IBOutlet NSView *swappableView;
    IBOutlet NSPopUpButton *popup;
    SenFormPanelController *currentPageController;
    NSMutableArray *pageControllers;
}
- (void)setDictionaryValue:(NSDictionary *)aDictionaryValue;
- (NSDictionary *)dictionaryValue;
- (void)addValuesFromDictionary:(NSDictionary *)newValues;
- (id)objectValueForKey:(NSString *)aKey;
- (void)setObjectValue:(id)newValue forKey:(NSString *)aKey;

- (void)refreshControls;
- (void)refreshControls:(id)sender;
- (void)takeObjectValuesFromAllControls;
- (void)takeObjectValuesFromAllControls:(id)sender;

- (void)switchPage:(id)sender;
@end

@interface SenMultiPageController (NSCoding) <NSCoding>
@end