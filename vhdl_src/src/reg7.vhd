----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:    15:02:29 04/04/2014
-- Design Name:
-- Module Name:    reg32 - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
-- use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
-- library UNISIM;
-- use UNISIM.VComponents.all;

entity reg7 is
  port (
    din   : in    std_logic_vector(10 downto 0);
    clk   : in    std_logic;
    reset : in    std_logic;
    load  : in    std_logic;
    dout  : out   std_logic_vector(10 downto 0)
  );
end entity reg7;

architecture behavioral of reg7 is

begin

  sync_proc : process (clk) is
  begin

    if (clk'event and clk = '1') then
      if (reset = '1') then
        dout <= "00000000000";
      else
        if (load='1') then
          dout <= din;
        end if;
      end if;
    end if;

  end process sync_proc;

end architecture behavioral;

