@interface LineJoinGraphicsChange : SimpleGraphicsChange
{
    int	joinValue;
}

- initGraphicView:aGraphicView lineJoin:(int)aJoinValue;
- (NSString *)changeName;
- (Class)changeDetailClass;
- (int)lineJoin;

@end
