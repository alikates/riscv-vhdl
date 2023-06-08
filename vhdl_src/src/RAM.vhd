-- RISC RAM
-- Little Endian

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;

-- Mode
-- "000" signed byte
-- "100" unsigned byte
-- "001" signed half (16 bits)
-- "101" unsigned half (16 bits)
-- "010" word (32 bits)

entity RAM_RISC is 
	port (
		reset		: in std_logic;
		clk 		: in std_logic;
		we 			: in std_logic;
		re 			: in std_logic;
		fetch		: in std_logic;
		mode		: in std_logic_vector (2 downto 0);
		addr_inst 	: in std_logic_vector (29 downto 0);
		addr_data	: in std_logic_vector (31 downto 0);
		pc	: in std_logic_vector (31 downto 0);

		data_in 	: in std_logic_vector (31 downto 0);

		inst_out 	: out std_logic_vector (31 downto 0);
		data_out 	: out std_logic_vector (31 downto 0);

		ram_busy    : out std_logic
		);
end RAM_RISC;

architecture behavioral of RAM_RISC is

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
		we    : in    std_logic; -- write enable
		re    : in    std_logic; -- read enable
		inv   : in    std_logic; -- invalidate
		access_mode : in    std_logic_vector(1 downto 0); -- "00" word, "01" half-word, "10" byte
		dout  : out   std_logic_vector(xlen - 1 downto 0);
		rdy   : out   std_logic
	);
	end component mem_acdc;

	component imem is
	port (
		addr_inst 	: in std_logic_vector (29 downto 0);
		instr_out 	: out std_logic_vector (31 downto 0)
	);
	end component imem;


	signal saved_byte : std_logic_vector(1 downto 0);
	signal saved_mode : std_logic_vector(2 downto 0);
	signal bg, bg_in : std_logic;
	signal invalidate : std_logic;

	signal dout : std_logic_vector(31 downto 0);
	signal rdy, addr_range : std_logic;
	signal int_we, int_re : std_logic;

	-- signal imem_dout, imem_addr : std_logic_vector(31 downto 0);

	type rom_type is array (0 to 8192) of std_logic_vector(31 downto 0);
	signal rom : rom_type := (
		x"00000097",
		x"01c08093",
		x"30509073",
		x"00001117",
		x"b2410113",
		x"16c000ef",
		x"0000006f",
		x"ffc10113",
		x"00112023",
		x"018000ef",
		x"2b4000ef",
		x"08c000ef",
		x"00012083",
		x"00410113",
		x"30200073",
		x"f8c10113",
		x"00312023",
		x"00412223",
		x"00512423",
		x"00612623",
		x"00712823",
		x"00812a23",
		x"00912c23",
		x"00a12e23",
		x"02b12023",
		x"02c12223",
		x"02d12423",
		x"02e12623",
		x"02f12823",
		x"03012a23",
		x"03112c23",
		x"03212e23",
		x"05312023",
		x"05412223",
		x"05512423",
		x"05612623",
		x"05712823",
		x"05812a23",
		x"05912c23",
		x"05a12e23",
		x"07b12023",
		x"07c12223",
		x"07d12423",
		x"07e12623",
		x"07f12823",
		x"00008067",
		x"00012183",
		x"00412203",
		x"00812283",
		x"00c12303",
		x"01012383",
		x"01412403",
		x"01812483",
		x"01c12503",
		x"02012583",
		x"02412603",
		x"02812683",
		x"02c12703",
		x"03012783",
		x"03412803",
		x"03812883",
		x"03c12903",
		x"04012983",
		x"04412a03",
		x"04812a83",
		x"04c12b03",
		x"05012b83",
		x"05412c03",
		x"05812c83",
		x"05c12d03",
		x"06012d83",
		x"06412e03",
		x"06812e83",
		x"06c12f03",
		x"07012f83",
		x"07410113",
		x"00008067",
		x"00300793",
		x"00a7ea63",
		x"00251513",
		x"36402783",
		x"00a787b3",
		x"00b7a023",
		x"00008067",
		x"34202573",
		x"00008067",
		x"30452073",
		x"00008067",
		x"30453073",
		x"00008067",
		x"30052073",
		x"00008067",
		x"30053073",
		x"00008067",
		x"30002573",
		x"00008067",
		x"ff010113",
		x"00112623",
		x"25800593",
		x"00100513",
		x"fa5ff0ef",
		x"33000513",
		x"0bc000ef",
		x"7d000513",
		x"00000593",
		x"058000ef",
		x"088000ef",
		x"0000006f",
		x"ff010113",
		x"00112623",
		x"00050737",
		x"000015b7",
		x"00072783",
		x"00472603",
		x"8005a683",
		x"8045a583",
		x"00d786b3",
		x"00f6b7b3",
		x"00b60633",
		x"00c787b3",
		x"00d72423",
		x"00f72623",
		x"34000513",
		x"068000ef",
		x"00c12083",
		x"01010113",
		x"00008067",
		x"000017b7",
		x"80a7a023",
		x"80b7a223",
		x"00050737",
		x"00072783",
		x"00472683",
		x"00a78533",
		x"00f537b3",
		x"00b686b3",
		x"00d787b3",
		x"00a72423",
		x"00f72623",
		x"00008067",
		x"ff010113",
		x"00112623",
		x"08000513",
		x"f1dff0ef",
		x"00800513",
		x"f25ff0ef",
		x"00c12083",
		x"01010113",
		x"00008067",
		x"00054783",
		x"00078e63",
		x"00150513",
		x"00090737",
		x"00f72023",
		x"00150513",
		x"fff54783",
		x"fe079ae3",
		x"00008067",
		x"06050063",
		x"fe010113",
		x"00010813",
		x"00080693",
		x"00000713",
		x"02b577b3",
		x"00050613",
		x"02b55533",
		x"03078793",
		x"00f68023",
		x"00070793",
		x"00170713",
		x"00168693",
		x"feb670e3",
		x"0207c063",
		x"00f107b3",
		x"000906b7",
		x"0007c703",
		x"00e6a023",
		x"00078713",
		x"fff78793",
		x"ff0718e3",
		x"02010113",
		x"00008067",
		x"00008067",
		x"ff010113",
		x"00112623",
		x"00812423",
		x"e69ff0ef",
		x"800007b7",
		x"00778793",
		x"02f50463",
		x"00050413",
		x"34800513",
		x"f55ff0ef",
		x"01000593",
		x"00040513",
		x"f6dff0ef",
		x"33c00513",
		x"f41ff0ef",
		x"0000006f",
		x"e95ff0ef",
		x"00c12083",
		x"00812403",
		x"01010113",
		x"00008067",
		others => (others => '0')
	);

