#import "NSStringAppended.h"
#import <Foundation/NSData.h>
#import <string.h>

@implementation NSString (Appended)

+ (id)stringWithCStringInEUC:(const char *)cstr
{
	NSData *data;
	id str;

	data = [NSData dataWithBytes:(const void *)cstr length:strlen(cstr)];
	str = [[self alloc] initWithData:data encoding:NSJapaneseEUCStringEncoding];
	[str autorelease];
	return str;
}

+ (id)stringWithCStringInSJIS:(const char *)cstr
{
	NSData *data;
	id str;

	data = [NSData dataWithBytes:(const void *)cstr length:strlen(cstr)];
	str = [[self alloc] initWithData:data encoding:NSShiftJISStringEncoding];
	[str autorelease];
	return str;
}

+ (id)stringWithCStringInFS:(const char *)cstr
{
	return [self stringWithUTF8String:cstr];
}

- (const char *)cStringInEUC
{
	/* Only if default coding of cString is EUC.
		return [self cString];
	*/
	NSMutableData *data = [[[self dataUsingEncoding:NSJapaneseEUCStringEncoding
			allowLossyConversion:NO] mutableCopy] autorelease];
	[data increaseLengthBy:1];
	return [data bytes];
}

- (const char *)cStringInSJIS
{
	NSMutableData *data = [[[self dataUsingEncoding:NSShiftJISStringEncoding
			allowLossyConversion:NO] mutableCopy] autorelease];
	[data increaseLengthBy:1];
	return [data bytes];
}

- (NSString *)newStringByAppendingPathComponent:(NSString *)obj
{
	NSString *tmp;

	if ([obj length] < 3 || [obj characterAtIndex:1] != ':')
		return [self stringByAppendingPathComponent: obj];

	/* obj may have form like MS-DOS filename, that is, "C:xxxxx".	*/
	/* Usual method stringByAppendingPathComponent: can't append	*/
	/* such component well. */

	tmp = [self stringByAppendingPathComponent:[obj substringToIndex:1]];
	return [tmp stringByAppendingString:[obj substringFromIndex:1]];
}

@end
