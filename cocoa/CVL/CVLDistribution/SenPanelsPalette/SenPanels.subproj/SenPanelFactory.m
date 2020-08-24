/* SenPanelFactory.m created by ja on Wed 25-Feb-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "SenPanelFactory.h"
#import "_NibOwner.h"
#import <SenFoundation/SenFoundation.h>

static SenPanelFactory *sharedPanelFactory=nil;

static NSString *PlatformNibKey=@"OPENSTEP nib";

@interface SenPanelFactory (Private)
- (id)initWithDefaultRessourceFile;
- (void)registerPanelWithHandle:(id)aController withName:(NSString *)panelName;
@end

@interface NSObject(SenPanel)
- (BOOL) isInUse;
@end

@implementation SenPanelFactory
+ (SenPanelFactory *)sharedPanelFactory
{
    if (!sharedPanelFactory) {
        sharedPanelFactory=[[self alloc] initWithDefaultRessourceFile];
    }
    return sharedPanelFactory;
}

- (id)init
{
    if ( (self=[super init]) ) {
        panels=[[NSMutableDictionary alloc] init];
    }
    return self;
}

- (id)initWithDefaultRessourceFile
{
    if ( (self=[self init]) ) {
        properties=[[NSDictionary alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Panels" ofType:@"plist"]];
        if (!properties) {
            NSString *aMsg = [NSString stringWithFormat:
                @"Warning: cannot open panels property list"];
            SEN_LOG(aMsg);                                
        }
    }
    return self;
}

- (void)registerPanelWithHandle:(id)aController withName:(NSString *)panelName
{
    SEN_ASSERT_NOT_NIL(aController);
    SEN_ASSERT_NOT_EMPTY(panelName);
    [panels setObject:aController forKey:panelName];
}

- (id) handleOfPanelWithName:(NSString *)panelName
{
    id				panelOwner;
    _NibOwner		*owner;
    NSDictionary	*panelProperties;
    NSString		*nibName;

    if((panelOwner = [panels objectForKey:panelName])){
        if(![panelOwner respondsToSelector:@selector(isInUse)] || ![panelOwner isInUse])
            return panelOwner;
    }

    if((panelProperties = [properties objectForKey:panelName])){
        nibName = [panelProperties objectForKey:PlatformNibKey];
        if(!nibName)
            nibName = [panelProperties objectForKey:@"nib"];

        if(nibName){
            owner = [[[_NibOwner alloc] init] autorelease];
            if([NSBundle loadNibNamed:nibName owner:owner]){
                [self registerPanelWithHandle:[owner handle] withName:panelName];
                if([[owner handle] respondsToSelector:@selector(awakeWithProperties:)])
                    [[owner handle] awakeWithProperties:panelProperties];

                return [[owner handle] autorelease];
            }
            else
                NSLog(@"Warning: failed to read nib for panel with name:%@", panelName);
        }
        NSLog(@"Warning: don't know how to instantiate panel with name:%@", panelName);
    }
    else
        NSLog(@"Warning: cannot find panels with name:%@",panelName);

    return nil;
}

@end
