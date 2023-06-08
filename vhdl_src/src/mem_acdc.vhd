library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.std_logic_misc.all;
  use ieee.numeric_std_unsigned.all;

entity mem_acdc is
  generic (
    num_vias     : integer := 4;
    xlen         : integer := 32;
    block_word_n : integer := 4
  );
  port (
    clk         : in    std_logic;
    reset       : in    std_logic;
    addr        : in    std_logic_vector(xlen - 1 downto 0);
    pc          : in    std_logic_vector(xlen - 1 downto 0);
    din         : in    std_logic_vector(xlen - 1 downto 0);
    we          : in    std_logic; -- write enable
    re          : in    std_logic; -- read enable
    inv         : in    std_logic; -- invalidate
    access_mode : in    std_logic_vector(1 downto 0); -- "00" word, "01" half-word, "10" byte
    dout        : out   std_logic_vector(xlen - 1 downto 0);
    rdy         : out   std_logic
  );
end entity mem_acdc;

architecture behavioral of mem_acdc is

  component acdc is
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
  end component acdc;

  component md_cont is
    port (
      clk           : in    std_logic;
      reset         : in    std_logic;
      bus_frame     : in    std_logic;
      bus_rd_wr     : in    std_logic;
      bus_addr      : in    std_logic_vector(31 downto 0);
      bus_data      : in    std_logic_vector(31 downto 0);
      md_bus_devsel : out   std_logic;
      md_bus_trdy   : out   std_logic;
      md_send_data  : out   std_logic;
      md_dout       : out   std_logic_vector(31 downto 0)
    );
  end component md_cont;

  -- ACDC signals
  signal acdc_addr            : std_logic_vector(xlen - 1 downto 0);
  signal acdc_din             : std_logic_vector(xlen - 1 downto 0);
  signal acdc_dout            : std_logic_vector(xlen - 1 downto 0);
  signal acdc_wb_tag_addr_out : std_logic_vector(xlen - 1 downto 0);

  signal internal_dout : std_logic_vector(xlen - 1 downto 0);

  signal acdc_tags_we, ac_addr : std_logic;

  signal acdc_ac_we : std_logic;
  signal acdc_dc_we : std_logic;
  signal acdc_re    : std_logic;

  signal acdc_hit       : std_logic;
  signal acdc_dirty     : std_logic;
  signal acdc_valid     : std_logic;
  signal acdc_drp       : std_logic;
  signal acdc_set_dirty : std_logic;
  signal acdc_wb_read   : std_logic;

  -- Memory signals

  signal mem_bus_addr   : std_logic_vector(xlen - 1 downto 0);
  signal mem_din        : std_logic_vector(xlen - 1 downto 0);
  signal mem_dout       : std_logic_vector(xlen - 1 downto 0);
  signal mem_bus_rd_wr  : std_logic;
  signal mem_bus_frame  : std_logic;
  signal mem_bus_trdy   : std_logic;
  signal mem_bus_devsel : std_logic;
  signal mem_send_data  : std_logic;

  -- State machine and misc
  -- type state_type is (inicio, waitramword, writedcword, memread, memwrite, endwriteram, endreadram, writeback, rplwritedc, rplwaitram, rplendwritedc);

  type state_type is (inicio, espera, ramwritearound, ramwritearoundwait, ramreadaround, ramreadaroundwait, writeback, writebackwaitramok, replace, replacewaitramok);

  signal state,        next_state : state_type;

  signal word_cnt : std_logic_vector(2 downto 0);

  signal byte_n : std_logic_vector(1 downto 0);

