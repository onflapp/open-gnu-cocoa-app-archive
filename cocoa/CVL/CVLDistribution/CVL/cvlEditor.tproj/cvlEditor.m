
// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/Foundation.h>
#import <CVLEditorClient.h>


int main(int argc, const char *argv[])
{
    NSAutoreleasePool					*pool = [[NSAutoreleasePool alloc] init];
    NSArray								*args = [[NSProcessInfo processInfo] arguments];
    NSDistantObject <CVLEditorClient>	*proxy = nil;
    NSString                            *aTemplateFile = nil;
    int									exitCode = 0;
    
    if ( [args count] != 2 ) {
        NSLog(@"cvlEditor must have exactly one argument (in addition to the executable pathname which is always included) a template filename. This error usually occurs because the executable cvlEditor is being launched by Xcode instead of launching CVL.app. The arguments were %@.", [args description]);
        exitCode = 2;
        goto myEnd;
    }    
	proxy = [NSConnection rootProxyForConnectionWithRegisteredName:CVLEditorClientConnectionName host:nil]; // Search only on localhost
    if(!proxy){
        NSLog(@"cvlEditor couldn't get rootProxy for local connection %@", CVLEditorClientConnectionName);
        exitCode = 1;
        goto myEnd;
    }
    [proxy setProtocolForProxy:@protocol(CVLEditorClient)];
    aTemplateFile = [args lastObject];
    if(![proxy showCommitPanelWithSelectedFilesUsingTemplateFile:aTemplateFile])
        exitCode = -1;

myEnd:
    [pool release];
    exit(exitCode);
    return exitCode;
}
