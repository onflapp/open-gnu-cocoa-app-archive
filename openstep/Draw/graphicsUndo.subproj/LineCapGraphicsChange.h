@interface LineCapGraphicsChange : SimpleGraphicsChange
{
    int	capValue;
}

- initGraphicView:aGraphicView lineCap:(int)aCapValue;
- (NSString *)changeName;
- (Class)changeDetailClass;
- (int)lineCap;

@end
