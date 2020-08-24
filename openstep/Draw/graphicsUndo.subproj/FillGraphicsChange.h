@interface FillGraphicsChange : SimpleGraphicsChange
{
    int fill;
}

- initGraphicView:aGraphicView;
- initGraphicView:aGraphicView fill:(int)fillValue;
- (NSString *)changeName;
- (Class)changeDetailClass;
- (int)fill;

@end
