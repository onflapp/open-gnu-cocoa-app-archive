#ifndef CROSS_45

#include <sys/time.h>	/* to get the current time */
#include <VHFShared/vhfCompatibility.h>

/* for debugging purposes */
#define CROSS_45(p)	{	PSgsave(); PSsetlinewidth(0);\
				PSmoveto(((p).x-2), ((p).y-2));\
				PSlineto(((p).x+2), ((p).y+2));\
				PSmoveto(((p).x+2), ((p).y-2));\
				PSlineto(((p).x-2), ((p).y+2)); PSstroke();PSgrestore();}
#define CROSS_90(p)	{	PSgsave(); PSsetlinewidth(0);\
				PSmoveto(((p).x-2), ((p).y));\
				PSlineto(((p).x+2), ((p).y));\
				PSmoveto(((p).x), ((p).y-2));\
				PSlineto(((p).x), ((p).y+2)); PSstroke();PSgrestore();}
#define CROSS_45_s(p)	{	PSgsave(); PSsetlinewidth(0);\
				PSmoveto(((p).x-1), ((p).y-1));\
				PSlineto(((p).x+1), ((p).y+1));\
				PSmoveto(((p).x+1), ((p).y-1));\
				PSlineto(((p).x-1), ((p).y+1)); PSstroke();PSgrestore();}
#define CROSS_90_s(p)	{	PSgsave(); PSsetlinewidth(0);\
				PSmoveto(((p).x-1), ((p).y));\
				PSlineto(((p).x+1), ((p).y));\
				PSmoveto(((p).x), ((p).y-1));\
				PSlineto(((p).x), ((p).y+1)); PSstroke();PSgrestore();}
#define CROSS_45_S(p, s)	{	PSgsave(); PSsetlinewidth(0);\
					PSmoveto(((p).x-(s)), ((p).y-(s)));\
					PSlineto(((p).x+(s)), ((p).y+(s)));\
					PSmoveto(((p).x+(s)), ((p).y-(s)));\
					PSlineto(((p).x-(s)), ((p).y+(s))); PSstroke();PSgrestore(); \
				}
#define CROSS_90_S(p, s)	{	PSgsave(); PSsetlinewidth(0);\
					PSmoveto(((p).x-(s)), ((p).y));\
					PSlineto(((p).x+(s)), ((p).y));\
					PSmoveto(((p).x), ((p).y-(s)));\
					PSlineto(((p).x), ((p).y+(s))); PSstroke();PSgrestore(); \
				}
#define DRAWLINE(l)		{	PSgsave();PSsetlinewidth(0);\
					PSmoveto((l).begin.x, ((l).begin.y));\
					PSlineto((l).end.x, ((l).end.y));PSstroke();PSgrestore(); \
				}
#define DRAWCURVE(c)	{	PSgsave();PSsetlinewidth(0);\
				PSmoveto((c).p0.x, ((c).p0.y));\
				PScurveto((c).p1.x, ((c).p1.y),\
					 (c).p2.x, ((c).p2.y),\
					 (c).p3.x, ((c).p3.y));PSstroke();PSgrestore();\
			}
#define DRAWARC(a)		{	SVPoint	points[2]; \
					arcStartEndPoints(&(a), points); \
					PSgsave();PSsetlinewidth(0);\
					PSmoveto(points[0].x, points[0].y);\
					PSarc((a).center.x, ((a).center.y), ((a).radius.x), \
					(a).begAngle, (a).endAngle); PSstroke();PSgrestore(); \
				}
#define DRAWRECT(r)	{ PSgsave(); NSFrameRectWithWidth(r, 0.0); PSgrestore(); }

/* struct timeval t1, t2;
 * gettimeofday (&t1, NULL);
 */
#define TOUSEC(t)		((((t).tv_sec-747841200)*1000) + (t).tv_usec)
#define TIMEDIFF(t1, t2)	(Diff(TOUSEC(t1), TOUSEC(t2)))
#define ADDTIMES(t1, t2)	(struct timeval){(t1).tv_sec =((t1.tv_sec+(t2).tv_sec)*1000+(t1).tv_usec+(t2).tv_usec)/1000, \
    (t1).tv_usec=((t1.tv_sec+(t2).tv_sec)*1000+(t1).tv_usec+(t2).tv_usec)%1000}
#define TIMEUSEC(t)		((t).tv_sec*1000 + (t).tv_usec)
#define INITTIME		{0, 0};

#endif
