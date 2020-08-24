//
//  CvsWatcher.m
//  CVL
//
//  Created by William Swats on Mon Sep 15 2003.
//  Copyright (c) 2003 Sen:te. All rights reserved.
//

#import "CvsWatcher.h"

#import <SenFoundation/SenFoundation.h>


@implementation CvsWatcher


- (id)init
{
    SEN_NOT_DESIGNATED_INITIALIZER(@"-initWithUsername:watchesEdit:watchesUnedit:watchesCommit:isTemporary:");
    
    return nil;
}

- (id)initWithUsername:(NSString *)aUsername watchesEdit:(NSNumber *)watchesEditState watchesUnedit:(NSNumber *)watchesUneditState watchesCommit:(NSNumber *)watchesCommitState isTemporary:(NSNumber *)isTemporaryState
    /*" This is the designated initializer for this class. A CvsWatcher object is
        essentially a holder for the information returned from a CVS request for
        one of the watchers of a file. this iformation is a username, an edit 
        state, an unedit state, a commit state and whether are not it is a 
        temporary watch.
    "*/
{
    SEN_ASSERT_NOT_EMPTY(aUsername);
    
    if ( (self = [super init]) ) {
        ASSIGN(username, aUsername);
        ASSIGN(watchesEdit, watchesEditState);
        ASSIGN(watchesUnedit, watchesUneditState);
        ASSIGN(watchesCommit, watchesCommitState);
        ASSIGN(isTemporary, isTemporaryState);
    }
    return self;
}

- (void)dealloc
{
    RELEASE(username);
    
    [super dealloc];
}

- (NSString *)username
    /*" This is the get method for the username.

        See also #{-setUsername:}
    "*/
{
    return username;
}

- (void)setUsername:(NSString *)newUsername
    /*" This is the set method for the username.

        See also #{-username}
    "*/
{
    ASSIGN(username, newUsername);
}

- (NSNumber *)watchesEdit
    /*" This is the get method for the watches edit state expressed as a 
        NSNumber (1 is on and 0 is off).

        See also #{-setWatchesEdit:}
    "*/
{
	return watchesEdit;
}

- (void)setWatchesEdit:(NSNumber *)newWatchesEdit
    /*" This is the set method for the watches edit state expressed as a 
        NSNumber (1 is on and 0 is off).
    
        See also #{-watchesEdit}
    "*/
{
    ASSIGN(watchesEdit, newWatchesEdit);
}

- (NSNumber *)watchesUnedit
    /*" This is the get method for the watches unedit state expressed as a 
        NSNumber (1 is on and 0 is off).
    
        See also #{-setWatchesUnedit:}
    "*/
{
	return watchesUnedit;
}

- (void)setWatchesUnedit:(NSNumber *)newWatchesUnedit
    /*" This is the set method for the watches unedit state expressed as a 
        NSNumber (1 is on and 0 is off).
    
        See also #{-watchesUnedit}
    "*/
{
    ASSIGN(watchesUnedit, newWatchesUnedit);
}

- (NSNumber *)watchesCommit
    /*" This is the get method for the watches commit state expressed as a 
        NSNumber (1 is on and 0 is off).
    
        See also #{-setWatchesCommit:}
    "*/
{
	return watchesCommit;
}

- (void)setWatchesCommit:(NSNumber *)newWatchesCommit
    /*" This is the set method for the watches commit state expressed as a 
        NSNumber (1 is on and 0 is off).
    
        See also #{-watchesCommit}
    "*/
{
    ASSIGN(watchesCommit, newWatchesCommit);
}

- (NSNumber *)isTemporary
    /*" This is the get method for the isTemporary state expressed as a 
        NSNumber (1 is on and 0 is off). isTemporary is turn on whenever a user
        issues the CVS edit command on a file. He is then automatically setup
        as a temporary watcher of all actions on that file. These watcher
        actions are deleted when the same user either commits or issues an 
        unedit command on the same file.
    
        See also #{-setIsTemporary:}
    "*/
{
	return isTemporary;
}

- (void)setIsTemporary:(NSNumber *)newIsTemporary
    /*" This is the set method for the isTemporary state expressed as a 
        NSNumber (1 is on and 0 is off).
    
        See also #{-isTemporary}
    "*/
{
    ASSIGN(isTemporary, newIsTemporary);
}


@end
