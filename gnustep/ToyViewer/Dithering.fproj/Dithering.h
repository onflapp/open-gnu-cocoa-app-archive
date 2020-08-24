@protocol Dithering

- (void)reset:(int)pixellevel width:(int)width;
- (void)reset:(int)pixellevel;
- (void)dealloc;
- (unsigned char *)buffer;
- (unsigned char *)getNewLine;
- (const unsigned char *)threshold;

@end
