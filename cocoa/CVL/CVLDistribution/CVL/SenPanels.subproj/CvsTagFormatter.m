//
//  CvsTagFormatter.m
//  CVL
//
//  Created by William Swats on Wed Jul 23 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "CvsTagFormatter.h"
#import <SenFoundation/SenAssertion.h>


@implementation CvsTagFormatter

- (NSString *)stringForObjectValue:(id)anObject
{
    NSString *aString = @"";
    
    if ( anObject != nil ) {
        if ( [anObject isKindOfClass:[NSString class]] ) {
            aString = anObject;
        } else if ( [anObject respondsToSelector:@selector(stringValue)] ) {
            aString = [anObject stringValue];
        } else if ( [anObject respondsToSelector:@selector(description)] ) {
            aString = [anObject description];
        }
    }
    return aString;
}

- (NSAttributedString *)attributedStringForObjectValue:(id)obj withDefaultAttributes:(NSDictionary *)attrs
{
    return nil;
}

- (BOOL)getObjectValue:(id *)anObjectPtr forString:(NSString *)aString errorDescription:(NSString **)anErrorPtr
{
    NSScanner *aScanner;
    NSCharacterSet *aLetterCharacterSet = nil;
    NSCharacterSet *aDigitCharacterSet = nil;
    NSMutableCharacterSet *aCvsTagCharacterSet = nil;
    NSCharacterSet *anEmptyCharacterSet = nil;

    NSString *anError = @"an unknown formatting error occurred.";
    
    BOOL result = NO;
    BOOL scanResult = NO;

    SEN_ASSERT_NOT_NIL((id)anObjectPtr);
    
    aLetterCharacterSet = [NSCharacterSet characterSetWithCharactersInString:
        @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"];
    aDigitCharacterSet = [NSCharacterSet characterSetWithCharactersInString:
        @"0123456789"];
    aCvsTagCharacterSet = (NSMutableCharacterSet *)[NSMutableCharacterSet characterSetWithCharactersInString:
        @"-_"];
    [aCvsTagCharacterSet formUnionWithCharacterSet:aDigitCharacterSet];
    [aCvsTagCharacterSet formUnionWithCharacterSet:aLetterCharacterSet];
    anEmptyCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@""];
    
    // Set the default error message.
    anError = [NSString stringWithFormat:
        @"An unknown formatting error occurred. Your tag was \"%@\"",
        aString];
    
    if ( isNotEmpty(aString) ) {
        // Create a scanner.
        aScanner = [NSScanner scannerWithString:aString];
        // Do not skip white space.
        [aScanner setCharactersToBeSkipped:anEmptyCharacterSet];
        // Check that the tag begins with a letter.
        scanResult = [aScanner scanCharactersFromSet:aLetterCharacterSet intoString:NULL];
        if ( scanResult == NO ) {
            anError = [NSString stringWithFormat:
                @"The first character of a tag has to start with a letter. Your tag was \"%@\"",
                aString];
            result = NO;
        } else {
            // Check that the rest of the string only has letters, digits, and the
            // charaters dash and underscore.
            scanResult = [aScanner scanCharactersFromSet:aCvsTagCharacterSet intoString:NULL];
            if ( [aScanner isAtEnd] ) {
                *anObjectPtr = [[aString copy] autorelease];
                result = YES;
            } else {
                anError = [NSString stringWithFormat:
                    @"A tag can only contain letters (a-z) and (A-Z), digits (0-9) and the dash(-) and the underscore (_). Your tag was \"%@\".", 
                    aString];
                result = NO;
            }            
        }
    } else {
        // An empty string passes the formatting tests
        result = YES;
    }
    
    // If we have a formatting error then write the error message to the error
    // pointer pasted in.
    if ( result == NO ) {
        if ( anErrorPtr != NULL ) {
            *anErrorPtr = NSLocalizedString(anError, @"A CVS Tag formatting Error");                
        }        
    }
    return result;
}

- (BOOL)isPartialStringValid:(NSString *)partialString newEditingString:(NSString **)newString errorDescription:(NSString **)anErrorPtr
{
    id anObject = nil;
    id *anObjectPtr = NULL;
    
    anObjectPtr = &anObject;
    return [self getObjectValue:anObjectPtr 
                      forString:partialString 
               errorDescription:anErrorPtr];
}


@end

#ifdef RHAPSODY
@implementation NSTextField(CvsTagFormatter)
- (void)setFormatter:(NSFormatter *)formatter
{
    [[self cell] setFormatter:formatter];
}
@end
#endif
