/* SenFormPanelController.h created by ja on Wed 25-Feb-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <AppKit/AppKit.h>
#import "SenFormController.h"

@protocol SenFormsAuxiliaryController

-(void)performSetup;

@end

@interface SenFormPanelController : NSObject <NSCoding>
{
    IBOutlet SenFormController *formController;
    IBOutlet NSWindow *panel;
    id      <SenFormsAuxiliaryController>auxiliaryController;
    BOOL	modal;
    int		modalResult;
    BOOL	isInUse;
}
- (int)showAndRunModal:(BOOL)modal;
- (int)showAndRunModal;
- (void)ok:sender;
- (void)cancel:sender;
- (int) modalResult;

- (NSWindow *)panel;
- (SenFormController *)formController;

- (NSDictionary *)dictionaryValue;
- (void)setDictionaryValue:(NSDictionary *)newValues;
- (void)addValuesFromDictionary:(NSDictionary *)newValues;
- (id)objectValueForKey:(NSString *)aKey;
- (void)setObjectValue:(id)newValue forKey:(NSString *)aKey;

- (BOOL) isInUse;
- (void)setupAuxiliaryController;

@end

@interface SenFormPanelController (NSCoding) <NSCoding>
@end

