#import <Foundation/NSString.h>
#import <Foundation/NSPathUtilities.h>

@interface NSString (Appended)

+ (id)stringWithCStringInEUC:(const char *)cstr;
+ (id)stringWithCStringInSJIS:(const char *)cstr;
+ (id)stringWithCStringInFS:(const char *)cstr;
- (const char *)cStringInEUC;
- (const char *)cStringInSJIS;

- (NSString *)newStringByAppendingPathComponent:(NSString *)obj;

@end
