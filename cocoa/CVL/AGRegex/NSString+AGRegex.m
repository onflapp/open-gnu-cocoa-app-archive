//
//  NSString+AGRegex.m
//  AGRegex
//
//  Created by William Swats on Mon Jan 26 2004.
//  Copyright (c) 2004 Sente SA. All rights reserved.
//

#import "NSString+AGRegex.h"
#import "AGRegex.h"
#import "AGRegexMatch.h"


@implementation NSString (AGRegex)

- (BOOL)matchesPattern:(NSString *)aPattern options:(int)someOptions
{
    AGRegex *aRegex = nil;
    AGRegexMatch *aMatch = nil;
    BOOL aMatchFound = NO;
    BOOL optionsOkay = NO;
    
    optionsOkay = [self checkOptions:someOptions];
    if ( optionsOkay == NO ) return NO;
    
    if ( (aPattern != nil) && ([aPattern length] > 0) ) {
        NS_DURING
        aRegex = [AGRegex regexWithPattern:aPattern options:someOptions];
        aMatch = [aRegex findInString:self];
        NS_HANDLER
            NSString *aMsg = [NSString stringWithFormat:
                @"Exception is \"%@\"; Reason is \"%@\"; UserInfo = \"%@\"", 
                [localException name], 
                [localException reason], 
                [localException userInfo]];
            NSLog( [NSString stringWithFormat:
                @"Message: %@ Occurred in file %s:%d in method [%@ %@].",
                (aMsg), __FILE__, __LINE__, NSStringFromClass([self class]),
                NSStringFromSelector(_cmd)] );
        NS_ENDHANDLER
        
        //NSLog(@"aRegex = %@",aRegex);
        //NSLog(@"aMatch = %@",aMatch);
        aMatchFound = ([aMatch count] > 0);        
    }
    return aMatchFound;
}

- (NSArray *)findAllMatchesWithPattern:(NSString *)aPattern options:(int)someOptions
{
    AGRegex *aRegex = nil;
    NSMutableArray *allTheMatches = nil;
    NSArray *allTheRegexMatches = nil;
    AGRegexMatch *aRegexMatch = nil;
    NSString *aMatch = nil;
    NSEnumerator *aRegexMatchEnumerator = nil;
    unsigned int aCount = 0;
    BOOL optionsOkay = NO;
    
    //NSLog(@"self = %@",self);
    //NSLog(@"aPattern = %@",aPattern);

    optionsOkay = [self checkOptions:someOptions];
    if ( optionsOkay == NO ) return nil;
    
    if ( (aPattern != nil) && ([aPattern length] > 0) ) {
        NS_DURING
            aRegex = [AGRegex regexWithPattern:aPattern options:someOptions];
            allTheRegexMatches = [aRegex findAllInString:self];
        NS_HANDLER
            NSString *aMsg = [NSString stringWithFormat:
                @"Exception is \"%@\"; Reason is \"%@\"; UserInfo = \"%@\"", 
                [localException name], 
                [localException reason], 
                [localException userInfo]];
            NSLog( [NSString stringWithFormat:
                @"Message: %@ Occurred in file %s:%d in method [%@ %@].",
                (aMsg), __FILE__, __LINE__, NSStringFromClass([self class]),
                NSStringFromSelector(_cmd)] );
        NS_ENDHANDLER
        
        if ( allTheRegexMatches != nil ) {
            aCount = [allTheRegexMatches count];
        }
        if ( aCount > 0 ) {
            allTheMatches = [NSMutableArray arrayWithCapacity:aCount];
            aRegexMatchEnumerator = [allTheRegexMatches objectEnumerator];
            while ( (aRegexMatch = [aRegexMatchEnumerator nextObject]) ) {
                aMatch = [aRegexMatch group];
                [allTheMatches addObject:aMatch];
                //NSLog(@"aRegexMatch = %@",aRegexMatch);
                //NSLog(@"aMatch = %@",aMatch);
            }
        }
    }
    return allTheMatches;
}

- (NSArray *)findAllSubPatternMatchesWithPattern:(NSString *)aPattern options:(int)someOptions
{
    AGRegex *aRegex = nil;
    NSMutableArray *allTheMatches = nil;
    NSArray *allTheRegexMatches = nil;
    AGRegexMatch *aRegexMatch = nil;
    NSString *aSubPatternMatch = nil;
    NSEnumerator *aRegexMatchEnumerator = nil;
    unsigned int aCount = 0;
    unsigned int aSubPatternCount = 0;
    unsigned int anIndex = 0;
    BOOL optionsOkay = NO;
    
    //NSLog(@"self = %@",self);
    //NSLog(@"aPattern = %@",aPattern);
    
    optionsOkay = [self checkOptions:someOptions];
    if ( optionsOkay == NO ) return nil;
        
    if ( (aPattern != nil) && ([aPattern length] > 0) ) {
        NS_DURING
            aRegex = [AGRegex regexWithPattern:aPattern options:someOptions];
            allTheRegexMatches = [aRegex findAllInString:self];
        NS_HANDLER
            NSString *aMsg = [NSString stringWithFormat:
                @"Exception is \"%@\"; Reason is \"%@\"; UserInfo = \"%@\"", 
                [localException name], 
                [localException reason], 
                [localException userInfo]];
            NSLog( [NSString stringWithFormat:
                                    @"Message: %@ Occurred in file %s:%d in method [%@ %@].",
                (aMsg), __FILE__, __LINE__, NSStringFromClass([self class]),
                NSStringFromSelector(_cmd)] );
        NS_ENDHANDLER
        
        if ( allTheRegexMatches != nil ) {
            aCount = [allTheRegexMatches count];
        }
        if ( aCount > 0 ) {
            allTheMatches = [NSMutableArray arrayWithCapacity:aCount];
            aRegexMatchEnumerator = [allTheRegexMatches objectEnumerator];
            while ( (aRegexMatch = [aRegexMatchEnumerator nextObject]) ) {
                aSubPatternCount = [aRegexMatch count];
                if ( aSubPatternCount > 1 ) {
                    for ( anIndex = 1; anIndex < aSubPatternCount; anIndex++ ) {
                        aSubPatternMatch = [aRegexMatch groupAtIndex:anIndex];
                        if ( aSubPatternMatch == nil ) {
                            aSubPatternMatch = (NSString *)[NSNull null];
                        }
                        [allTheMatches addObject:aSubPatternMatch];
                        //NSLog(@"aRegexMatch = %@",aRegexMatch);
                        //NSLog(@"aSubPatternMatch = %@",aSubPatternMatch);                        
                    }
                }
            }
        }
    }
    return allTheMatches;
}