begin

  byte_n <= addr(1 downto 0);

  cache : component acdc
    generic map (
      num_vias     => 4,
      xlen         => 32,
      block_word_n => 4
    )
    port map (
      clk             => clk,
      reset           => reset,
      addr            => acdc_addr,
      pc              => pc,
      din             => acdc_din,
      dout            => acdc_dout,
      tags_we         => acdc_tags_we,
      hit             => acdc_hit,
      ac_we           => acdc_ac_we,
      dc_we           => acdc_dc_we,
      re              => acdc_re,
      wb_read         => acdc_wb_read,
      set_dirty       => acdc_set_dirty,
      access_mode     => access_mode,
      valid           => acdc_valid,
      dirty           => acdc_dirty,
      ac_addr         => ac_addr,
      drp             => acdc_drp,
      wb_tag_addr_out => acdc_wb_tag_addr_out
    );

  mem : component md_cont
    port map (
      clk           => clk,
      reset         => reset,
      bus_addr      => mem_bus_addr,
      bus_data      => mem_din,
      md_dout       => mem_dout,
      bus_rd_wr     => mem_bus_rd_wr,
      bus_frame     => mem_bus_frame,
      md_bus_devsel => mem_bus_devsel,
      md_bus_trdy   => mem_bus_trdy,
      md_send_data  => mem_send_data
    );

  sync_proc : process (clk, reset) is
  begin

    if (clk'event and clk = '1') then
      if (reset = '1') then
        state <= Inicio;
      else
        state <= next_state;
      end if;
    end if;

  end process sync_proc;

  counter : process (clk, reset, mem_bus_trdy) is
  begin

    if (clk'event and clk = '1') then
      if (reset = '1') then
        word_cnt <= (others => '0');
        -- dout <= (others => '0');
      else
        if (state /= Replace and state /= WriteBack) then
          word_cnt <= (others => '0');
        else
          if (mem_bus_trdy = '1') then
            word_cnt <= word_cnt + "001";
          end if;
        end if;
      end if;
    end if;

  end process counter;

  -- Mealy State Machine
  state_transition : process (state, clk, ac_addr, acdc_hit, re, we, acdc_drp, acdc_dirty, word_cnt, mem_bus_trdy, din, addr, mem_dout, mem_bus_devsel) is
  begin

    rdy            <= '0';
    mem_bus_rd_wr  <= '0';
    mem_bus_frame  <= '0';
    mem_bus_addr   <= (others => '0');
    mem_din        <= (others => '0');
    acdc_ac_we     <= '0';
    acdc_dc_we     <= '0';
    acdc_re        <= '0';
    acdc_din       <= din;
    acdc_addr      <= addr;
    acdc_tags_we   <= '0';
    acdc_set_dirty <= '0';
    acdc_wb_read   <= '0';
    internal_dout <= (others => '0');

    case state is

      when Inicio =>
        rdy <= '1';
        next_state <= Espera;

      when Espera =>

        rdy <= '1';

        if (ac_addr = '1'  and we = '1') then
          acdc_ac_we <= '1';
          next_state <= Espera;
        elsif (acdc_hit = '1' and we = '1') then
          acdc_dc_we <= '1';
          next_state <= Espera;
        elsif (acdc_hit = '1' and re = '1') then
          acdc_re    <= '1';
          internal_dout <= acdc_dout;
          next_state <= Espera;
        elsif (acdc_drp = '0' and we = '1') then                                                -- write bypass
          rdy <= '0';
          mem_bus_frame <= '1';
          mem_bus_addr  <= addr;
          next_state <= RamWriteAround;
        elsif (acdc_drp = '0' and re = '1') then                                                -- read bypass
          rdy <= '0';
          mem_bus_frame <= '1';
          mem_bus_addr  <= addr;
          next_state <= RamReadAround;
        elsif (acdc_drp = '1' and acdc_dirty = '1'  and (we = '1' or re = '1')) then            -- write back and replace
          rdy           <= '0';
          acdc_re       <= '1';
          acdc_wb_read  <= '1';
          mem_bus_addr  <= acdc_wb_tag_addr_out(xlen - 1 downto 4) & "0000";                    -- direccion de bloque
          mem_bus_frame <= '1';                                                                 -- iniciamos transferencia de bloque a memoria
          next_state    <= WriteBackWaitRamOk;
        elsif (acdc_drp = '1' and acdc_dirty = '0' and (we = '1' or re = '1')) then             -- replace only
          rdy           <= '0';
          mem_bus_frame <= '1';                                                                 -- iniciamos transferencia de bloque a memoria
          mem_bus_addr  <= addr(xlen - 1 downto 4) & "0000";                                    -- direccion de bloque

          next_state <= ReplaceWaitRamOk;
        else
          next_state <= Espera;
        end if;
      when RamWriteAround =>
        mem_bus_frame <= '1';
        mem_bus_addr  <= addr;
        mem_din       <= din;
        mem_bus_rd_wr <= '1';
        if (mem_bus_trdy = '1') then
          rdy <= '1';
          internal_dout <= mem_dout;
          next_state <= Espera;
        end if;
      when RamWriteAroundWait =>
        -- rdy <= '1';
        internal_dout <= mem_dout;
        next_state <= Espera;

      when RamReadAround =>
        mem_bus_frame <= '1';
        mem_bus_addr  <= addr;
        mem_din       <= din;
        mem_bus_rd_wr <= '0';
        if (mem_bus_trdy = '1') then
          -- rdy <= '1';
          internal_dout <= mem_dout;
          next_state <= Espera;
        end if;
      when RamReadAroundWait =>
        rdy <= '1';
        internal_dout <= mem_dout;
        next_state <= Espera;

      when WriteBackWaitRamOk =>

        acdc_re       <= '1';
        acdc_wb_read  <= '1';
        acdc_addr     <= acdc_wb_tag_addr_out(xlen - 1 downto 4) & word_cnt(1 downto 0) & "00";
        mem_bus_rd_wr <= '1';
        mem_bus_frame <= '1';                                                                   -- iniciamos transferencia de bloque a memoria
        mem_bus_addr  <= acdc_wb_tag_addr_out(xlen - 1 downto 4) & word_cnt(1 downto 0) & "00"; -- direccion de bloque
        mem_din       <= acdc_dout;

        if (mem_bus_devsel = '1') then
          next_state <= WriteBack;
        end if;

      when WriteBack =>

        acdc_re       <= '1';
        acdc_wb_read  <= '1';
        acdc_addr     <= acdc_wb_tag_addr_out(xlen - 1 downto 4) & word_cnt(1 downto 0) & "00";
        mem_bus_rd_wr <= '1';
        mem_bus_frame <= '1';
        mem_bus_addr  <= acdc_wb_tag_addr_out(xlen - 1 downto 4) & word_cnt(1 downto 0) & "00"; -- direccion de bloque
        mem_din       <= acdc_dout;

        if (word_cnt(2) = '1') then
          mem_bus_frame <= '0';
          next_state    <= ReplaceWaitRamOk;
        else
          next_state <= WriteBack;                                                              -- no hemos acabado de transferir bloques
        end if;

      when ReplaceWaitRamOk =>

        mem_bus_frame <= '1';                                                                   -- iniciamos transferencia de bloque a memoria
        mem_bus_addr  <= addr(xlen - 1 downto 4) & "0000";                                      -- direccion de bloque

        if (mem_bus_devsel = '1') then
          next_state <= Replace;
        end if;

      when Replace =>

        acdc_dc_we    <= mem_bus_trdy;
        acdc_din      <= mem_dout;
        acdc_addr     <= addr(xlen - 1 downto 4) & word_cnt(1 downto 0) & "00";
        mem_bus_frame <= '1';                                                                   -- iniciamos transferencia de bloque a memoria
        mem_bus_addr <= addr(xlen - 1 downto 4) & "0000";                                       -- direccion de bloque

        if (we = '1' and word_cnt(1 downto 0) = addr(3 downto 2)) then
          acdc_din <= din;
        end if;

        if (word_cnt(2) = '1') then
          acdc_tags_we   <= '1';
          acdc_set_dirty <= we;
          mem_bus_frame  <= '0';
          next_state     <= Espera;
        else
          next_state <= Replace;                                                                -- no hemos acabado de transferir bloques
        end if;

    end case;

  end process state_transition;

  dout (31 downto 16) <= internal_dout(31 downto 16) when access_mode(1 downto 0) = "10" else
                         (others => '0');
  dout (15 downto 8) <= internal_dout(15 downto 8) when (access_mode(1 downto 0) = "01" and byte_n = "00") or access_mode(1 downto 0) = "10" else
                        internal_dout(23 downto 16) when access_mode(1 downto 0) = "01" and byte_n = "10" else
                        (others => '0') when access_mode = "00";
  dout (7 downto 0) <= internal_dout(7 downto 0) when (access_mode(1 downto 0) = "00" and byte_n = "00") or access_mode(1 downto 0) = "10" or access_mode(1 downto 0) = "01"  else
                       internal_dout(15 downto 8) when access_mode(1 downto 0) = "00" and byte_n = "01" else
                       internal_dout(23 downto 16) when access_mode(1 downto 0) = "00" and byte_n = "10" else
                       internal_dout(31 downto 24) when access_mode(1 downto 0) = "00" and byte_n = "11" else
                       (others => '0');

end architecture behavioral;
