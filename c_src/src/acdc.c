#include <acdc.h>


volatile unsigned long * ACDC_BASE_ADDRESS = (unsigned long *) 0x80000000;
#define ACDC_IDX(i) *(ACDC_BASE_ADDRESS + i)

void acdc_set_drp(uint8_t idx, unsigned long address) {
	if (idx >= 4)
		return;

	ACDC_IDX(idx) = address;
}
