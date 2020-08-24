#import "../ImgOperatorClipped.h"
#import "../colorLuv.h"

enum {
	cnv_Uniq, cnv_Match, cnv_Grad, cnv_Simu
};

@interface ColorChanger:ImgOperatorClipped
{
	int	origclr[MAXPLANE];
	int	newclr[MAXPLANE];
	int	diffclr[MAXPLANE];
	float	comparison;
	int	cnvMethod;
	BOOL	isMono;
	t_Luv	origluv[3];
	int	cdiffwid;
}

+ (int)opcode;
+ (NSString *)oprString;

- (void)setColor:(const int *)ocl to:(const int *)ncl method:(int)method with:(float)comp;
- (void)setupWith:(ToyView *)tv;
- (commonInfo *)makeNewInfo;
- (BOOL)makeNewPlane:(unsigned char **)newmap with:(commonInfo *)newinf;

@end
