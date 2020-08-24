#import "../ImgOperator.h"
#import "../common.h"

enum {	S_Rect 		= 0,
	S_RoundRect	= 1,
	S_Oval		= 2,
	S_BezelConvex	= 3,
	S_BezelConcave	= 4,
	S_AquaRect	= 5,
	S_AquaOval	= 6
};


@interface SoftFramer:ImgOperator
{
	int	shape;
	float	ratio;
	int	bgcolor[MAXPLANE];
	BOOL	useAlpha;
	int	sq_width, sq_x, sq_y;
	float	t_rad;
	float	ov_x, ov_y;
}

+ (int)opcode;
+ (NSString *)oprString;

- (BOOL)isColorful:(int *)clr;
- (BOOL)isColorImageMade;

- (void)setFrame:(int)sval bgColor:(int *)color withAlpha:(BOOL)alpf;
- (void)setFrameRatio:(float)rval;
- (void)setFrameWidth:(int)wid;
- (BOOL)makeNewPlane:(unsigned char **)newmap with:(commonInfo *)newinf;
- (id)waitingMessage;
- (commonInfo *)makeNewInfo;

@end
