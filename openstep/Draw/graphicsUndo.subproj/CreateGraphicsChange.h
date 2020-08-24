@interface CreateGraphicsChange : Change
{
    id 		graphicView;
    Graphic	*graphic;
    NSString *changeName;
    StartEditingGraphicsChange *startEditingChange;
}

- initGraphicView:aGraphicView graphic:aGraphic;
- (NSString *)changeName;
- (void)undoChange;
- (void)redoChange;
- (BOOL)incorporateChange:change;

@end
