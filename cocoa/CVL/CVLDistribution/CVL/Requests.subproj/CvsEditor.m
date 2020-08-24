//
//  CvsEditor.m
//  CVL
//
//  Created by William Swats on Wed Sep 10 2003.
//  Copyright (c) 2003 Sente SA. All rights reserved.
//

/*" This class represents the editors returned by the cvs command "cvs editors".
    These objects are created in the class CvsEditorsRequest.
"*/

#import "CvsEditor.h"

#import <SenFoundation/SenFoundation.h>


@implementation CvsEditor

- (id)init
{
    SEN_NOT_DESIGNATED_INITIALIZER(@"-initWithUsername:startDate:hostname:filePath:");
    
    return nil;
}

- (id)initWithUsername:(NSString *)aUsername startDate:(NSCalendarDate *)aStartDate hostname:(NSString *)aHostname filePath:(NSString *)aFilePath
    /*" This is the designated initializer for this class. A CvsEditor object is
        essentially a holder for the information returned from a CVS request for
        one of the editors of a file. this iformation is a username, a date the
        edit started, a hostname and a file path.
    "*/
{
    SEN_ASSERT_NOT_EMPTY(aUsername);
    SEN_ASSERT_NOT_NIL(aStartDate);
    SEN_ASSERT_NOT_EMPTY(aHostname);
    SEN_ASSERT_NOT_EMPTY(aFilePath);
    
    if ( (self = [super init]) ) {
        ASSIGN(username, aUsername);
        ASSIGN(startDate, aStartDate);
        ASSIGN(hostname, aHostname);
        ASSIGN(filePath, aFilePath);
    }
    return self;
}

- (void)dealloc
{
    RELEASE(username);
    RELEASE(startDate);
    RELEASE(hostname);
    RELEASE(filePath);
    
    [super dealloc];
}

- (NSString *)description
    /*" This method overrides supers implementation. Here we return the username,
        start date, hostname and file path.
    "*/
{
    return [NSString stringWithFormat:
        @"username = %@, startDate = %@, hostname = %@, filePath = %@", 
        username, startDate, hostname, filePath];
}

- (NSCalendarDate *)startDate
    /*" This is the get method for the start date.

        See also #{-setStartDate:}
    "*/
{
	return startDate;
}

- (void)setStartDate:(NSCalendarDate *)newStartDate
    /*" This is the set method for the start date.

        See also #{-startDate}
    "*/
{
    ASSIGN(startDate, newStartDate);
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

- (NSString *)hostname
    /*" This is the get method for the hostname.

        See also #{-setHostname:}
    "*/
{
	return hostname;
}

- (void)setHostname:(NSString *)newHostname
    /*" This is the set method for the hostname.

        See also #{-hostname}
    "*/
{
    ASSIGN(hostname, newHostname);
}

- (NSString *)filePath
    /*" This is the get method for the file path.

        See also #{-setFilePath:}
    "*/
{
	return filePath;
}

- (void)setFilePath:(NSString *)newFilePath
    /*" This is the set method for the file path.

        See also #{-filePath}
    "*/
{
    ASSIGN(filePath, newFilePath);
}

- (BOOL)isEqualToCvsEditor:(CvsEditor *)anotherCvsEditor
    /*" This method returns YES if self is equal to anotherCvsEditor. Here equals
        means either it is the very same object or the usernames, hostnames,
        file paths and start dates are all the same. Otherwise NO is returned.
    "*/
{
    if ( self == anotherCvsEditor ) return YES;
    if ( ([[anotherCvsEditor username] isEqualToString:[self username]]) &&
         ([[anotherCvsEditor hostname] isEqualToString:[self hostname]]) &&
         ([[anotherCvsEditor filePath] isEqualToString:[self filePath]]) &&
         ([[anotherCvsEditor startDate] isEqualToDate:[self startDate]]) ) return YES;
    return NO;
}

@end
