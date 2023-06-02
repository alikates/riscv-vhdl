library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity mem_tb is
  generic (
    num_vias     : integer := 4;
    xlen         : integer := 32;
    block_word_n : integer := 4
  );
end entity mem_tb;

architecture behavioral of mem_tb is

  component mem_acdc is
    generic (
      num_vias     : integer := 4;
      xlen         : integer := 32;
      block_word_n : integer := 4
    );
    port (
      clk   : in    std_logic;
      reset : in    std_logic;
      addr  : in    std_logic_vector(xlen - 1 downto 0);
      pc    : in    std_logic_vector(xlen - 1 downto 0);
      din   : in    std_logic_vector(xlen - 1 downto 0);
      we    : in    std_logic;
      re    : in    std_logic;
      inv   : in    std_logic;
      dout  : out   std_logic_vector(xlen - 1 downto 0);
      rdy   : out   std_logic
    );
  end component mem_acdc;

  signal clk : std_logic;

  signal reset     : std_logic;
  signal acdc_we   : std_logic;
  signal acdc_re   : std_logic;
  signal acdc_inv  : std_logic;
  signal rdy       : std_logic;
  signal addr      : std_logic_vector(xlen - 1 downto 0);
  signal pc        : std_logic_vector(xlen - 1 downto 0);
  signal acdc_dout : std_logic_vector(xlen - 1 downto 0);
  signal acdc_din  : std_logic_vector(xlen - 1 downto 0);

  signal i : std_logic_vector(3 downto 0) := "0000";

begin

  mem_acdc_u : component mem_acdc
    port map (
      clk   => clk,
      reset => reset,
      addr  => addr,
      pc    => pc,
      we    => acdc_we,
      re    => acdc_re,
      din   => acdc_din,
      dout  => acdc_dout,
      inv   => acdc_inv,
      rdy   => rdy
    );

  -- continuous clock
  clock : process is
  begin

    clk <= '0';
    wait for 1 ns / 2;
    clk <= '1';
    wait for 1 ns / 2;

  end process clock;

  stim_proc : process is
  begin

    addr     <= x"00000000";
    pc       <= x"00000000";
    acdc_we  <= '0';
    acdc_din <= x"00000000";
    reset    <= '1';

    i <= "0000";

    wait until clk = '1' and clk'event;

    reset <= '0';

    i <= "0001";

    wait until rdy = '1' and clk = '1' and clk'event;
    i        <= "0010";
    addr     <= x"80000000";
    acdc_we  <= '1';
    acdc_din <= x"00000000";

    wait until rdy = '1' and clk = '1' and clk'event;
    i        <= "0011";
    addr     <= x"00000024";
    acdc_we  <= '0';
    acdc_re  <= '1';
    acdc_din <= x"00001100";

    wait until rdy = '1' and clk = '1' and clk'event;
    i        <= "0100";
    addr     <= x"00000000";
    acdc_we  <= '0';
    acdc_re  <= '0';
    acdc_din <= x"00000000";

    wait until clk = '1' and clk'event;
    i <= "0101";
    -- siguiente bloque

    addr     <= x"80000004";
    acdc_we  <= '1';
    acdc_din <= x"00001000";

    wait until rdy = '1' and clk = '1' and clk'event;
    i        <= "0110";
    acdc_we  <= '0';
    acdc_re  <= '1';
    pc       <= x"00000000";
    addr     <= x"00000030";
    acdc_din <= x"00001000";

    wait until rdy = '1' and clk = '1' and clk'event;
    i        <= "0111";
    addr     <= x"00000000";
    acdc_we  <= '0';
    acdc_re  <= '0';
    acdc_din <= x"00000000";

    wait;

  end process stim_proc;

end architecture behavioral;