- (NSArray *)splitStringWithPattern:(NSString *)aPattern options:(int)someOptions limit:(int)aLimit
{
    AGRegex *aRegex = nil;
    NSArray *allTheComponents = nil;
    BOOL optionsOkay = NO;
    
    //NSLog(@"self = %@",self);
    //NSLog(@"aPattern = %@",aPattern);
    
    optionsOkay = [self checkOptions:someOptions];
    if ( optionsOkay == NO ) return nil;
    
    NS_DURING
        aRegex = [AGRegex regexWithPattern:aPattern options:someOptions];
        allTheComponents = [aRegex splitString:self limit:aLimit];
    NS_HANDLER
        NSString *aMsg = [NSString stringWithFormat:
           @"Exception is \"%@\"; Reason is \"%@\"; UserInfo = \"%@\"", 
            [localException name], 
            [localException reason], 
            [localException userInfo]];
        NSLog( [NSString stringWithFormat:
            @"Message: %@ Occurred in file %s:%d in method [%@ %@].",
            (aMsg), __FILE__, __LINE__, NSStringFromClass([self class]),
            NSStringFromSelector(_cmd)] );
    NS_ENDHANDLER

    //NSLog(@"allTheComponents = %@",allTheComponents);
    return allTheComponents;
}

- (NSArray *)splitStringWithPattern:(NSString *)aPattern options:(int)someOptions
{
    return [self splitStringWithPattern:aPattern options:someOptions limit:0];
}

- (NSString *)replaceMatchesOfPattern:(NSString *)aPattern withString:(NSString *)aReplacementString options:(int)someOptions limit:(int)aLimit
{
    AGRegex *aRegex = nil;
    NSString *aNewString = nil;
    BOOL optionsOkay = NO;
    
    //NSLog(@"self = \n%@",self);
    //NSLog(@"aPattern = %@",aPattern);
    //NSLog(@"aReplacementString = %@",aReplacementString);
    
    optionsOkay = [self checkOptions:someOptions];
    if ( optionsOkay == NO ) return nil;
        
    NS_DURING
        aRegex = [AGRegex regexWithPattern:aPattern options:someOptions];
        aNewString = [aRegex replaceWithString:aReplacementString 
                                      inString:self 
                                         limit:aLimit];
    NS_HANDLER
        NSString *aMsg = [NSString stringWithFormat:
            @"Exception is \"%@\"; Reason is \"%@\"; UserInfo = \"%@\"", 
            [localException name], 
            [localException reason], 
            [localException userInfo]];
        NSLog( [NSString stringWithFormat:
            @"Message: %@ Occurred in file %s:%d in method [%@ %@].",
            (aMsg), __FILE__, __LINE__, NSStringFromClass([self class]),
            NSStringFromSelector(_cmd)] );
    NS_ENDHANDLER
    
    //NSLog(@"aNewString = \n%@",aNewString);
    return aNewString;
}

- (NSString *)replaceMatchesOfPattern:(NSString *)aPattern withString:(NSString *)aReplacementString options:(int)someOptions
{
    return [self replaceMatchesOfPattern:aPattern 
                              withString:aReplacementString 
                                 options:someOptions
                                   limit:0];
}

- (BOOL)checkOptions:(int)someOptions
{
    int allOptions = 0;
    // First do a bitwise OR on all the options.
    allOptions = AGRegexCaseInsensitive | 
                 AGRegexDotAll | 
                 AGRegexExtended |
                 AGRegexLazy |
                 AGRegexMultiline;
    // First do a bitwise AND on the someOptions argument and the one's 
    // complement of all the options. If this is not zero then this method
    // has been passed an invalid option.
    if ( (someOptions & ~allOptions) != 0 ) {
        // One or more of the options were not valid.
        [NSException raise:@"AGRegexAssertConditionException" format:
        @"someOptions = %d is not a valid set of options! Valid Options are:\n\tAGRegexCaseInsensitive = 1\n\tAGRegexDotAll = 2\n\tAGRegexExtended = 4\n\tAGRegexLazy = 8\n\tAGRegexMultiline = 16\nOccurred in file %s:%d in method [%@ %@].",
            someOptions, __FILE__, __LINE__, NSStringFromClass([self class]),
            NSStringFromSelector(_cmd)];        
        return NO;
    }
    return YES;
}

@end
