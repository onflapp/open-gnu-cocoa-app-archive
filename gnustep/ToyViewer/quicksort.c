#include  <stdlib.h>
#include "colormapsub.h"

/* ----------------------------------------------------------------
	QUICK SORT by Haruhiko Okumura
	奥村晴彦「Ｃ言語による最新アルゴリズム事典」（技術評論社）
	modified by T. Ogihara
----------------------------------------------------------------- */

static void inssort(int n, indexint *a, int (*qval)(int))
{
	int i, j, val;
	indexint x;

	for (i = 1; i < n; i++) {
		val = qval(x = a[i]);
		for (j = i - 1; j >= 0 && qval(a[j]) > val; j--)
			a[j + 1] = a[j];
		a[j + 1] = x;
	}
}

#define QS_THRESHOLD	10
#define QS_STACKSIZE	32	/* たかだか int のビット数程度 */

void quicksort(int n, indexint *ar, int (*qval)(int))
{
	int i, j, left, right, p;
	int leftstack[QS_STACKSIZE], rightstack[QS_STACKSIZE];
	indexint t;
	int x;

	left = 0;  right = n - 1;  p = 0;
	for ( ;  ; ) {
		if (right - left <= QS_THRESHOLD) {
			if (p == 0) break;
			p--;
			left = leftstack[p];
			right = rightstack[p];
		}
		x = qval(ar[(left + right) / 2]);
		i = left;  j = right;
		for ( ;  ; ) {
			while (qval(ar[i]) < x) i++;
			while (x < qval(ar[j])) j--;
			if (i >= j) break;
			t = ar[i];  ar[i] = ar[j];  ar[j] = t;
			i++;  j--;
		}
		if (i - left > right - j) {
			if (i - left > QS_THRESHOLD) {
				leftstack[p] = left;
				rightstack[p] = i - 1;
				p++;
			}
			left = j + 1;
		} else {
			if (right - j > QS_THRESHOLD) {
				leftstack[p] = j + 1;
				rightstack[p] = right;
				p++;
			}
			right = i - 1;
		}
	}
	inssort(n, ar, qval);
}
