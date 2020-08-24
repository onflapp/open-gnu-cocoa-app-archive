/* CVLAvatar.m created by phink on Mon 26-Apr-1999 */

// Copyright (c) 1997-2000, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CVLAvatar.h"
#import <ProjectBuilder/PBBundleHost.h>
#import <ProjectBuilder/PBProject.h>


@implementation CVLAvatar
+ (void) initialize
{
    [self sharedInstance];
}


+ (id) sharedInstance
{
    static id sharedInstance = nil;
    if (sharedInstance == nil) {
        sharedInstance = [[self alloc] init];
    }
    return sharedInstance;
}


- (NSArray *) notificationNames
{
    //return [[[NSBundle bundleForClass:[self class]] infoDictionary] objectForKey:@"NotificationNames"];
    return [NSArray arrayWithObjects:
        PBProjectDidSaveNotification,

        PBFileAddedToProjectNotification,
        PBFileRemovedFromProjectNotification,

        PBFileDidSaveNotification,  // sent ?
        PBFileDeletedNotification,  // sent ?
        PBFileRenamedNotification,
        nil];
}


- (void) registerToNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(fileDidSave:)
                                                 name:PBFileDidSaveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(projectDidSave:)
                                                 name:PBProjectDidSaveNotification
                                               object:nil];
}


- init
{
    [super init];
    [self registerToNotifications];
    return self;
}


- (void) notifyFileDidSave:(NSString *) filePath
{
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"FileDidSave"
                                                                   object:@"CVLAvatar"
                                                                 userInfo:[NSDictionary dictionaryWithObject:filePath forKey:@"Path"]
                                                       deliverImmediately: NO];
}


- (void) fileDidSave:(NSNotification *)notification
{
    [self notifyFileDidSave:[notification object]];
}


- (void) projectDidSave:(NSNotification *) notification
{
    PBProject *project = [notification object];
    [self notifyFileDidSave:[project canonicalFile]];
    [self notifyFileDidSave:[[[project canonicalFile] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Makefile"]];
}
@end
