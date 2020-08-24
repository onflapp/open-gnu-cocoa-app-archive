#import <Foundation/NSFileManager.h>
#import <Foundation/NSArray.h>

@interface DirList:NSObject
{
	id	namelist;
	BOOL	ignoreDots;
}

+ (void)setExtList:(NSArray *)list;

- (id)init;
- (void)dealloc;
- (void)setIgnoreDottedFiles:(BOOL)flag;
- (int)getDirList:(NSString *)dirname;
- (int)fileNumber;
- (NSString *)filenameAt:(int)pos;

@end
