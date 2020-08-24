#import <Foundation/NSObject.h>

@class NSImage, NSData;

@interface BackgCtr: NSObject
{
	id	backWin;
	id	fullscreenCtr;
}

+ (NSZone *)zoneForBackground;
+ (void)clearZone;
- (id)init;
- (void)setFullScreen:(id)controller;
- (void)cleanBackground:(id)sender;
- (void)toggleFront:(id)sender;
- (void)makeFront:(id)sender;
- (id)setImage:(NSImage *)backimage hasAlpha:(BOOL)alpha with:(int)method;
- (id)setStream:(NSData *)data with:(int)method;

@end
