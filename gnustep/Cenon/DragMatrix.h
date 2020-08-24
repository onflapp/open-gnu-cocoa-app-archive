
#import <AppKit/AppKit.h>

@interface DragMatrix:NSMatrix
{

}


@end

@interface DragMatrixTarget:NSObject
{

}
- (const char*)filenameForCell:cell;
- (void)renameCell:iCell to:(const char*)newName;
@end
