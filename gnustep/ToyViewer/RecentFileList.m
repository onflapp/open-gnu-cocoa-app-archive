

#include "RecentFileList.h" //GNUstep only
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <Foundation/NSPathUtilities.h>

#define  InitialMaxNumber	16

@interface NSString (FilenameSort)
- (NSComparisonResult)caseInsensitiveFilenameCompare:(NSString *)aString;
@end

@implementation NSString (FilenameSort)
- (NSComparisonResult)caseInsensitiveFilenameCompare:(NSString *)aString
{
	return [[self lastPathComponent]
		caseInsensitiveCompare: [aString lastPathComponent]];
}
@end


@interface PathCell : NSObject
{
	NSString *path;
	BOOL	hasDirPart;
	BOOL	hasSameName;
}
+ (id)cellWithPath:(NSString *)str;
- (void)dealloc;
- (NSString *)path;
- (void)setHasSameName:(BOOL)flag;
- (BOOL)menuUpdateNeeded;
- (NSString *)menuTitle;
@end

@implementation PathCell
+ (id)cellWithPath:(NSString *)str
{
	PathCell *obj = [[[self alloc] init] autorelease];
	obj->path = [str retain];
	obj->hasDirPart = obj->hasSameName = NO;
	return obj;
}

- (void)dealloc
{
	[path release];
	[super dealloc];
}

- (NSString *)path { return path; }

- (void)setHasSameName:(BOOL)flag { hasSameName = flag; }

- (BOOL)menuUpdateNeeded {
	return (hasSameName != hasDirPart);
}

- (NSString *)menuTitle
{
	if (hasSameName) {
		hasDirPart = YES;
		return [NSString stringWithFormat:@"%@  .../%@",
			[path lastPathComponent],
			[[path stringByDeletingLastPathComponent] lastPathComponent]];
	}
	hasDirPart = NO;
	return [path lastPathComponent];
}

@end


@implementation RecentFileList

static id sharedList = nil;

+ (id)sharedList {
	if (sharedList == nil)
		sharedList = [[self alloc] init];
	return sharedList;
}

/* Local Method */
- (void)addNewItemOfPath:(PathCell *)cell atIndex:(int)idx
{
	id <NSMenuItem> item;
	NSString *name;

	name = [cell menuTitle];
	item = [parent insertItemWithTitle:name action:@selector(menuAction:)
		keyEquivalent:@"" atIndex:idx];
	[item setTarget: self];
	[cleanItem setEnabled: YES];
}

/* Local Method */
- (void)checkItemsName
{
	int	n, idx;
	PathCell *p, *q;

	n = [filelist count];
	if (n <= 0) return;
	p = [filelist objectAtIndex:0];
	[p setHasSameName:NO];
	if (n == 1)
		return;
	for (idx = 1; idx < n; idx++) {
		q = [filelist objectAtIndex: idx];
		if ([[q path] caseInsensitiveFilenameCompare:[p path]] == NSOrderedSame) {
			[p setHasSameName: YES];
			[q setHasSameName: YES];
		}else
			[q setHasSameName: NO];
		p = q;
	}
}

- (id)init
{
	[super init];
	maxnum = InitialMaxNumber;
	filelist = [[NSMutableArray alloc] initWithCapacity: 1];
	fifo = [[NSMutableArray alloc] initWithCapacity: 1];
	return self;
}

- (void)dealloc
{
	[filelist release];
	[fifo release];
	[super dealloc];
}

- (void)setPropertyList:(id)list
{
	id	sorted;
	int	idx, n;

	if (list == nil || [list count] <= 0)
		return;
	if ([filelist count] > 0)
		[filelist removeAllObjects];
	[fifo release];
	fifo = [list mutableCopy];
	while ([fifo count] > maxnum)
		[fifo removeLastObject];
	sorted = [fifo sortedArrayUsingSelector:
			@selector(caseInsensitiveFilenameCompare:)];
	n = [sorted count];
	for (idx = 0; idx < n; idx++) {
		NSString *s = [sorted objectAtIndex:idx];
		[filelist addObject:[PathCell cellWithPath: s]];
	}
	[self checkItemsName];
}

