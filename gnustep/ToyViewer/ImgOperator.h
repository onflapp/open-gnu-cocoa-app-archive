#import <AppKit/AppKit.h>
#import "ImgOprAbs.h"

@class ToyWin, ToyView;

@interface ImgOperator: ImgOprAbs
{
	commonInfo	*cinf;		/* just pointer */
	ToyWin		*parentw;	/* just pointer */
	unsigned char	*map[MAXPLANE];	/* just pointer */
	NSString	*newfname;	/* auto released */
	id		msgtext;	/* just pointer */
}

/* Virtual */
+ (BOOL)detectParent;

/* Virtual */
- (BOOL)makeNewPlane:(unsigned char **)newmap with:(commonInfo *)newinf;
- (id)waitingMessage;
- (BOOL)checkInfo:(NSString *)filename;
- (commonInfo *)makeNewInfo;
- (void)setupWith:(ToyView *)tv;
/* LOCAL */
- (int)doOperation;
- (int)doEPSOperation;

- (void)createNewImage;

@end
