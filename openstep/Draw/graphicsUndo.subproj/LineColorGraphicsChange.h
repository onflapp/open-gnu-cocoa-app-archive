@interface LineColorGraphicsChange : SimpleGraphicsChange
{
    NSColor *color;
}

- initGraphicView:aGraphicView color:(NSColor *)aColor;
- (NSString *)changeName;
- (Class)changeDetailClass;
- (NSColor *)lineColor;

@end
