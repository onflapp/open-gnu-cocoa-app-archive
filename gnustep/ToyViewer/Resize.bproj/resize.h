/* resize.m */
commonInfo *makeDCTResizedMap(commonInfo *cinf, int bsz, int asz,
		unsigned char *map[], unsigned char *newmap[], BOOL wmsg);

commonInfo *makeBilinearResizedMap(float, float, commonInfo *,
	unsigned char **, unsigned char **);