- (void)setTarget:(id)obj andAction:(SEL)sel
{
	target = obj;
	action = sel;
}

- (void)menuAction:(id)sender
{
	int i;
	int idx = [parent indexOfItem: sender];
	NSString *path = [[filelist objectAtIndex: idx] path];
	[target performSelector:action withObject: path];
	if ((i = [fifo indexOfObject: path]) != NSNotFound) {
		[fifo removeObjectAtIndex: i];
		// path is retained by filelist
		[fifo insertObject:path atIndex:0];
	}
}

- (void)setMaxFiles:(int)max { maxnum = max; }

- (void)makeSubMenuOf:(NSMenu *)menu
{
	int	n, i;

	parent = menu;
	if ((n = [parent numberOfItems]) > 0) {
		cleanItem = [parent itemAtIndex:(n-1)];
		[cleanItem setTarget: self];
		[cleanItem setAction: @selector(clearAll:)];
	}
	i = [filelist count];
	if (i > 0) {
	    [parent insertItem:[NSMenuItem separatorItem] atIndex:0];
	    while (--i >= 0)
		[self addNewItemOfPath:
			[filelist objectAtIndex: i] atIndex: 0];
		[cleanItem setEnabled: YES];
	}else
		[cleanItem setEnabled: NO];
}

- (void)addNewFilepath:(NSString *)path
{
	int	cnt, idx, comp;
	PathCell	*cell;

	cnt = [filelist count];
	for (idx = 0; idx < cnt; idx++) {
		comp = [path caseInsensitiveFilenameCompare:
				[[filelist objectAtIndex:idx] path]];
		if (comp == NSOrderedSame) {
			int i;
			for (i = [fifo count] - 1; i >= 0; i--) {
				id obj = [fifo objectAtIndex:i];
				if ([obj isEqualToString:path]) {
					[fifo removeObjectAtIndex: i];
					// obj is retained by a cell in filelist
					[fifo insertObject:obj atIndex:0];
					return;
				}
			}
			break;
		}
		if (comp == NSOrderedAscending)
			break;
	}

	if (cnt == 0)
		[parent insertItem:[NSMenuItem separatorItem] atIndex:0];
	[fifo insertObject:path atIndex:0];
	cell = [PathCell cellWithPath: path];
	[filelist insertObject:cell atIndex:idx];
	[self addNewItemOfPath:cell atIndex:idx];
	for (cnt = [fifo count] - 1; cnt >= maxnum; cnt--) {
		int i;
		id obj = [fifo objectAtIndex: cnt];
		[fifo removeObjectAtIndex: cnt];
		for (i = [filelist count] - 1; i >=0; i--) {
		    if ([obj isEqualToString: [[filelist objectAtIndex: i] path]])
			break;
		}
		[parent removeItemAtIndex: i];
		[filelist removeObjectAtIndex: i];
	}

	[self checkItemsName];
	for (cnt = [filelist count] - 1; cnt >= 0; cnt--) {
		PathCell *cell = [filelist objectAtIndex: cnt];
		if ([cell menuUpdateNeeded])
			[[parent itemAtIndex: cnt] setTitle:[cell menuTitle]];
	}
}

- (void)clearAll:(id)sender
{
	int i;

	i = [filelist count];
	[filelist removeAllObjects];
	[fifo removeAllObjects];
	while (--i >= 0)
		[parent removeItemAtIndex: i];
	[cleanItem setEnabled: NO];
	if ([parent numberOfItems] > 0 && [[parent itemAtIndex:0] isSeparatorItem])
		[parent removeItemAtIndex: 0];
}

- (NSArray *)array { return fifo; }

@end
