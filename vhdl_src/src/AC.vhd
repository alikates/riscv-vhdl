library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.std_logic_misc.all;

library work;
  use work.acdc_utils.all;

entity ac is
  generic (
    num_vias     : integer := 4;
    xlen         : integer := 32;
    block_word_n : integer := 4
  );
  port (
    clk         : in    std_logic;
    reset       : in    std_logic;
    pc          : in    std_logic_vector(xlen - 1 downto 0);
    address     : in    std_logic_vector(ilog2(num_vias) - 1 downto 0);
    din         : in    std_logic_vector(xlen - 1 downto 0);
    we          : in    std_logic;
    ac_tag_hits : out   std_logic_vector(num_vias - 1 downto 0);
    dout        : out   std_logic_vector(xlen - 1 downto 0)
  );
end entity ac;

architecture behavioral of ac is

  -- ac signals

  type ac_tags_type is array(num_vias - 1 downto 0) of std_logic_vector(xlen - 1 downto 0);

  signal ac_mem : ac_tags_type;

  signal valid : std_logic_vector(num_vias - 1 downto 0);

begin

  address_lines : for i in 0 to num_vias - 1 generate
    ac_tag_hits(i) <= '1' when (ac_mem(i) = pc and valid(i) = '1') else
                      '0';
  end generate address_lines;

  wr_ac_data : process (clk, we, address) is
  begin

    if (clk'event and clk = '1') then
      if (reset = '1') then
        valid <= (others => '0');

        for i in 0 to num_vias - 1 loop

          ac_mem(i) <= (others => '0');

        end loop;

      elsif (we = '1') then
        valid(to_uint(address))  <= '1';
        ac_mem(to_uint(address)) <= din;
      end if;
    end if;

  end process wr_ac_data;

  dout <= ac_mem(to_uint(address));

end architecture behavioral;
