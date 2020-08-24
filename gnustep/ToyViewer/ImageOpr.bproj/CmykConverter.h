#import "../ImgOperator.h"

@interface CmykConverter:ImgOperator

+ (int)opcode;
+ (NSString *)oprString;

- (id)waitingMessage;
- (BOOL)checkInfo:(NSString *)filename;
- (BOOL)makeNewPlane:(unsigned char **)newmap with:(commonInfo *)newinf;

@end
