//
//  CvsEditor.h
//  CVL
//
//  Created by William Swats on Wed Sep 10 2003.
//  Copyright (c) 2003 Sente SA. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface CvsEditor : NSObject 
{
    NSCalendarDate *startDate;
    NSString *username;
    NSString *hostname;
    NSString *filePath;
}
/*" Creation Methods "*/
- (id)initWithUsername:(NSString *)aUsername startDate:(NSCalendarDate *)aStartDate hostname:(NSString *)aHostname filePath:(NSString *)aFilePath;

/*" Accessor Methods "*/
- (NSCalendarDate *)startDate;
- (void)setStartDate:(NSCalendarDate *)newStartDate;
- (NSString *)username;
- (void)setUsername:(NSString *)newUsername;
- (NSString *)hostname;
- (void)setHostname:(NSString *)newHostname;
- (NSString *)filePath;
- (void)setFilePath:(NSString *)newFilePath;

/*" Comparison Methods "*/
- (BOOL)isEqualToCvsEditor:(CvsEditor *)anotherCvsEditor;

@end
