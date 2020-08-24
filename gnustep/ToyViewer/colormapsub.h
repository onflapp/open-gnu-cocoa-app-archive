/* colormapsub.h */

#define  EnoughMemory	1

#if EnoughMemory
  typedef int indexint;
#else
  typedef short indexint;
#endif

void quicksort(int, indexint *, int (*)(int));
