/* CvsPserverRepository.m created by ja on Mon 16-Feb-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CvsPserverRepository.h"
#import "RepositoryProperties.h"

#import <CvsLoginRequest.h>
#import <Foundation/Foundation.h>
#import <SenFoundation/SenFoundation.h>
#import <AGRegex/AGRegexes.h>


@interface CvsPserverRepository (Private)
- (BOOL) hasPermanentPassword;
- (void)loginEnded:(NSNotification *)notification;
@end

@implementation CvsPserverRepository


- initWithMethod:(NSString *)theMethod root:(NSString *)repositoryRoot
{
    if ( (self=[super initWithMethod:theMethod root:repositoryRoot]) ) {
        if ([self hasPermanentPassword]) {
            isLoggedIn=YES;
        }
    }

    return self;
}

- initWithProperties:(NSDictionary *)properties
{
    NSString*thePassword;

    if ( (self=[super initWithProperties:properties]) ) {
        thePassword=[properties objectForKey:PASSWORD_KEY];
        if (thePassword && ![thePassword isEqual:@""]) {
            password=[thePassword retain];
        } else {
            if ([self hasPermanentPassword]) {
                isLoggedIn=YES;
            }
        }
    }
    return self;
}

- (void)dealloc
{
    [password release];
    [loginRequest release];

    [super dealloc];
}

- (id) init
{
    self= [super init];
    isLoggedIn= NO;

    return self;
}

- (NSDictionary *)properties
{
	NSMutableDictionary	*properties = [NSMutableDictionary dictionaryWithDictionary:[super properties]];
    
	if(password == nil)
        password = @""; // We NEED to always all the key-value pairs!
    [properties setObject:password forKey:PASSWORD_KEY];
    
    return properties;
}

- (BOOL)needsLogin
{
    return YES;
}

- (void)setIsLoggedIn:(BOOL)flag
{
    if (isLoggedIn!=flag) {
        isLoggedIn=flag;
        if (!isLoggedIn) {
            [password release];
            password=nil;
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:@"RepositoryChanged" object:self];
    }
}

- (BOOL)isReadyForRequests
{
    return isLoggedIn;
}

- (BOOL)isLoggedIn
{
    return isLoggedIn;
}

- (Request *)gettingReadyRequest
{
    return [self loginRequest];
}

- (Request *)loginRequest
{
    if (isLoggedIn) {
        return nil;
    } else {
        if (!loginRequest) {

            loginRequest=[CvsLoginRequest cvsLoginRequestForRepository:self];
            if (password) {
                [(CvsLoginRequest *)loginRequest setPassword:password];
            }
            [[NSNotificationCenter defaultCenter]
                          addObserver:self
                             selector:@selector(loginEnded:)
                                 name:@"RequestCompleted"
                               object:loginRequest];
            [loginRequest schedule];
            [loginRequest retain];
        }
        return loginRequest;
    }
}

- (void)loginEnded:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter]
                  removeObserver:self
                         name:@"RequestCompleted"
                       object:loginRequest];
    [loginRequest release];
    loginRequest=nil;
}

- (BOOL) hasPermanentPassword
    /*" This method returns YES if a .cvspass file exists in the user's home
        directory and if it contains an entry for the pserver repository that 
        this instance stands for; otherwise NO is returned.
    "*/
{
    NSString				*mContent				= nil;
    NSString				*aPath					= nil;
    NSFileManager			*fileManager			= nil;
	RepositoryProperties	*aRepositoryProperties	= nil;
	NSEnumerator			*lineEnum				= nil;
	NSArray					*linesArray				= nil;
	NSString				*lineString				= nil;
	NSString				*aCopy					= nil;
	NSString				*aRepositoryRoot		= nil;
	NSArray					*wordsFromLine			= nil;
	NSString				*myRepositoryRoot		= nil;
	NSString				*aRepositoryRootWithoutPort		= nil;
	
    aPath = [[self homeDirectory] stringByAppendingPathComponent:@".cvspass"];
    // Check first to see if path exists.
    fileManager = [NSFileManager defaultManager];
    if ( [fileManager senFileExistsAtPath:aPath]  == NO ) {
		return NO;
	}
	
	mContent = [NSString stringWithContentsOfFile:aPath];
	// Test to see if we could actually read the file.
	if( mContent == nil ) {
		// Could not since mContent was nil.
		NSString *aTitle = nil;
		NSString *aMessage = nil;
		
		aTitle = [NSString stringWithFormat:@"CVL Warning"];
		aMessage = [NSString stringWithFormat:
			@"The CVS .cvspass file \"%@\" could not be opened for reading.",
			aPath];
		(void)NSRunAlertPanel(aTitle, aMessage, nil, nil, nil);    
		return NO;
	}
	
	// Remove empty lines.
	aCopy = [mContent replaceMatchesOfPattern:@"\\s+\\n" 
								 withString:@"" 
									options:0];
	linesArray = [aCopy splitStringWithPattern:@"\\n" 
									   options:0];
	lineEnum = [linesArray objectEnumerator];
	myRepositoryRoot = [self root];
	while ( (lineString = [lineEnum nextObject]) ) {
		// In newest cvs versions (1.11.x, in Tiger), the format of the .cvspass
		// file has changed. Lines can begin with a '/1 ' sequence
		//  Old format: [user@]host:[port]/path Aencoded_password
		//  New format: /1 user@host:port/path Aencoded_password
		// Old and new formats can be merged in the same file
		// Look at password_entry_parseline() in src/login.c of cvs sources
		lineString = [lineString replaceMatchesOfPattern:@"^/\\d+\\D" withString:@"" options:0];
		wordsFromLine = [lineString splitStringWithPattern:@"\\s" 
												   options:0];
		if ( [wordsFromLine count] >= 2 ) {                    
			aRepositoryRoot = [wordsFromLine objectAtIndex:0];
			if ( [myRepositoryRoot isEqualToString:aRepositoryRoot] == YES ) {
				return YES;
			} else {
				// Maybe there is a port number in the entry in the .cvspass file.
				// Lets parse the entry and then strip out the port number
				// and try again.
				aRepositoryProperties = [RepositoryProperties 
										parseRepositoryRoot:aRepositoryRoot];
				aRepositoryRootWithoutPort = [aRepositoryProperties 
													repositoryRootWithoutPort];
				if ( [myRepositoryRoot isEqualToString:aRepositoryRootWithoutPort] == YES ) {
					return YES;
				} else {
				}
			}
		}
	}
    return NO;
}


@end
