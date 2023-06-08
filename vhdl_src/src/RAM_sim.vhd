----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:    14:12:11 04/04/2014
-- Design Name:
-- Module Name:    memoriaRAM - Behavioral
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;
  use ieee.numeric_std.all;

library work;
  use work.acdc_utils.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
-- use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
-- library UNISIM;
-- use UNISIM.VComponents.all;
-- Memoria RAM de 128 oalabras de 32 bits

entity ram_128_32 is
  port (
    clk    : in    std_logic;
    addr   : in    std_logic_vector(31 downto 0); -- Dir
    din    : in    std_logic_vector(31 downto 0); -- entrada de datos para el puerto de escritura
    we     : in    std_logic;                     -- write enable
    re     : in    std_logic;                     -- read enable
    enable : in    std_logic;                     -- solo se lee o escribe si enable está activado
    dout   : out   std_logic_vector(31 downto 0)
  );
end entity ram_128_32;

architecture behavioral of ram_128_32 is

  type ramtype is array(0 to 2047) of std_logic_vector(31 downto 0);

  signal ram   : ramtype := (
                204 => x"6c6c6548",
                205 => x"6f77206f",
                206 => x"21646c72",
                207 => x"0000000a",
                208 => x"6b636954",
                209 => x"00000a21",
                210 => x"78656e55",
                211 => x"74636570",
                212 => x"6d206465",
                213 => x"73756163",
                214 => x"6f662065",
                215 => x"2c646e75",
                216 => x"00000020",
                217 => x"80000000",
                others => (others => '0')
                );
  signal dir_7 : std_logic_vector(10 downto 0);

begin

  dir_7 <= addr(12 downto 2); -- como la memoria es de 128 plalabras no usamos la dirección completa sino sólo 7 bits. Como se direccionan los bytes, pero damos palabras no usamos los 2 bits menos significativos

  process (clk) is
  begin

    if (clk'event and clk = '1') then
      if ((we = '1') and (enable = '1')) then -- sólo se escribe si WE vale 1
        ram(to_uint(dir_7)) <= din;
        -- report "Simulation time : " & time'image(now) & ".  Data written: " & integer'image(to_integer(signed(din))) & ", in ADDR = " & integer'image(to_integer(signed(addr)));
      end if;
    end if;

  end process;

  dout <= ram(to_uint(dir_7)) when ((re='1') and (enable = '1')) else
          (others => '0'); -- sólo se lee si RE vale 1

end architecture behavioral;

