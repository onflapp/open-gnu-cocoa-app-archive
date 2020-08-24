/*$Id: NSString.SenOysterRegex.m,v 1.6 2006/04/12 12:47:48 stephane Exp $*/

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "NSString.SenOysterRegex.h"
#import "SenOysterShell.h"
#import <SenFoundation/SenFoundation.h>
#import <Foundation/Foundation.h>

NSString *SenOysterExceptionOperatorKey = @"Operator";

static NSString *selfVar = @"_";
static NSString *matchVar = @"oysterMatch";
static NSString *tempVar = @"oysterTemporary";

@interface NSString (SenOysterRegex_Private)
- (void) raiseInvalidOperator:(NSString *) operatorString currentException:(NSException *)currentException;
@end


@implementation NSString (SenOysterRegex_Private)
- (void) raiseInvalidOperator:(NSString *) operatorString currentException:(NSException *)currentException;
{
    if ([[currentException name] isEqualToString:NSInvalidArgumentException]) {
        [currentException raise];
    }
    else {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[operatorString copy] forKey:SenOysterExceptionOperatorKey];
        NSException *exception = [NSException exceptionWithName:NSInvalidArgumentException reason:[currentException reason] userInfo:userInfo];
        [exception raise];
    }
}
@end


@implementation NSString (SenOysterRegexConditions)
- (BOOL) isValidStringEncoding
{
    return [self canBeConvertedToEncoding:[NSString defaultCStringEncoding]];
}
@end

#ifdef SENOYSTER_PROFILING

static NSTimeInterval	___totalTime = 0.0;
static NSTimeInterval	___totalTime1 = 0.0;
static NSTimeInterval	___totalTime2 = 0.0;
static NSTimeInterval	___totalTime3 = 0.0;
static NSTimeInterval	___totalTime4 = 0.0;
static NSTimeInterval	___totalTime5 = 0.0;

#define START_PROFILER {NSDate *___now = [NSDate date];
#define STOP_PROFILER(x)   {NSTimeInterval ___delta = [[NSDate date] timeIntervalSinceDate:___now];___totalTime += ___delta;___totalTime##x += ___delta;}
#define END_PROFILER(x)   STOP_PROFILER(x);}

@interface SenOysterTimeLogger:NSObject
{}
@end

@implementation SenOysterTimeLogger

+ (void) load
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(terminate:) name:@"NSApplicationWillTerminateNotification" object:nil];
}

+ (void) terminate:(NSNotification *)notif
{
    NSLog(@"SenOyster total time = %lfs", ___totalTime);
    NSLog(@"SenOyster -[NSString(SenOysterRegexMatching) isMatchedByOperator:] time = %lfs", ___totalTime1);
    NSLog(@"SenOyster -[NSString(SenOysterRegexMatching) componentsMatchedByOperator:] time = %lfs", ___totalTime2);
    NSLog(@"SenOyster -[NSString(SenOysterRegexSplitting) componentsSeparatedByOperator:count:] time = %lfs", ___totalTime3);
    NSLog(@"SenOyster -[NSString(SenOysterRegexReplacing) stringByApplyingReplacementOperator:] time = %lfs", ___totalTime4);
    NSLog(@"SenOyster -[NSMutableString(SenOysterRegexReplacing) applyReplacementOperator:] time = %lfs", ___totalTime5);
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"NSApplicationWillTerminateNotification" object:nil];
}

@end
#else

#define START_PROFILER
#define STOP_PROFILER(x)
#define END_PROFILER(x)

#endif

@implementation NSString (SenOysterRegexMatching)
- (BOOL) isMatchedByOperator:(NSString *) operatorString
{
    BOOL	result;
    
    START_PROFILER;
    result = !isNilOrEmpty([self substringMatchedByOperator:operatorString]);
    END_PROFILER(1);

    return result;
}


- (NSString *) substringMatchedByOperator:(NSString *) operatorString
{
    volatile NSString *match = nil;
    senprecondition ([self isValidStringEncoding]);
    senprecondition ([operatorString isValidStringEncoding]);

    NS_DURING
        SenOysterShell *oyster = [SenOysterShell sharedOyster];
        NSString *command = [NSString stringWithFormat:@"%@;$%@=$&", operatorString, matchVar];
        [oyster setString:self forName:selfVar];
        [oyster eval:command];
        match = [oyster stringWithName:matchVar];
    NS_HANDLER
        [self raiseInvalidOperator:operatorString currentException:localException];
    NS_ENDHANDLER
    return (NSString *)match;
}


- (NSArray *) componentsMatchedByOperator:(NSString *) operatorString
{
    volatile NSArray *components = nil;

    START_PROFILER;
    senprecondition ([self isValidStringEncoding]);
    senprecondition ([operatorString isValidStringEncoding]);

    NS_DURING
        NSString *command = [NSString stringWithFormat:@"@%@ = %@", tempVar, operatorString];
        SenOysterShell *oyster = [SenOysterShell sharedOyster];

        [oyster setString:self forName:selfVar];
        [oyster eval:command];
        components = [oyster arrayWithName:tempVar];
    NS_HANDLER
        [self raiseInvalidOperator:operatorString currentException:localException];
    NS_ENDHANDLER
    
    if (!isNilOrEmpty ((NSArray *)components)) {
        if ([(NSArray *)components count] > 1) {
            STOP_PROFILER(2);
            return (NSArray *)components;
        }
        if (!isNilOrEmpty([(NSArray *)components objectAtIndex:0])) {
            STOP_PROFILER(2);
            return (NSArray *)components;
        }
    }
    END_PROFILER(2);
    return nil;
}


