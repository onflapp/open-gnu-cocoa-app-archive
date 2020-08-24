/* CVLUnwrapRequest.m created by stephane on Fri 25-Feb-2000 */
/* Copyright (c) 1997, Sen:te Ltd.  All rights reserved. */

#import "CVLUnwrapRequest.h"
#import "CVLFile.h"
#import <SenFoundation/SenFoundation.h>


static NSString	*unwrapPath = nil;


@interface CVLUnwrapRequest(Private)
+ (void) preferencesChanged:(NSNotification *)notification;
- (id) initWithCVLFile:(CVLFile *)aFile;
@end

@implementation CVLUnwrapRequest

+ (void) initialize
{
    static BOOL	initialized = NO;

    [super initialize];
    if(!initialized){
        initialized = YES;
        [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObject:[[NSBundle mainBundle] pathForResource:@"unwrap" ofType:@"sh"] forKey:@"unwrap"]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(preferencesChanged:) name:@"PreferencesChanged" object:nil];
        [self preferencesChanged:nil];
    }
}

+ (void) preferencesChanged:(NSNotification *)notification
{
    ASSIGN(unwrapPath, [[NSUserDefaults standardUserDefaults] objectForKey:@"unwrap"]);
}

+ (BOOL) unwrapIsValid
{
    return unwrapPath != nil;
}

+ (id) unwrapRequestForWrapper:(NSString *)fileFullPath
{
    CVLFile *aFile = nil;

    aFile = (CVLFile *)[CVLFile treeAtPath:fileFullPath];
    return [[[self alloc] initWithCVLFile:aFile] autorelease];
}

- (id) initWithCVLFile:(CVLFile *)aFile
{
    if(![[self class] unwrapIsValid]){
        [self dealloc];
        return nil;
    }

    if ( (self = [super initWithTitle:@"unwrap"]) ) {
        NSTask	*unwrapTask = [[NSTask alloc] init];

        [unwrapTask setLaunchPath:unwrapPath];
        [self setTask:unwrapTask];
        [unwrapTask release];
        [task setArguments:[NSArray arrayWithObject:[[aFile path] lastPathComponent]]];
        [task setCurrentDirectoryPath:[[aFile path] stringByDeletingLastPathComponent]];
    }
    
    return self;
}

- (NSArray *) modifiedFiles
{
    return [NSArray arrayWithObject:[[[self task] launchPath] stringByAppendingPathComponent:[[[self task] arguments] lastObject]]];
}

@end
