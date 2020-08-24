//
//  CvsWatchRequest.h
//  CVL
//
//  Created by Isa Kindov on Wed Jul 10 2002.
//  Copyright (c) 2002 Sen:te. All rights reserved.
//

#import <CvsRequest.h>


typedef enum {
    CvsWatchEditActionTag = 10,
    CvsWatchUneditActionTag = 20,
    CvsWatchCommitActionTag = 30,
    CvsWatchAllActionsTag = 40,
    CvsWatchNoActionTag = 50,

    CvsUnwatchEditActionTag = -10,
    CvsUnwatchUneditActionTag = -20,
    CvsUnwatchCommitActionTag = -30,
    CvsUnwatchAllActionsTag = -40,

    CvsWatchOnTag = 100,
    CvsWatchOffTag = -100
}CvsWatchActionTag;


@interface CvsWatchRequest : CvsRequest
{
    CvsWatchActionTag	actionTag;
}

+ (CvsWatchRequest *) watchRequestForFiles:(NSArray *)files inPath:(NSString *)path forAction:(CvsWatchActionTag)tag;

- (CvsWatchActionTag) actionTag;
- (void) setActionTag:(CvsWatchActionTag)newActionTag;

@end