- (int) matchOperator:(NSString *) operatorString toObjects:(NSString **) firstObject, ...
{
    volatile int numberOfMatches = 0;
    senprecondition ([self isValidStringEncoding]);
    senprecondition ([operatorString isValidStringEncoding]);

    NS_DURING
        NSArray *components = [self componentsMatchedByOperator:operatorString];
        numberOfMatches = [components count];
        
        if (numberOfMatches > 0) {
            NSString **nextObjectPointer = firstObject;
            int nextIndex = 0;
            va_list args;

            va_start (args, firstObject);
            while ((nextIndex < numberOfMatches) && (nextObjectPointer != NULL))  {                
                *nextObjectPointer = [components objectAtIndex:nextIndex++];
                nextObjectPointer = va_arg (args, NSString **);
            }
            va_end (args);
       };
    NS_HANDLER
        [self raiseInvalidOperator:operatorString currentException:localException];
    NS_ENDHANDLER
    return numberOfMatches;
}


- (void) study
{
    // FIXME broken ?
    senprecondition ([self isValidStringEncoding]);
    {
        SenOysterShell *oyster = [SenOysterShell sharedOyster];
        [oyster setString:self forName:selfVar];
        [oyster eval:@"study;"];
    }
}
@end


@implementation NSString (SenOysterRegexSplitting)
- (NSArray *) componentsSeparatedByOperator:(NSString *) operatorString count:(unsigned int) count
{
    volatile NSArray *components = nil;

    START_PROFILER;
    senprecondition ([self isValidStringEncoding]);
    senprecondition (isNilOrEmpty (operatorString) || [operatorString isValidStringEncoding]);

    NS_DURING
        SenOysterShell *oyster = [SenOysterShell sharedOyster];
        NSString *command = nil;
        NSString *splitParameterList =  nil;

        if (isNilOrEmpty(operatorString)) {
            splitParameterList = ((count == 0) ?
                                  @"" :
                                  [NSString stringWithFormat:@"($_, %d);", count]);
        }
        else {
            splitParameterList = ((count == 0) ?
                                  [NSString stringWithFormat:@"(%@, $_);", operatorString] :
                                  [NSString stringWithFormat:@"(%@, $_, %d);", operatorString, count]);
        }
        command = [NSString stringWithFormat:@"@%@ = split%@;", tempVar, splitParameterList];

        [oyster setString:self forName:selfVar];
        [oyster eval:command];
        components = [oyster arrayWithName:tempVar];
    NS_HANDLER
        [self raiseInvalidOperator:operatorString currentException:localException];
    NS_ENDHANDLER
    senpostcondition ((count == 0) || ([(NSArray *)components count] <= count));
    END_PROFILER(3);
    return (NSArray *)components;
}



- (NSArray *) componentsSeparatedByOperator:(NSString *) operatorString
{
//    senprecondition ([self isValidStringEncoding]);
//    senprecondition (isNilOrEmpty (operatorString) || [operatorString isValidStringEncoding]);
// Already done in following call
    return [self componentsSeparatedByOperator:operatorString count:0];
}


- (NSArray *) componentsSeparatedBySpace
{
//    senprecondition ([self isValidStringEncoding]); // Already done in following call
    return [self componentsSeparatedByOperator:nil count:0];
}
@end


@implementation NSString (SenOysterRegexReplacing)
- (NSString *) stringByApplyingReplacementOperator:(NSString *) operatorString
{
    volatile NSString *transformedString = nil;
    
    START_PROFILER;
    senprecondition ([self isValidStringEncoding]);
    senprecondition ([operatorString isValidStringEncoding]);
    NS_DURING
        SenOysterShell *oyster = [SenOysterShell sharedOyster];
        NSString *command = [NSString stringWithFormat:@"%@;", operatorString];

        [oyster setString:self forName:selfVar];
        [oyster eval:command];
        transformedString = [oyster stringWithName:selfVar];
    NS_HANDLER
        [self raiseInvalidOperator:operatorString currentException:localException];
    NS_ENDHANDLER
    
    END_PROFILER(4);
    return (NSString *)transformedString;
}
@end


@implementation NSMutableString (SenOysterRegexReplacing)
- (int) applyReplacementOperator:(NSString *) operatorString
{
    volatile int numberOfReplacements = 0;
    
    START_PROFILER;
    senprecondition ([self isValidStringEncoding]);
    senprecondition ([operatorString isValidStringEncoding]);
    NS_DURING
        SenOysterShell *oyster = [SenOysterShell sharedOyster];
        NSString *command = [NSString stringWithFormat:@"$%@ = %@;", tempVar, operatorString];

        [oyster setString:self forName:selfVar];
        [oyster eval:command];
        if (0 != (numberOfReplacements = [oyster intWithName:tempVar])) {
            [self setString:[oyster stringWithName:selfVar]];
        };
    NS_HANDLER
        [self raiseInvalidOperator:operatorString currentException:localException];
    NS_ENDHANDLER
    
    END_PROFILER(5);
    return numberOfReplacements;
}
@end
