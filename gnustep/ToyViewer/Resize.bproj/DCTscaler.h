#import <Foundation/NSObject.h>
#import "../dcttable.h"

// #define  DCTMAXSIZE	20

typedef	double	DCTmat[ DCTMAXSIZE ][ DCTMAXSIZE ];
typedef	unsigned char *PIXmat[ DCTMAXSIZE ];

@interface DCTscaler : NSObject
{
	int	aSize, bSize;
	DCTmat	Ca, Cat, Cb, Cbt;
}

- (id)init:(int)bsize :(int)asize;	/*  bsize / asize  */
- (void)DCTrescale:(PIXmat)dst from:(PIXmat)src;

@end
