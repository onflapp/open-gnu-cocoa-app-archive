//
//  NSString+AGRegex.h
//  AGRegex
//
//  Created by William Swats on Mon Jan 26 2004.
//  Copyright (c) 2004 Sente SA. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSString (AGRegex)

/*!
@method matchesPattern:options:
     This method return YES if self matches aPattern using the options in 
     someOptions */
- (BOOL)matchesPattern:(NSString *)aPattern options:(int)someOptions;

/*!
@method findAllMatchesWithPattern:options:
     This method return an array of strings that represent all the matches self 
     has with aPattern using the options in someOptions */
- (NSArray *)findAllMatchesWithPattern:(NSString *)aPattern options:(int)someOptions;

/*!
 @method findAllSubPatternMatchesWithPattern:options:
     This method return an array of strings that represent all the matches self 
     has with the sub-patterns in aPattern using the options in someOptions. A
     sub-pattern is one that is contained within parenthesis in the pattern. 
     The first parenthesis match is at index zero, the second at index one and
     the third one at index two and the nth one at index n-1. */
- (NSArray *)findAllSubPatternMatchesWithPattern:(NSString *)aPattern options:(int)someOptions;

/*!
@method splitStringWithPattern:options:limit:
     This method returns an array of strings that represent the components of 
     self that has been split using aPattern with the options in someOptions. 
     The integer in aLimit represent the maximum number of components to be 
     returned. if aLimit is zreo then there is no limit. For example if this 
     method is called with aPattern equal to a space, then this method would 
     return all the words in a string. */
- (NSArray *)splitStringWithPattern:(NSString *)aPattern options:(int)someOptions limit:(int)aLimit;

/*!
 @method splitStringWithPattern:options:
     This method just calls the method splitStringWithPattern:options:limit: 
     with a zero limit. */
- (NSArray *)splitStringWithPattern:(NSString *)aPattern options:(int)someOptions;

/*!
 @method replaceMatchesOfPattern:withString:options:limit:
     This method replaces all occurrences of aPattern in self with 
     aReplacementString up to a limit of aLimit. If aLimit is zero then there is
     no limit on the number of replacements. */
- (NSString *)replaceMatchesOfPattern:(NSString *)aPattern withString:(NSString *)aReplacementString options:(int)someOptions limit:(int)aLimit;

/*!
  @method replaceMatchesOfPattern:withString:options:
    This method just calls the method 
     replaceMatchesOfPattern:withString:options:limit: with a zero limit. */
- (NSString *)replaceMatchesOfPattern:(NSString *)aPattern withString:(NSString *)aReplacementString options:(int)someOptions;

/*!
  @method checkOptions:
     This method returns YES if the options in someOptions are all valid options; 
     otherwise an AGRegexAssertConditionException exception is raised. */
- (BOOL)checkOptions:(int)someOptions;

@end
