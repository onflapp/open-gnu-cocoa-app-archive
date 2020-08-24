//
//  CvsWatcher.h
//  CVL
//
//  Created by William Swats on Mon Sep 15 2003.
//  Copyright (c) 2003 Sen:te. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface CvsWatcher : NSObject {
    NSString *username;
    NSNumber *watchesEdit;
    NSNumber *watchesUnedit;
    NSNumber *watchesCommit;
    NSNumber *isTemporary;
}
/*" Creation Methods "*/
- (id)initWithUsername:(NSString *)aUsername watchesEdit:(NSNumber *)watchesEditState watchesUnedit:(NSNumber *)watchesUneditState watchesCommit:(NSNumber *)watchesCommitState isTemporary:(NSNumber *)isTemporaryState;

/*" Accessor Methods "*/
- (NSString *)username;
- (void)setUsername:(NSString *)newUsername;
- (NSNumber *)watchesEdit;
- (void)setWatchesEdit:(NSNumber *)newWatchesEdit;
- (NSNumber *)watchesUnedit;
- (void)setWatchesUnedit:(NSNumber *)newWatchesUnedit;
- (NSNumber *)watchesCommit;
- (void)setWatchesCommit:(NSNumber *)newWatchesCommit;
- (NSNumber *)isTemporary;
- (void)setIsTemporary:(NSNumber *)newIsTemporary;

@end
