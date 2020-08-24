#import "DirList.h"
#import <Foundation/NSString.h>
#import <Foundation/NSPathUtilities.h>

static NSArray *extlist = nil;

#ifdef _NeXT_Style_

static int NXstrcmp(const unsigned char *a, const unsigned char *b)
{
	/* 040 sp a  b  c  d  e  f  g */
	/* 050 h  i  j  k  l  m  n  o */
	/* 060 p  q  r  s  t  u  v  w */
	/* 070 x  y  z  0  1  2  3  4 */
	/* 100 5  6  7  8  9  -- -- --*/
	/* 110 -- !  "  #  $  %  &  ' */
	/* 120 (  )  *  +  ,  -  .  / */
	/* 130 -- -- :  ;  <  =  >  ? */
	/* 140 @  -- -- [  \  ]  ^  _ */
	/* 150 `  -- -- {  |  }  ~  --*/

	static unsigned char tab[96] =
	/* 040 sp  !  "  #  $  %  &  ' */	" IJKLMNO"
	/* 050  (  )  *  +  ,  -  .  / */	"PQRSTUVW"
	/* 060  0  1  2  3  4  5  6  7 */	";<=>?@AB"
	/* 070  8  9  :  ;  <  =  >  ? */	"CDZ[\\]^_"
	/* 100  @  A  B  C  D  E  F  G */	"`!\"#$%&\'"
	/* 110  H  I  J  K  L  M  N  O */	"()*+,-./"
	/* 120  P  Q  R  S  T  U  V  W */	"01234567"
	/* 130  X  Y  Z  [  \  ]  ^  _ */	"89:cdefg"
	/* 140  `  a  b  c  d  e  f  g */	"h!\"#$%&\'"
	/* 150  h  i  j  k  l  m  n  o */	"()*+,-./"
	/* 160  p  q  r  s  t  u  v  w */	"01234567"
	/* 170  x  y  z  {  |  }  ~ del*/	"89:klmn\177";

	int x, y;

	for ( ;  ; a++, b++) {
		if ((x = *a) > ' ' || x < 0x7f) x = tab[x - ' '];
		if ((y = *b) > ' ' || y < 0x7f) y = tab[y - ' '];
		if ((x -= y) != 0)
			return x;
		if (!y) return 0;
	}
}

static int NXalphasort(id str1, id str2, void *context)
{
	int	v = NXstrcmp([str1 cString], [str2 cString]);
	return (v == 0) ? NSOrderedSame
		: ((v > 0) ? NSOrderedDescending: NSOrderedAscending);
}

#endif /* _NeXT_Style_ */


@implementation DirList

+ (void)setExtList:(NSArray *)list
{
	[list retain];
	[extlist release];
	extlist = list;
}


- (id)init
{
	[super init];
	namelist = nil;
	ignoreDots = NO;
	return self;
}

- (void)dealloc
{
	if (namelist)
		[namelist release];
	[super dealloc];
}

- (void)setIgnoreDottedFiles:(BOOL)flag
{
	ignoreDots = flag;
}

- (int)getDirList:(NSString *)dirname
{
	NSFileManager *manager;
	id	d;
	int	i, n;

	manager = [NSFileManager defaultManager];
	d = [manager directoryContentsAtPath:dirname];
	if (extlist)
		d = [d pathsMatchingExtensions:extlist];
	if ((n = [d count]) == 0)
		return 0;
	if (ignoreDots) {
		id ign = [NSMutableArray arrayWithCapacity:1];
		for (i = 0; i < n; i++) {
			id tmp = [d objectAtIndex:i];
			if ([tmp characterAtIndex:0] != '.')
				[ign addObject:tmp];
		}
		d = ign;
	}
#ifdef _NeXT_Style_
	namelist = [d sortedArrayUsingFunction:NXalphasort context:nil];
#else
	namelist = [d sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
#endif
	[namelist retain];
	return [namelist count];
}

- (int)fileNumber
{
	return [namelist count];
}

- (NSString *)filenameAt:(int)pos
{
	return ([namelist count] > pos)
		? [namelist objectAtIndex:pos] : @"";
	// Thanks, R.Berber.
}

@end
