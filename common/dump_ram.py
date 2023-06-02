from elftools.elf.elffile import ELFFile

# Tool for creating vhdl RAM files from an elf file

def write_vhdl_memory(ram, data):
    '''Writes VHDL RAM memory'''
    with open(f'../vhdl_src/src/B_RAM_{ram}.vhd', "w", encoding="utf8") as ram_file:
        with open("../common/vhdl_rams/tail.txt", "r", encoding="utf8") as tail:
            tail_lines = tail.readlines()
        with open(f'../common/vhdl_rams/head_{ram}.txt', "r", encoding="utf8") as ram_head:
            ram_file.writelines(ram_head.readlines())
        addr = 0
        for j in data:
            ram_file.write(f'\t\t{addr} => x\"{j:02x}\",\n')
            addr += 1
        ram_file.writelines(tail_lines)

def section_as_bytes(efile, section_name):
    data = ""
    with open(efile, 'rb') as fil:
        elf_file = ELFFile(fil)
        seg_data = elf_file.get_section_by_name(section_name).data()
        ram = []
        for i in range(0, len(seg_data), 4):
            b = bytearray(seg_data[i:i+4])
            b.reverse()
            byte_str = b.hex()
            data += f'x\"{b.hex():s}\",\n'

    return data

# Main func
myfile = "build/main"
print(section_as_bytes(myfile, ".init") + section_as_bytes(myfile, ".text"))
print(section_as_bytes(myfile, ".rodata") + section_as_bytes(myfile, ".sdata"))
# for i in range(4):
#     write_vhdl_memory(i, rams[i])
