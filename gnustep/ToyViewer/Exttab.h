#import <AppKit/AppKit.h>

@interface Exttab : NSObject
{
	int entry;
	char **table;
	int *args;
}

+ (void)setHome:(NSString *)home andPath:(NSString *)path;
- (id)init;
- (int)readExtData:(NSString *)filename;
- (char **)table;
- (int)entry;
- (const char **)execListAlloc: (const char *)type with: (NSString *)filename;
@end
