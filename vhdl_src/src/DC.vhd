library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.std_logic_misc.all;
  use ieee.numeric_std_unsigned.all;

library work;
  use work.acdc_utils.all;

entity dc is
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
    wb_read         : in    std_logic;
    re              : in    std_logic;
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
end entity dc;

architecture behavioral of dc is

  component dc_tagmem is
    generic (
      num_vias     : integer;
      xlen         : integer;
      block_word_n : integer
    );
    port (
      clk         : in    std_logic;
      reset       : in    std_logic;
      address     : in    std_logic_vector(xlen - 1 downto ilog2(block_word_n) + 2);
      address_out : out   std_logic_vector(xlen - 1 downto 0);
      tag_we      : in    std_logic;
      set_dirty   : in    std_logic;
      hit         : out   std_logic;
      dirty       : out   std_logic;
      valid       : out   std_logic
    );
  end component dc_tagmem;

  subtype clines is std_logic_vector(num_vias - 1 downto 0);

  type cache is array(num_vias * block_word_n - 1 downto 0) of std_logic_vector(xlen - 1 downto 0);

  signal line_hits        : clines;
  signal valid_lines      : clines;
  signal dirty_lines      : clines;
  signal num_hit, num_rpl : std_logic_vector(ilog2(num_vias) - 1 downto 0);
  signal word_n           : std_logic_vector(ilog2(block_word_n) - 1 downto 0);
  signal byte_n : std_logic_vector(1 downto 0);
  signal tag_we           : std_logic_vector(num_vias - 1 downto 0);
  signal internal_dout : std_logic_vector(xlen - 1 downto 0);

  signal cache_mem : cache;

  signal internal_hit   : std_logic;
  signal internal_valid : std_logic;
  signal internal_we    : std_logic;
  signal drp            : std_logic;

  signal address : std_logic_vector(xlen - 1 downto ilog2(block_word_n) + 2);

  type tagmem_address_out is array(num_vias - 1 downto 0) of std_logic_vector(xlen - 1 downto 0);

  signal tag_address_out : tagmem_address_out;

begin

  address <= addr(xlen - 1 downto ilog2(block_word_n) + 2);
  word_n  <= addr(ilog2(block_word_n) - 1 + 2 downto 2);
  byte_n <= addr(1 downto 0);

  tag_we      <= drp_index when tags_we = '1' else
                 (others => '0');
  internal_we <= we;

  cache_line_tags : for i in 0 to num_vias - 1 generate

    line : component dc_tagmem
      generic map (
        num_vias     => num_vias,
        xlen         => xlen,
        block_word_n => block_word_n
      )
      port map (
        clk         => clk,
        reset       => reset,
        address     => address,
        address_out => tag_address_out(i),
        tag_we      => tag_we(i),
        set_dirty   => set_dirty,
        hit         => line_hits(i),
        dirty       => dirty_lines(i),
        valid       => valid_lines(i)
      );

  end generate cache_line_tags;

  -- Encoder con prioridad para indexar la memoria cache, convierte de num_vias a log2(num_vias) bits
  hit_encoder : process (line_hits) is
  begin

    num_hit <= (others => '0');

    for i in 0 to num_vias - 1 loop

      if (line_hits(i) = '1') then
        num_hit <= std_logic_vector(to_unsigned(i, num_hit'length));
      end if;

    end loop;

  end process hit_encoder;

  -- Encoder con prioridad para obtener el bloque a reemplazar, convierte de num_vias a log2(num_vias) bits
  rpl_encoder : process (drp_index) is
  begin

    num_rpl <= (others => '0');

    for i in 0 to num_vias - 1 loop

      if (drp_index(i) = '1') then
        num_rpl <= std_logic_vector(to_unsigned(i, num_rpl'length));
      end if;

    end loop;

  end process rpl_encoder;

  -- rst : process (clk, reset) is
  -- begin

  --   if (clk'event and clk = '1') then
  --     if (reset = '1') then
  --       cache_mem <= (others => (others => '0'));
  --     end if;
  --   end if;

  -- end process rst;

  wr_dc_data : process (clk, reset, num_rpl, word_n, we) is
  begin

    if (clk'event and clk = '1') then
      if (reset = '1') then

        for i in 0 to (num_rpl'length * word_n'length * 4) - 1 loop

          cache_mem(i) <= (others => '0');

        end loop;

      elsif (internal_we = '1') then                                -- estamos escribiendo
        if (internal_hit = '1') then                                -- el bloque ya está en cache, no hace falta escribir en la vía que indica la AC
          cache_mem(to_uint(num_hit & word_n)) <= din;
          -- if (access_mode = "10") then   -- word
          --   cache_mem(to_uint(num_hit & word_n)) <= din;
          -- elsif (access_mode = "01") then   -- half word
          --   cache_mem(to_uint(num_hit & word_n))(15 downto 0) <= din(15 downto 0);
          -- elsif (access_mode = "00") then
          --   cache_mem(to_uint(num_hit & word_n))(7 downto 0) <= din(7 downto 0);
          -- end if;
        else                                                        -- el bloque no está en la cache, escribir en la vía que indica la AC
          cache_mem(to_uint(num_rpl & word_n)) <= din;
          -- if (access_mode = "10") then   -- word
          --   cache_mem(to_uint(num_rpl & word_n)) <= din;
          -- elsif (access_mode = "01") then   -- half word
          --   cache_mem(to_uint(num_rpl & word_n))(15 downto 0) <= din(15 downto 0);
          -- elsif (access_mode = "00") then
          --   cache_mem(to_uint(num_rpl & word_n))(7 downto 0) <= din(7 downto 0);
          -- end if;
        end if;
      end if;
    end if;

  end process wr_dc_data;

  drp            <= or_reduce(drp_index);
  internal_hit   <= or_reduce(line_hits);
  internal_valid <= valid_lines(to_uint(num_hit));
  dirty          <= dirty_lines(to_uint(num_hit)) when internal_hit = '1' else
                    dirty_lines(to_uint(num_rpl));
  valid          <= internal_valid;
  hit            <= internal_hit;

  internal_dout <= cache_mem(to_uint(num_hit & word_n)) when wb_read = '0' and internal_hit = '1' else
          cache_mem(to_uint(num_rpl & word_n)) when wb_read = '1' else
          (others => '0');

  dout <= internal_dout;

  -- dout (31 downto 16) <= internal_dout(31 downto 16) when access_mode = "10" else
  --                        (others => '0');
  -- dout (15 downto 8) <= internal_dout(15 downto 8) when (access_mode = "01" and byte_n = "00") or access_mode = "10" else
  --                       internal_dout(31 downto 16) when access_mode = "01" and byte_n = "10" else
  --                       (others => '0') when access_mode = "00";
  -- dout (7 downto 0) <= internal_dout(7 downto 0) when (access_mode = "00" and byte_n = "00") or access_mode = "10" or access_mode = "01"  else
  --                      internal_dout(15 downto 8) when access_mode = "00" and byte_n = "01" else
  --                      internal_dout(23 downto 16) when access_mode = "00" and byte_n = "10" else
  --                      internal_dout(31 downto 24) when access_mode = "00" and byte_n = "11" else
  --                      (others => '0');

  wb_tag_addr_out <= tag_address_out(to_uint(num_rpl)) when wb_read = '1' else
                     (others => '0');

end architecture behavioral;
