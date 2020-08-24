/* CvsRemoteRepository.m created by ja on Wed 11-Mar-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CvsRemoteRepository.h"
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <AGRegex/AGRegexes.h>


@implementation CvsRemoteRepository
+ (NSString *)rootForProperties:(NSDictionary *)properties
{
    NSString *theMethod,*theUser,*theHost,*theRepositoryPath, *thePort;

    theMethod=[properties objectForKey:METHOD_KEY];
    theUser=[properties objectForKey:USER_KEY];
    theHost=[properties objectForKey:HOST_KEY];
    theRepositoryPath=[properties objectForKey:PATH_KEY];
    thePort = [properties objectForKey:PORT_KEY];
    if(theRepositoryPath && ![theRepositoryPath hasPrefix:@"/"]){
        // Let's check that the path is an ABSOLUTE one!
        // If we don't and it is not, repository will create an absolutely ;-)
        // awful checkoutDir!!!
        // WARNING: we cannot use method -[NSString isAbsolute], because on NT
        // it checks for backslashes!!! 
		// WARNING: on NT, path can contain drive letter!!
        if(!([theRepositoryPath length] > 2 && [theRepositoryPath characterAtIndex:1] == ':' && [theRepositoryPath characterAtIndex:2] == '/'))
           theRepositoryPath = [@"/" stringByAppendingString:theRepositoryPath];
	}

    if (theMethod && theUser && theHost && theRepositoryPath) {
        NSString    *portString = ([thePort intValue] > 0 ? [NSString stringWithFormat:@"%d", [thePort intValue]]:@"");
        
		if ([theUser isEqual:@""]) {
			return [NSString stringWithFormat:@":%@:%@:%@%@",theMethod,theHost, portString,theRepositoryPath];
		} else {
			return [NSString stringWithFormat:@":%@:%@@%@:%@%@",theMethod,theUser,theHost, portString,theRepositoryPath];
		}
    } else {
        return nil;
    }
}

- initWithMethod:(NSString *)theMethod root:(NSString *)repositoryRoot
{
    BOOL validRootString=NO;
    NSArray *matchingResult;
    user=host=path=nil;
    port = 0;
    
    if ( (self=[super initWithMethod:theMethod root:repositoryRoot]) ) {
		//  Old format: [user@]host:[port]/path Aencoded_password
		//  New format: user@host:port/path Aencoded_password
		// See how cvs parses it in src/root.c, parse_cvsroot().
		matchingResult = [repositoryRoot findAllSubPatternMatchesWithPattern:@"^:(\\w*):(\\w+)@([0-9a-zA-Z_\\-\\.]+):(\\d*)?(/.*)$" options:AGRegexMultiline];
		if([matchingResult count] == 5){
			id  aValue;
			
			user=[[matchingResult objectAtIndex:1] retain];
			host=[[matchingResult objectAtIndex:2] retain];
			aValue = [matchingResult objectAtIndex:3];
			if([aValue isKindOfClass:[NSString class]]) // Could be NSNull
				port=[aValue intValue];
			path=[[matchingResult objectAtIndex:4] retain];
			validRootString=YES;
		}
		else{// try without user
			matchingResult=[repositoryRoot findAllSubPatternMatchesWithPattern:@"^:(\\w*):([0-9a-zA-Z_\\-\\.]+):(\\d*)?(/.*)$" options:AGRegexMultiline];
			if([matchingResult count] == 4){
				id  aValue;
				
				user=@"";
				host=[[matchingResult objectAtIndex:1] retain];
				aValue = [matchingResult objectAtIndex:2];
				if([aValue isKindOfClass:[NSString class]]) // Could be NSNull
					port=[aValue intValue];
				path=[[matchingResult objectAtIndex:3] retain];
				validRootString=YES;
			}
		}
        if (!validRootString) {
            NSRunAlertPanel(@"Cvs Repository Problem", 
                @"The repository root string \"%@\" is invalid. We will ignore this repository.",
                nil, nil, nil, repositoryRoot);
            [self release];
            return nil;
        }
    }

    return self;
}

- initWithProperties:(NSDictionary *)properties
{
    NSString *theMethod,*theUser,*theHost,*theRepositoryPath, *thePort;

    theMethod=[properties objectForKey:METHOD_KEY];
    theUser=[properties objectForKey:USER_KEY];
    theHost=[properties objectForKey:HOST_KEY];
    theRepositoryPath=[properties objectForKey:PATH_KEY];
    thePort=[properties objectForKey:PORT_KEY];

    if ( (self=[super initWithMethod:theMethod root:[[self class] rootForProperties:properties]]) ) {
        user=[theUser retain];
        host=[theHost retain];
        path=[theRepositoryPath retain];
        if(thePort && [thePort intValue] > 0)
            port = [thePort intValue];
    }
    return self;
}

- (NSDictionary *)properties
{
	NSMutableDictionary	*properties = [NSMutableDictionary dictionaryWithObjectsAndKeys:method, METHOD_KEY, host, HOST_KEY, path, PATH_KEY, user, USER_KEY, nil];
    
	if(port > 0)
		[properties setObject:[NSString stringWithFormat:@"%u", port] forKey:PORT_KEY];
    else
        // We NEED to always all the key-value pairs!    
		[properties setObject:@"" forKey:PORT_KEY];
    return properties;
}

- (void)dealloc
{
    [user release];
    [host release];

    [super dealloc];
}

- (NSString *) username
{
    return user;
}


@end
