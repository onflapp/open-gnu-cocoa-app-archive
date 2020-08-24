@interface ArrowGraphicsChange : SimpleGraphicsChange
{
    int	arrowValue;
}

- initGraphicView:aGraphicView lineArrow:(int)anArrowValue;
- (NSString *)changeName;
- (Class)changeDetailClass;
- (int)lineArrow;

@end
