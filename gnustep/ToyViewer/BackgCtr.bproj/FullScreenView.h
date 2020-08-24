#import "Background.h"
#import "../PlayControl.h"

@interface FullScreenView: Background
{
	id <PlayControl>	controller;
}

+ (void)initialize;

- (id)init;
- (BOOL)becomeFirstResponder;
- (void)resetCursorRects;
- (void)setController:(id <PlayControl>)obj;
- (void)mouseDown:(NSEvent *)event;
- (void)keyDown:(NSEvent *)event;

@end
