
// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CVLInspector.h"
#import <SenFoundation/SenFoundation.h>

@implementation CVLInspector

+ (CVLInspector *) sharedInstance;
{
    static NSMutableDictionary *sharedInspectors = nil;
    CVLInspector * inspector = nil;
    
    if (sharedInspectors == nil) {
        sharedInspectors = [[NSMutableDictionary alloc] init];
    }

    inspector = [sharedInspectors objectForKey:NSStringFromClass(self)];
    if (inspector == nil) {
        inspector = [[self alloc] init];
        [sharedInspectors setObject:inspector forKey:NSStringFromClass(self)];
        [inspector release];
    }
    return inspector;
}


- init
{
    self = [super init];
    [NSBundle loadNibNamed:NSStringFromClass ([self class]) owner:self];
    if (!view && window) {
        ASSIGN(view, [window contentView]);
    }
    return self;
}


- (NSView *) view
{
    return view;
}


- (NSArray *) inspected
{
    return inspected;
}


- (void) setInspected:(NSArray *) anArray
{
    ASSIGN(inspected, anArray);
    [self update];
}

- (NSString *) firstInspectedFile
    /*" This method returns the path of the first selected workarea file or nil
        if there are none.
    "*/
{
    NSString *aPath = nil;
    
    if ( isNotEmpty(inspected) ) {
        aPath = [inspected objectAtIndex:0];
    }
    return aPath;
}


- (void) update
{
    
}

@end
