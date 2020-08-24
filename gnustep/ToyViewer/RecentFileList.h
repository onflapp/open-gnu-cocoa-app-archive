#import <Foundation/NSObject.h>
//# <AppKit/NSMenu.h>
#import <AppKit/NSMenuItem.h>

@class NSString, NSArray, NSMenu; //erk pb with include GNUstep

@interface RecentFileList : NSObject
{
	NSMenu	*parent;
	id <NSMenuItem>	cleanItem;
	id	target;
	SEL	action;
	id	filelist;
	id	fifo;
	int	maxnum;
}

+ (id)sharedList;
- (id)init;
- (void)dealloc;
- (void)setPropertyList:(id)list;
- (void)setTarget:(id)obj andAction:(SEL)sel;
- (void)menuAction:(id)sender;
- (void)setMaxFiles:(int)max;
- (void)makeSubMenuOf:(NSMenu *)menu;

- (void)addNewFilepath:(NSString *)path;
- (void)clearAll:(id)sender;

- (NSArray *)array;

@end
