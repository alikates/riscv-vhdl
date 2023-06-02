----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:    15:16:09 05/14/2014
-- Design Name:
-- Module Name:    addr_counter - Behavioral
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
  -- Uncomment the following library declaration if using
  -- arithmetic functions with Signed or Unsigned values
  use ieee.numeric_std.all;

entity counter is
  port (
    clk          : in    std_logic;
    reset        : in    std_logic;
    count_enable : in    std_logic;
    load         : in    std_logic;
    d_in         : in    std_logic_vector(7 downto 0);
    count        : out   std_logic_vector(7 downto 0)
  );
end entity counter;

architecture behavioral of counter is

  signal int_count : std_logic_vector(7 downto 0);

begin

  process (clk) is
  begin

    if (clk='1' and clk'event) then
      if (reset='1') then
        int_count <= (others => '0');        -- pone todo a 0
      elsif (load='1') then                  -- si load vale 1 el contador no hace nada
        int_count <= d_in;
      elsif (count_enable='1') then
        int_count <= int_count + "00000001"; -- si enable vale uno y load vale 0 el contador cuenta.
      end if;
    end if;

  end process;

  count <= int_count;

end architecture behavioral;

