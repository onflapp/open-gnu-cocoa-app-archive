//
//  CvsVerboseStatusRequestForWorkArea.h
//  CVL
//
//  Created by William Swats on Mon Apr 05 2004.
//  Copyright (c) 2004 Sente SA. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <CvsRequest.h>



@interface CvsVerboseStatusRequestForWorkArea : CvsRequest
{
    NSMutableString *parsingBuffer;
    NSMutableDictionary *result;
}

+ (CvsVerboseStatusRequestForWorkArea *)cvsVerboseStatusRequestForWorkArea:(NSString *)aWorkAreaPath;

- (NSDictionary *)result;

@end
