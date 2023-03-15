// file = 0; split type = patterns; threshold = 100000; total count = 0.
#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include "rmapats.h"

void  hsG_0__0 (struct dummyq_struct * I1288, EBLK  * I1282, U  I685);
void  hsG_0__0 (struct dummyq_struct * I1288, EBLK  * I1282, U  I685)
{
    U  I1546;
    U  I1547;
    U  I1548;
    struct futq * I1549;
    struct dummyq_struct * pQ = I1288;
    I1546 = ((U )vcs_clocks) + I685;
    I1548 = I1546 & ((1 << fHashTableSize) - 1);
    I1282->I727 = (EBLK  *)(-1);
    I1282->I731 = I1546;
    if (I1546 < (U )vcs_clocks) {
        I1547 = ((U  *)&vcs_clocks)[1];
        sched_millenium(pQ, I1282, I1547 + 1, I1546);
    }
    else if ((peblkFutQ1Head != ((void *)0)) && (I685 == 1)) {
        I1282->I733 = (struct eblk *)peblkFutQ1Tail;
        peblkFutQ1Tail->I727 = I1282;
        peblkFutQ1Tail = I1282;
    }
    else if ((I1549 = pQ->I1189[I1548].I745)) {
        I1282->I733 = (struct eblk *)I1549->I744;
        I1549->I744->I727 = (RP )I1282;
        I1549->I744 = (RmaEblk  *)I1282;
    }
    else {
        sched_hsopt(pQ, I1282, I1546);
    }
}
#ifdef __cplusplus
extern "C" {
#endif
void SinitHsimPats(void);
#ifdef __cplusplus
}
#endif
