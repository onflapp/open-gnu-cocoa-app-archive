@interface LineWidthGraphicsChange : SimpleGraphicsChange
{
    float widthValue;
}

- initGraphicView:aGraphicView lineWidth:(float)aWidth;
- (NSString *)changeName;
- (Class)changeDetailClass;
- (float)lineWidth;

@end
