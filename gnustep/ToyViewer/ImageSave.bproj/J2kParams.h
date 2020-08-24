/*
 *  J2kParams.h
 *  ToyViewer
 */

#ifndef _J2k_Params_
#define _J2k_Params_

/* For JPEG2000 */
#define  Tag_jp2	0
#define  Tag_jpc	1
#define  Tag_rate	0
#define  Tag_resol	1
#define  Tag_compo	2
#define  TagIsLegalProg(x)	((x) >= 0 && (x) <= Tag_compo)
#define  Lossless	(-1)

#endif
