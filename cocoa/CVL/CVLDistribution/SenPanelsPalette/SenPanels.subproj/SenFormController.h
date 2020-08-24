/* SenFormController.h created by ja on Tue 24-Feb-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <AppKit/AppKit.h>

@interface SenFormController : NSObject
{
    NSMutableDictionary *values;
    NSMutableDictionary *controls;
}
+ (SenFormController *)instance;

- (id)objectValue;
- (NSDictionary *)dictionaryValue;
- (void)setDictionaryValue:(NSDictionary *)aDictionary;
- (void)addValuesFromDictionary:(NSDictionary *)aDictionary;
- (id)objectValueForKey:(NSString *)aKey;
- (void)setObjectValue:(id)newValue forKey:(NSString *)aKey;

- (void)setControl:(id)aControl forKey:(NSString *)key;
- (id)controlForKey:(NSString *)key;

- (void)refreshControls;
- (void)refreshControls:(id)sender;
- (void)takeObjectValuesFromAllControls;
- (void)takeObjectValuesFromAllControls:(id)sender;
- (void)takeObjectValueFromSender:(id)sender;
@end

@interface SenFormController (NSCoding) <NSCoding> 
@end