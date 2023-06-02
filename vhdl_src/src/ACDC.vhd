library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.std_logic_misc.all;

library work;
  use work.acdc_utils.all;

entity acdc is
  generic (
    num_vias     : integer := 4;
    xlen         : integer := 32;
    block_word_n : integer := 4
  );
  port (
    clk             : in    std_logic;
    reset           : in    std_logic;
    addr            : in    std_logic_vector(xlen - 1 downto 0);
    pc              : in    std_logic_vector(xlen - 1 downto 0);
    din             : in    std_logic_vector(xlen - 1 downto 0);
    ac_we           : in    std_logic;
    dc_we           : in    std_logic;
    re              : in    std_logic;
    wb_read         : in    std_logic;
    tags_we         : in    std_logic;
    set_dirty       : in    std_logic;
    access_mode     : in    std_logic_vector(1 downto 0); -- "00" word, "01" half-word, "10" byte
    hit             : out   std_logic;
    dirty           : out   std_logic;
    valid           : out   std_logic;
    dout            : out   std_logic_vector(xlen - 1 downto 0);
    ac_addr         : out   std_logic;
    drp             : out   std_logic;
    wb_tag_addr_out : out   std_logic_vector(xlen - 1 downto 0)
  );
end entity acdc;

architecture behavioral of acdc is

  component ac is
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
  end component ac;

  component dc is
    generic (
      num_vias     : integer := 4;
      xlen         : integer := 32;
      block_word_n : integer := 4
    );
    port (
      clk             : in    std_logic;
      reset           : in    std_logic;
      addr            : in    std_logic_vector(xlen - 1 downto 0);
      din             : in    std_logic_vector(xlen - 1 downto 0);
      we              : in    std_logic;
      re              : in    std_logic;
      wb_read         : in    std_logic;
      drp_index       : in    std_logic_vector(num_vias - 1 downto 0);
      tags_we         : in    std_logic;
      set_dirty       : in    std_logic;
      access_mode     : in    std_logic_vector(1 downto 0); -- "00" word, "01" half-word, "10" byte
      hit             : out   std_logic;
      dirty           : out   std_logic;
      valid           : out   std_logic;
      dout            : out   std_logic_vector(xlen - 1 downto 0);
      wb_tag_addr_out : out   std_logic_vector(xlen - 1 downto 0)
    );
  end component dc;

  signal ac_dout, dc_dout : std_logic_vector(xlen - 1 downto 0);

  signal drp_index      : std_logic_vector(num_vias - 1 downto 0);
  signal ac_tag_address : std_logic_vector(ilog2(num_vias) - 1 downto 0);

begin

  ac_u : component ac
    generic map (
      num_vias     => 4,
      xlen         => 32,
      block_word_n => 4
    )
    port map (
      clk         => clk,
      reset       => reset,
      pc          => pc,
      address     => ac_tag_address,
      din         => din,
      we          => ac_we,
      ac_tag_hits => drp_index,
      dout        => ac_dout
    );

  dc_u : component dc
    generic map (
      num_vias     => 4,
      xlen         => 32,
      block_word_n => 4
    )
    port map (
      clk             => clk,
      reset           => reset,
      addr            => addr,
      din             => din,
      we              => dc_we,
      re              => re,
      wb_read         => wb_read,
      drp_index       => drp_index,
      tags_we         => tags_we,
      set_dirty       => set_dirty,
      access_mode     => access_mode,
      hit             => hit,
      dirty           => dirty,
      valid           => valid,
      dout            => dc_dout,
      wb_tag_addr_out => wb_tag_addr_out
    );

  -- AC is mapped from 0x80000000 to 0x8000000F
  ac_addr        <= '1' when addr(xlen - 1) = '1' and or_reduce(addr(xlen - 2 downto 4)) = '0' else
                    '0';
  ac_tag_address <= addr(ilog2(num_vias) + 2 - 1 downto 2);

  drp  <= or_reduce(drp_index);
  dout <= dc_dout;

end architecture behavioral;
