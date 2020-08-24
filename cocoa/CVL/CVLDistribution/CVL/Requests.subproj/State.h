/* State.h created by ja on Fri 18-Feb-2000 */
/* Copyright (c) 1997, Sen:te Ltd.  All rights reserved. */

#import <AppKit/AppKit.h>

@class Transition;

@interface State : NSObject
{
    NSMutableArray *transitions;
    NSDictionary *attributes;
    SEL enteringSelector;
    NSString *name;
}
+ (State *)initialStateForStateFile:(NSString *)filePath;
- (State *)nextStateForMachine:(id)machine;
- (id)valueForKey:(NSString *)key;
- (BOOL)isTerminal;
- (SEL)enteringSelector;
@end
