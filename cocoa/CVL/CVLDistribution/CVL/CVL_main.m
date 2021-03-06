/* Generated by the NeXT Project Builder 
   NOTE: Do NOT change this file -- Project Builder maintains it.
*/

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <AppKit/AppKit.h>
#import <SenFoundation/SenFoundation.h>

int main(int argc, const char *argv[]) {
    NSAutoreleasePool	*aPool						= nil;
	NSArray				*theLaunchedApplications	= nil;
	NSDictionary		*anApp						= nil;
	NSEnumerator		*anEnumerator				= nil;
	NSString			*anAppName					= nil;
	int					 aCounter					= 0;
	
	aPool = [[NSAutoreleasePool alloc] init];

	// Only allow one instance of the CVL app to be launched per logged-in user.
	theLaunchedApplications = [[NSWorkspace sharedWorkspace] launchedApplications];
	if ( isNotEmpty(theLaunchedApplications) ) {
		anEnumerator = [theLaunchedApplications objectEnumerator];
		while ( (anApp = [anEnumerator nextObject]) ) {
			anAppName = [anApp objectForKey:@"NSApplicationName"];
			if ( [anAppName isEqualToString:@"CVL"] == YES ) {
				aCounter++;
				if ( aCounter > 1 ) {
					NSRunAlertPanel([[NSProcessInfo processInfo] processName], 
									@"Another copy of CVL is already running. Only one copy of CVL per user can run at a time. This copy will terminate.", 
									nil, nil, nil);
					exit(0);					
				}
			}
		}
	}

    if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"SenLogCheckpoints"] ) { 
        SenLogCheckpoint( ([NSString stringWithFormat:
                     @"Checkpoint occurred in file %s:%d.",
                    __FILE__, __LINE__]) );
    }
    [aPool release];

    return NSApplicationMain(argc, argv);
}