begin
	invalidate <= '0';

	addr_range <= '1' when (addr_data(31 downto 14) = "000000000000000000") or (addr_data(31 downto 4) = "1000000000000000000000000000") else '0';

	process(clk)
	begin
		if (rising_edge(clk)) then
			if (reset = '1') then
				saved_byte <= "00";
				saved_mode <= "000";
				bg <= '0';
			else
				saved_byte <= addr_data(1 downto 0);
				-- assert mode = "100" report "unimplemented memory access mode";
				saved_mode <= mode;
				bg <= bg_in;
			end if;
		end if;
	end process;

	bg_in <= '1' when unsigned(addr_data) < x"00002000" else '0';

	inst_out <= rom(to_integer(unsigned(addr_inst(12 downto 0))));

	int_we <= we when addr_range = '1' else '0';
	int_re <= re when addr_range = '1' else '0';

	D_MEM : mem_acdc
	GENERIC MAP (
	    num_vias => 4,
		xlen => 32,
		block_word_n => 4
	)
	PORT MAP (
		clk   => clk,
		reset => reset,
		addr  => addr_data,
		pc    => pc,
		we    => int_we,
		re    => int_re,
		din   => data_in,
		access_mode => mode(1 downto 0),
		dout  => dout,
		inv   => invalidate,
		rdy   => rdy
	);

	ram_busy <= not rdy when addr_range = '1' else '0';
	data_out <= (others => 'Z') when bg = '0'
				else dout;

end behavioral ; -- arch

