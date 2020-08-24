#import <Foundation/NSObject.h>
#import "ImgToolCtrlAbs.h"

#define  MAX_TAG	11

@class NSMenuItem;

@interface ImageOpCtr : NSObject
{
	id	imageOpr;
	id	toolPanel;
	id	toolView;
	id	toolButton;
	id	monoPanel;
	id	rotatePanel;
	id	resizePanel;
	id	reducePanel;
	int	currentTab;
	ImgToolCtrlAbs *tag2control[MAX_TAG];
}

- (id)init;

/* NSMenuActionResponder Protocol */
- (BOOL)validateMenuItem:(NSMenuItem *)aMenuItem;

- (void)loadNewTool:(id)sender;
- (void)forwardInvocation:(NSInvocation *)anInvocation;
- (void)saveData;

- (void)activateToolPanel:(id)sender;
- (void)rotateByAngle:(id)sender;
- (void)doResize:(id)sender by:(int)op;
- (void)convertCMYKtoRGB:(id)sender;

- (void)flip:(id)sender;
- (void)readyForResize:(id)sender;
- (void)newBitmap:(id)sender;
- (void)reduce:(id)sender;

@end
