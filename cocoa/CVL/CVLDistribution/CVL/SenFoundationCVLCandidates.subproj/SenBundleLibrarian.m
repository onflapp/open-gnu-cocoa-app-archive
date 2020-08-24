
// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "SenBundleLibrarian.h"
#import "NSBundle_CVLAdditions.h"

static NSMutableArray *_bundleArray = nil;

@implementation SenBundleLibrarian

+ (void) initialize
{
    if ([self class] == [SenBundleLibrarian class]) {
        if(!_bundleArray) {
            _bundleArray = [[NSMutableArray alloc] init];
        }
    }
}


+ (void) addBundlesInPath:(NSString *)path withExtension:(NSString *)extension
{
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:path];
    NSString *filename = nil;
    NSBundle *newBundle = nil;

    while ( (filename = [enumerator nextObject]) ) {
        // Do not look in to the sub-directories.
        [enumerator skipDescendents];
        if ([[filename pathExtension] isEqualToString:extension]) {
            newBundle = [[[NSBundle alloc] initWithPath: [NSString stringWithFormat:@"%@/%@", path, filename]] autorelease];

            if(!newBundle)
                // We MUST check this, because it may happen that NSBundle couldn't create the bundle!
                // Mail to cvl-feedback, from A. Palubitzky on Sept 10 1999 and followings.
                continue;
            if(![_bundleArray containsObject:newBundle]) {
                [_bundleArray addObject:newBundle];
            }
       }
    }
}

+ (void) addBundlesInPath:(NSString *)path
{
    [self addBundlesInPath:path withExtension:@"bundle"];
}

+ (void) setup
    /*
       * Installs the class lookup error handling function for automatic
       * bundle loading.  This method also registers bundles found in the
       * following directories:
       *    ~/Library/Bundles
       *    /LocalLibrary/Bundles
       *    <Path to Executable>/<AppName>.app/Resources
       *    /NextLibrary/Bundles
       */
{
    static BOOL alreadySetup = NO;

    if(!alreadySetup) {
        // Stephane: we should use now the new search path utility functions...
        [self addBundlesInPath: [NSString stringWithFormat:@"%@/Library/Bundles", NSHomeDirectory()]];
        [self addBundlesInPath:[NSString stringWithFormat:@"/LocalLibrary/Bundles"]];
        [self addBundlesInPath:[[NSBundle mainBundle] builtInPlugInsPath]];
        [self addBundlesInPath:[NSString stringWithFormat:@"/NextLibrary/Bundles"]];
        alreadySetup = YES;
    }
}


+ (NSArray *) bundlesWithValue:(NSString *)value forString:(NSString *)key
    /*
       * Returns an NSArray of RZBundle instances whose 'info.dict' file contain
       * the key/value pair: "key" = "value".
       */
{
    NSMutableArray *array = nil;
    NSEnumerator *bundles;
    NSBundle *bundle;

    [self setup];
    bundles = [_bundleArray objectEnumerator];

    while ( (bundle = [bundles nextObject]) ) {
        if([value isEqual:[bundle objectForKey:key]]) {
            if(!array) {
                array = [NSMutableArray array];
            }
            [array addObject:bundle];
        }
    }
    return array;		
}

+ (NSArray *) bundlesWithKeyValues:(NSDictionary *) aDictionary
{
    NSMutableArray *array = nil;
    NSEnumerator *bundles;
    NSBundle *bundle;

    bundles = [_bundleArray objectEnumerator];

    while ( (bundle = [bundles nextObject]) ) {
        NSEnumerator *keyEnumerator = [aDictionary keyEnumerator];
        NSString *key;
        while ( (key = [keyEnumerator nextObject]) ) {
            if(![[aDictionary objectForKey:key] isEqual:[bundle objectForKey:key]]) {
                break;
            }
        }
        if (!key) {
            if (!array) {
                array = [NSMutableArray array];
            }
            [array addObject:bundle];
        }
    }
    return array;		
}



+ (NSArray *) valuesForString:(NSString *) key
    /*
     * Returns as an NSArray the union of the values found for key in all bundles.
     */
{
    NSMutableArray *array = nil;
    NSEnumerator *bundles;
    NSBundle *bundle;
    id value;

    [self setup];
    bundles = [_bundleArray objectEnumerator];

    while ( (bundle = [bundles nextObject]) ) {
        if ( (value = [bundle objectForKey:key]) ) {
            if(!array) {
                array = [NSMutableArray array];
            }
            if ([value isKindOfClass:[NSArray class]]) {
                NSEnumerator *valueEnumerator = [value objectEnumerator];
                id v;
                while ( (v = [valueEnumerator nextObject]) ) {
                    [array addObject:v];
                }
            }
            else {
                [array addObject:value];
            }
        }
    }
    return array;		
}

@end
