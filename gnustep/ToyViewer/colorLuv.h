/*
	colorLuv.h
		RGB <--> L+u+v+ Color Space

	for ToyViewer 3.10	May 1999  T. Ogihara
*/

typedef short	t_Luv;

/* Note: 3.0 should be 4.0 according to the definition of L+u+v+ */
#define  real2LuvL(x)	((int)((x) * 3.0))
#define  LuvL2real(x)	((x) / 3.0)
#define  real2Luv(x)	((int)(x + 140.5))
#define  Luv2real(x)	((x) - 140.0)
#define  LuvMaxL	300		/* > 99.888 * 3.0 */
#define  LuvTrans	500		/* > 99.888 * 3.0 */
#define  isLuvTrans(x)	((x) > 499)	/* x is L element of Luv */
#define  LuvMonoWidth	300		/* = 99.888 * 3.0 */
#define  LuvColorWidth	360

void setupLuv(void);
void transRGBtoLuv(t_Luv luv[], const int rgb[], int cnum, int alp);
int getLuv(t_Luv luv[], int cnum, int alp);
int allocLuvPlanes(t_Luv **planes, int size, int pnum);
