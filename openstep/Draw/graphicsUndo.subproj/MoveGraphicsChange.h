@interface MoveGraphicsChange : SimpleGraphicsChange
{
    NSPoint	undoVector;
    NSPoint	redoVector;
}

- initGraphicView:aGraphicView vector:(NSPoint)aVector;
- (NSString *)changeName;
- (Class)changeDetailClass;
- (NSPoint)undoVector;
- (NSPoint)redoVector;

@end
