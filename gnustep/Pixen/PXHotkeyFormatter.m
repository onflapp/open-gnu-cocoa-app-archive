//
//  PXHotkeyFormatter.m
//  Pixen-XCode
//
//  Created by Andy Matuschak on Sun Apr 04 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXHotkeyFormatter.h"


@implementation PXHotkeyFormatter

- stringForObjectValue:(NSString *)anObject
{
	if (![anObject isKindOfClass:[NSString class]]) { return nil; }
	if ([anObject length] > 0)
	{
		unichar theCharacter = [anObject characterAtIndex:([anObject length] - 1)];
		if(![[NSCharacterSet letterCharacterSet] characterIsMember:theCharacter])
		{
			return nil;
		}
		return [NSString stringWithFormat:@"%c", theCharacter];
	}
	else
		return @"";
}

- (BOOL)isPartialStringValid:(NSString *)partialString newEditingString:(NSString **)newString errorDescription:(NSString **)error
{
	if ([partialString length] > 0)
	{
		unichar theCharacter = [partialString characterAtIndex:([partialString length] - 1)];
		if(![[NSCharacterSet letterCharacterSet] characterIsMember:theCharacter])
		{
			*newString = nil;
			return NO;
		}
		if ([partialString length] > 1) {
			*newString = [NSString stringWithFormat:@"%c", theCharacter];
			return NO;
		}
	}
	return YES;
}

- (BOOL)getObjectValue:(id *)anObject forString:string errorDescription:(NSString **)error;
{
	*anObject = [[string copy] autorelease];
	return YES;
}

- attributedStringForObjectValue:anObject defaultAttributes:attributes
{
	return [[[NSAttributedString alloc] initWithString:[self stringForObjectValue:anObject]] autorelease];
}

@end
