/* rotate.c */

void rotate_size(float angle, const commonInfo *cinf, commonInfo *newinf);
int sub_rotate(int op, float angle, const commonInfo *cinf, commonInfo *newinf,
		int idx[], unsigned char **working);
