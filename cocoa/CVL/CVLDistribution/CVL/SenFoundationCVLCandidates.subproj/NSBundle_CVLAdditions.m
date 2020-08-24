
// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "NSBundle_CVLAdditions.h"

@implementation NSBundle (CVLAdditions)

- (NSDictionary *) localizedInfoDictionary
{
    NSString *path = [self pathForResource:@"LocalizedInfo" ofType:@"plist"];
    volatile NSDictionary *localizedInfoDictionary = nil;
    NS_DURING
        localizedInfoDictionary = [[NSString stringWithContentsOfFile:path] propertyList];
    NS_HANDLER
        localizedInfoDictionary = nil;
        [localException raise];
    NS_ENDHANDLER
    return (NSDictionary *)localizedInfoDictionary;
}


- (id) objectForKey:(NSString *) key
{
    NSObject *result = [[self localizedInfoDictionary] objectForKey:key];
    
    if (result == nil) {
        result = [[self infoDictionary] objectForKey:key];
    }
    return result;
}
@end
