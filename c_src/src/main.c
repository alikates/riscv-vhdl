#include <print.h>
#include <mtimer.h>
#include <acdc.h>

// Example main
int main() {
    acdc_set_drp(1, 0x00000258);
    print_str("Hello world!\n");
    
    // Make mtimer interrupt every 2000 ticks
    set_mtimer_period(2000);
    enable_mtimer();

    // Wait
    while(1);
}
