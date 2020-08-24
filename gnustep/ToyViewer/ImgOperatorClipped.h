#import "ImgOperator.h"

@interface ImgOperatorClipped:ImgOperator
{
	BOOL	selected;
	BOOL	outside;
	int	xorg, yorg, xend, yend;
}

+ (BOOL)detectParent;

- (id)init;
- (void)setOutside:(BOOL)flag;

/* overwrite */
- (void)setupWith:(ToyView *)tv;

@end
