OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY
{
	rom (xa) :  ORIGIN = 0x00000000, LENGTH = 4K
	ram (wxa) : ORIGIN = 0x00000800, LENGTH = 4K
}

SECTIONS
{
	.init : { *(.init) } >rom
	.text : {
		*(.text);
		. = ALIGN(4);
	} >rom
	.data : { *(.data); . = ALIGN(4); } >rom
	.rodata : { *(.rodata.*); . = ALIGN(4); } >rom
	.sdata : { *(.sdata); . = ALIGN(4); } >rom
	.bss : { *(.bss) } >ram
	.sbss : { *(.sbss) } >ram
	.stack :
	{
		. = ALIGN(16);
		. += 800;
		_stack_top = .;
	} >ram
}
