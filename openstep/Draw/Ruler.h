@interface Ruler : NSView <Ruler>
{
    NSFont *font;
    float descender;
    float startX;
    float lastlp, lasthp;
    BOOL zeroAtViewOrigin;
    BOOL notHidden;
}

+ (float)width;

- setFont:(NSFont *)aFont;
- (void)drawRect:(NSRect)rects;

@end
