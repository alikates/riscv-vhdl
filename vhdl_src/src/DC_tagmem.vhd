
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.std_logic_misc.all;

library work;
  use work.acdc_utils.all;

entity dc_tagmem is
  generic (
    num_vias     : integer := 4;
    xlen         : integer := 32;
    block_word_n : integer := 4
  );
  port (
    clk         : in    std_logic;
    reset       : in    std_logic;
    address     : in    std_logic_vector(xlen - 1 downto ilog2(block_word_n) + 2);
    address_out : out   std_logic_vector(xlen - 1 downto 0);
    tag_we      : in    std_logic; -- write enable para la memoria de etiquetas
    set_dirty   : in    std_logic; -- si estamos accediendo a la cache en lectura o escritura
    hit         : out   std_logic; -- indica si es acierto
    dirty       : out   std_logic;
    valid       : out   std_logic
  );
end entity dc_tagmem;

architecture behavioral of dc_tagmem is

  signal tag_mem      : std_logic_vector(xlen - 1 downto ilog2(block_word_n) + 2);
  signal dirty_int    : std_logic;
  signal valid_int    : std_logic;
  signal internal_hit : std_logic;

begin

  main : process (clk) is
  begin

    if (clk'event and clk = '1') then                     -- last block write and tag write can be done simultaneously
      if (reset = '1') then
        tag_mem   <= (others => '0');
        dirty_int <= '0';
        valid_int <= '0';
      elsif (tag_we = '1') then                           -- fetching data from memory, clean
        valid_int <= '1';                                 -- assure line is valid
        tag_mem   <= address;
        if (set_dirty = '1') then
          dirty_int <= '1';
        end if;
      elsif (set_dirty = '1' and internal_hit = '1') then -- writing to cache/mem, dirty if hit
        valid_int <= '1';                                 -- assure line is valid
        dirty_int <= '1';                                 -- hit on write, line dirty
      end if;
    end if;

  end process main;

  valid        <= valid_int;
  dirty        <= dirty_int;
  internal_hit <= '1' when (tag_mem = address) and (valid_int = '1') else
                  '0';
  hit          <= internal_hit;

  address_out(xlen - 1 downto ilog2(block_word_n) + 2) <= tag_mem;
  address_out(ilog2(block_word_n) + 2 - 1 downto 0)    <= (others => '0');

end architecture behavioral;
