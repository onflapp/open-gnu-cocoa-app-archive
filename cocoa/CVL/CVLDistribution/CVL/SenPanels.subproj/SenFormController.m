/* SenFormController.m created by ja on Tue 24-Feb-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "SenFormController.h"
#import <SenFoundation/SenFoundation.h>

static SenFormController *instance=nil;

@interface SenFormController (Private)
@end

@implementation SenFormController
+ (SenFormController *)instance
{
    if (!instance) {
        instance=[[self alloc] init];
    }
    return instance;
}

- (id)init
{
    if ( (self=[super init]) ) {
        values=[[NSMutableDictionary alloc] init];
        controls=[[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc
{
    RELEASE(values);
    RELEASE(controls);

    [super dealloc];
}

- (void)awakeFromNib
{
    [self refreshControls];
}

- (id)objectValue
{
    return values;
}

- (void)setDictionaryValue:(NSDictionary *)aDictionary;
{
    [values setDictionary:aDictionary];
    [self refreshControls];
}

- (void)addValuesFromDictionary:(NSDictionary *)aDictionary
{
    [values addEntriesFromDictionary:aDictionary];
    [self refreshControls];
}

- (void)setObjectValue:(id)newValue forKey:(NSString *)aKey
{    
    SEN_ASSERT_NOT_EMPTY(aKey);
    
    if ( newValue != nil ) {
        [values setObject:newValue forKey:aKey];
    } else {
        [values removeObjectForKey:aKey];
    }
    [self refreshControls];
}

- (NSDictionary *)dictionaryValue
{
    return values;
}

- (id)objectValueForKey:(NSString *)aKey
{
    id aValue = nil;

    SEN_ASSERT_NOT_EMPTY(aKey);

    aValue = [values objectForKey:aKey];

    return aValue;
}

- (void)setControl:(id)aControl forKey:(NSString *)key
{
    if ( (aControl != nil) && (key != nil) ) {
        [controls setObject:aControl forKey:key];
    }
}

- (id)controlForKey:(NSString *)key
{
    return [controls objectForKey:key];
}

- (void)refreshControls:(id)sender
{
    [self refreshControls];
}

- (void)refreshControls
{
    id enumerator;
    NSString *key;
    NSControl *control;
    id value = nil;

    enumerator=[controls keyEnumerator];
    while ( (key=[enumerator nextObject]) ) {
        control=(NSControl *)[controls objectForKey:key];
        if ( (value=[values objectForKey:key]) ) {
            [control setObjectValue:value];
        }
    }
}

- (void)takeObjectValuesFromAllControls:(id)sender
{
    [self takeObjectValuesFromAllControls];
}

- (void)takeObjectValuesFromAllControls
{
    id enumerator;
    NSString *aKey;
    NSCell *cell;
    NSControl *aControl = nil;
    id aValue = nil;

    enumerator=[controls keyEnumerator];
    while ( (aKey=[enumerator nextObject]) ) {
        aControl = [controls objectForKey:aKey];
        if([aControl respondsToSelector:@selector(selectedCell)]){
            cell = [aControl selectedCell];
            // Added a check for nil objects. This prevents the crash that
            // happened when the user clicks on the OK button in the Modules 
            // window without having selected any modules and then types in a 
            // module name by hand and then enters a workarea path and then clicks on
            // the Checkout button. There still must be something wrong in the
            // class ModuleChoiceController that is making the objectValue of
            // the date field (in the CvsCheckoutModulePanel nib) nil in the 
            // above situation.
            // William Swats  23-July-2003
            if ( (cell != nil) && [cell hasValidObjectValue] ) {
                aValue = [cell objectValue];
                if ( aValue != nil ) {
                    [values setObject:aValue forKey:aKey];
                } else {
                    [values removeObjectForKey:aKey];
                }
            } else {
                [values removeObjectForKey:aKey];
            }
        }
    }
}

- (void)takeObjectValueFromSender:(id)sender
{
    if ([sender isKindOfClass:[NSCell class]]) {
        NSControl *control=(NSControl*)[sender controlView];
        id keysEnumerator;
        NSString *key;
        NSArray *allKeys = nil;
        id aValue = nil;

        if ( control == nil ) return;
        if ([sender hasValidObjectValue]) {
            if( [sender respondsToSelector:@selector(objectValue)] ) {
                aValue = [sender objectValue];
                allKeys = [controls allKeysForObject:control];
                if ( isNotEmpty(allKeys) ) {
                    keysEnumerator=[allKeys objectEnumerator];
                    while ( (key=[keysEnumerator nextObject]) ) {
                        if ( aValue != nil ) {
                            [values setObject:aValue forKey:key];
                        } else {
                            [values removeObjectForKey:key];
                        }
                    }                        
                }                
            }
        }
    }
}

- (id)initWithCoder:(NSCoder *)decoder
{
    int		version;
   
    self = [self init];
    
    version = [decoder versionForClassName:@"SenFormController"];
    /*
    switch (version) {
    case 0:
        break;
    default:
        break;
    } */
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    //[super encodeWithCoder:coder];

    // Version == 1
}

- (NSString *)description
{
    return [[super description] stringByAppendingString:[NSString stringWithFormat:@"{ controls = %@, \nvalues = %@ }",controls,values]];
}

- (void)control:(NSControl *)aControl didFailToValidatePartialString:(NSString *)aString errorDescription:(NSString *)anError
    /*" This method allows us to present an error panel to user if he starts to 
        enter incorrect data according to some formatter.
    "*/
{
    NSString *aTitle = nil;
    NSString *aKey = @"Unknown Control";
    NSArray *allKeys = nil;
    
    SEN_ASSERT_NOT_NIL(aControl);
    
    allKeys = [controls allKeysForObject:aControl];
    
    if ( isNotEmpty(allKeys) ) {
        SEN_ASSERT_CONDITION(([allKeys count] <= 1));
        aKey = [allKeys objectAtIndex:0];
    }
    aTitle = [NSString stringWithFormat:@"%@ Formatting Error", aKey];
    (void)NSRunAlertPanel(aTitle, anError, nil, nil, nil);
}


@end
