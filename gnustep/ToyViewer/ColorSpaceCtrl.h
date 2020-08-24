#import  <Foundation/NSObject.h>
#import  <Foundation/NSString.h>
#import  <AppKit/NSGraphics.h>
#import  "common.h"

@interface ColorSpaceCtrl: NSObject
{
}

+ (void)initialize;
+ (enum ns_colorspace)colorSpaceID:(NSString *)name;
+ (NSString *)colorSpaceName:(enum ns_colorspace)csid;

@end
