rasinfo *loadRasterHeader(FILE *fp, int *errcode);
void freeRasterHeader(rasinfo *ras);

BOOL isGray(const rasinfo *ras);
int raster_to_pxo(const rasinfo *ras, FILE *fp, FILE *fo);
int raster_to_pgm(const rasinfo *ras, FILE *fp, FILE *fo);
int raster_to_pbm(const rasinfo *ras, FILE *fp, FILE *fo);
int raster_to_ppm(const rasinfo *ras, FILE *fp, FILE *fo);
