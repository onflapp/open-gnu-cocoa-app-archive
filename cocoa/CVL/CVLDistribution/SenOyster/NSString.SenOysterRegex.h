/*$Id: NSString.SenOysterRegex.h,v 1.4 2001/03/29 08:25:31 stephane Exp $*/

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

// These categories of NSString defines search and replace methods based on Perl's
// powerful regular expression pattern matching.
//
// SenOysterRegex offers equivalent to the following Perl operators and functions:
//    SenOysterRegexMatching       [m]/PATTERN/[cgimosx]
//    SenOysterRegexReplacing      s/PATTERN/REPLACEMENT/[egimosx]
//                                 tr/SEARCHLIST/REPLACEMENTLIST/[cds]
//    SenOysterRegexSplitting      split(PATTERN,[EXPR,[LIMIT]])
//
// "Operator", in the context of these categories means a string containing a Perl
// operator (for instance: /\s+/ ) rather than a regular expression (for instance: \s+).
//
// FIXME: Operators and patterns are not objects.

#import <Foundation/NSString.h>
#import <Foundation/NSRange.h>
#import "SenOysterDefines.h"

@class NSArray;

SENOYSTER_EXPORT NSString *SenOysterExceptionOperatorKey;

@interface NSString (SenOysterRegexConditions)
// This category defines methods that can be used to partially validate operatorString. These
// methods are also used in preconditions.

- (BOOL) isValidStringEncoding;
    // Returns YES if and only if the receiver can be converted to a valid string encoding.
    // Only the defaultCStringEncoding is currently supported.
@end


@interface NSString (SenOysterRegexMatching)
- (BOOL) isMatchedByOperator:(NSString *) operatorString;
    // Returns YES if the receiver is matched by the operatorString's regular expression, NO otherwise.
    //
    // Raises NSInvalidArgument if operatorString is not a syntaxically correct perl matching
    // operator. The exception's userInfo dictionary has a copy of operatorString available under
    // the key SenOysterExceptionOperatorKey.
    //
    // senprecondition ([self isValidStringEncoding]);
    // senprecondition ([operatorString isValidStringEncoding]);

- (NSString *) substringMatchedByOperator:(NSString *) operatorString;
    // Returns the first subexpression of the receiver matched by the operatorString's regular expression,
    // or nil if there is no match.
    //
    // Raises NSInvalidArgument if operatorString is not a syntaxically correct perl matching
    // operator. The exception's userInfo dictionary has a copy of operatorString available under
    // the key SenOysterExceptionOperatorKey.
    //
    // senprecondition ([self isValidStringEncoding]);
    // senprecondition ([operatorString isValidStringEncoding]);

- (NSArray *) componentsMatchedByOperator:(NSString *) operatorString;
    // Returns an array consisting of the subexpressions matched by the parenthesis in operatorString,
    // or nil if there is no match.
    //
    // Raises NSInvalidArgument if operatorString is not a syntaxically correct perl matching
    // operator. The exception's userInfo dictionary has a copy of operatorString available under
    // the key SenOysterExceptionOperatorKey.
    //
    // senprecondition ([self isValidStringEncoding]);
    // senprecondition ([operatorString isValidStringEncoding]);

- (int) matchOperator:(NSString *) operatorString toObjects:(NSString **) firstObject, ...;
    // Returns the number of matches between the receiver and the operatorString's regular expression
    // and the subexpressions matched by the parenthesis in operatorString by reference in the NULL
    // terminated list of object references firstObject, ...
    //
    // Raises NSInvalidArgument if operatorString is not a syntaxically correct perl matching
    // operator. The exception's userInfo dictionary has a copy of operatorString available under
    // the key SenOysterExceptionOperatorKey.
    //
    // senprecondition ([self isValidStringEncoding]);
    // senprecondition ([operatorString isValidStringEncoding]);

- (void) study;
    /* Broken ? */
    // senprecondition ([self isValidStringEncoding]);

@end


@interface NSString (SenOysterRegexSplitting)
- (NSArray *) componentsSeparatedByOperator:(NSString *) operatorString count:(unsigned int) count;
    // Splits the receiver into an array of no more than count strings, and returns it.
    // Occurences of the strings in the receiver are separated by subexpressions matched
    // by the operatorString's regular expression.
    // If count is 0, returns all possible strings.
    // If operatorString is nil, splits on whitespace.
    //
    // Raises NSInvalidArgument if operatorString is not a syntaxically correct perl matching
    // operator. The exception's userInfo dictionary has a copy of operatorString available under
    // the key SenOysterExceptionOperatorKey.
    //
    // senprecondition ([self isValidStringEncoding]);
    // senprecondition ([operatorString isValidStringEncoding]);
    //
    // senpostcondition ((count == 0) || ([result count] <= count));


- (NSArray *) componentsSeparatedByOperator:(NSString *) operatorString;
    // Calls componentsSeparatedByOperator:count with a count of 0
    //
    // Raises NSInvalidArgument if operatorString is not a syntaxically correct perl matching
    // operator. The exception's userInfo dictionary has a copy of operatorString available under
    // the key SenOysterExceptionOperatorKey.
    //
    // senprecondition ([self isValidStringEncoding]);
    // senprecondition ([operatorString isValidStringEncoding]);

- (NSArray *) componentsSeparatedBySpace;
    // Calls componentsSeparatedByOperator:count: with a count of 0 and a nil operatorString
    //
    // senprecondition ([self isValidStringEncoding]);
@end


@interface NSString (SenOysterRegexReplacing)
- (NSString *) stringByApplyingReplacementOperator:(NSString *) operatorString;
    // Returns a copy of the receiver where:
    // - for substitutions (s/PATTERN/REPLACEMENT/... operatorString), all occurences of PATTERN
    // are replaced with REPLACEMENT.
    // - for translation (tr/SEARCHLIST/REPLACEMENT/... operatorString), all occurences of the
    // characters found in the search list are replaced with corresponding character in the
    // replacement list.
    //
    // Raises NSInvalidArgument if operatorString is not a syntaxically correct perl substitution
    // or tranliteration operator. The exception's userInfo dictionary has a copy of operatorString
    // available under the key SenOysterExceptionOperatorKey.
    //
    // senprecondition ([self isValidStringEncoding]);
    // senprecondition ([operatorString isValidStringEncoding]);
@end


@interface NSMutableString (SenOysterRegexReplacing)
- (int) applyReplacementOperator:(NSString *) operatorString;
    // Modify the receiver by:
    // - for substitutions (s/PATTERN/REPLACEMENT/... operatorString), replacing all
    // occurences of PATTERN with REPLACEMENT.
    // - for translation (tr/SEARCHLIST/REPLACEMENTLIST/... operatorString), replacing all
    // occurences of the characters found in the search list with corresponding character
    // in the replacement list.
    //
    // Raises NSInvalidArgument if operatorString is not a syntaxically correct perl substitution
    // or tranliteration operator. The exception's userInfo dictionary has a copy of operatorString
    // available under the key SenOysterExceptionOperatorKey.
    //
    // senprecondition ([self isValidStringEncoding]);
    // senprecondition ([operatorString isValidStringEncoding]);
@end
