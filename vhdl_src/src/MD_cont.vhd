----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:    14:12:11 04/04/2014
-- Design Name:
-- Module Name:    DMA - Behavioral
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

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

entity md_cont is
  port (
    clk           : in    std_logic;
    reset         : in    std_logic;
    bus_frame     : in    std_logic;                     -- indica que el master quiere más datos
    bus_rd_wr     : in    std_logic;
    bus_addr      : in    std_logic_vector(31 downto 0); -- Direcciones
    bus_data      : in    std_logic_vector(31 downto 0); -- Datos
    md_bus_devsel : out   std_logic;                     -- para avisar de que se ha reconocido que la dirección pertenece a este módulo
    md_bus_trdy   : out   std_logic;                     -- para avisar de que se va a realizar la operación solicitada en el ciclo actual
    md_send_data  : out   std_logic;                     -- para enviar los datos al bus
    md_dout       : out   std_logic_vector(31 downto 0)  -- salida de datos
  );
end entity md_cont;

architecture behavioral of md_cont is

  component counter is
    port (
      clk          : in    std_logic;
      reset        : in    std_logic;
      count_enable : in    std_logic;
      load         : in    std_logic;
      d_in         : in    std_logic_vector(7 downto 0);
      count        : out   std_logic_vector(7 downto 0)
    );
  end component;

  -- misma memoria que en el proyecto anterior
  component ram_128_32 is port (
      clk    : in    std_logic;
      enable : in    std_logic;
      addr   : in    std_logic_vector(31 downto 0);
      din    : in    std_logic_vector(31 downto 0);
      we     : in    std_logic;
      re     : in    std_logic;
      dout   : out   std_logic_vector(31 downto 0)
    );
  end component;

  component reg7 is
    port (
      din   : in    std_logic_vector(10 downto 0);
      clk   : in    std_logic;
      reset : in    std_logic;
      load  : in    std_logic;
      dout  : out   std_logic_vector(10 downto 0)
    );
  end component;

  signal bus_re                           : std_logic;
  signal bus_we                           : std_logic;
  signal mem_we                           : std_logic;
  signal contar_palabras                  : std_logic;
  signal resetear_cuenta                  : std_logic;
  signal md_enable                        : std_logic;
  signal memoria_preparada                : std_logic;
  signal contar_retardos                  : std_logic;
  signal direccion_distinta               : std_logic;
  signal reset_retardo                    : std_logic;
  signal load_addr                        : std_logic;
  signal addr_in_range                    : std_logic;
  signal addr_frame,      last_addr       : std_logic_vector(10 downto 0);
  signal cuenta_palabras, cuenta_retardos : std_logic_vector(7 downto 0);
  signal md_addr                          : std_logic_vector(31 downto 0);

  type state_type is (inicio, espera, transferencia, detectado);

  signal state,           next_state : state_type;

begin

  ---------------------------------------------------------------------------
  -- Decodificador: identifica cuando la dirección pertenece a la MD: (X"00000000"-X"00002000")
  ---------------------------------------------------------------------------

  addr_in_range <= '1' when (bus_addr(31 downto 14) = "000000000000000000") and (bus_frame='1') else
                   '0';

  ---------------------------------------------------------------------------
  -- Convertimos señal bus_Rd_Wr en señales de lectura y escritura
  ---------------------------------------------------------------------------

  bus_re <= not(bus_rd_wr);

  bus_we <= bus_rd_wr;

  ---------------------------------------------------------------------------
  -- HW para introducir retardos:
  -- Con un contador y una sencilla máquina de estados introducimos un retardo en la memoria de forma articial.
  -- Cuando se pide una dirección nueva manda la primera palabra en 4 ciclos y el resto cada dos
  -- Si se accede dos veces a la misma dirección la segunda vez no hay retardo inicial
  ---------------------------------------------------------------------------

  cont_retardos : component counter
    port map (
      clk          => clk,
      reset        => reset,
      count_enable => contar_retardos,
      load         => reset_retardo,
      d_in         => "00000000",
      count        => cuenta_retardos
    );

  -- este registro almacena la ultima dirección accedida. Cada vez que cambia la dirección se resetea el contador de retaros
  -- La idea es simular que cuando accedes a una dirección nueva tarda más. Si siempre accedes a la misma no introducirá retardos adicionales
  reg_last_addr : component reg7
    port map (
      din   => bus_addr(12 downto 2),
      clk   => clk,
      reset => reset,
      load  => load_addr,
      dout  => last_addr
    );

  direccion_distinta <= '0' when (last_addr = bus_addr(12 downto 2)) else
                        '1';
  -- introducimos un retardo en la memoria de forma articial. Manda la primera palabra en el cuarto ciclo y el resto cada dos ciclos
  -- Pero si los accesos son a direcciones repetidas el retardo inicial desaparece

  memoria_preparada <= '0' when (cuenta_retardos < "00000011" or cuenta_retardos(0) = '1') else
                       '1';
  ---------------------------------------------------------------------------
  -- Máquina de estados para introducir retardos
  ---------------------------------------------------------------------------

  sync_proc : process (clk) is
  begin

    if (clk'event and clk = '1') then
      if (reset = '1') then
        state <= Inicio;
      else
        state <= next_state;
      end if;
    end if;

  end process sync_proc;

  -- MEALY State-Machine - Outputs based on state and inputs
  output_decode : process (state, direccion_distinta, addr_in_range, memoria_preparada, bus_frame) is
  begin

    -- valores por defecto, si no se asigna otro valor en un estado valdrán lo que se asigna aquí
    contar_retardos <= '0';
    reset_retardo   <= '0';
    load_addr       <= '0';
    next_state      <= Inicio;
    md_bus_devsel   <= '0';
    md_bus_trdy     <= '0';
    md_send_data    <= '0';
    mem_we          <= '0';
    md_enable       <= '0';
    contar_palabras <= '0';
    -- Estado Inicio: se llega sólo con el reset. Sirve para que al acceder a la dirección 0 tras un reset introduzca los retardos
    if (state = Inicio and addr_in_range= '0') then          -- si no piden nada no hacemos nada
      next_state <= Inicio;
    elsif (state = Inicio and addr_in_range= '1') then       -- Si piden algo tras un reset reseteamos el contador de retardos y vamos a Evianado
      next_state    <= Detectado;
      reset_retardo <= '1';
      load_addr     <= '1';                                  -- cargamos  la dirección
    -- Estado Espera
    elsif (state = Espera and addr_in_range= '0') then       -- si no piden nada no hacemos nada
      next_state <= Espera;
    elsif (state = Espera and addr_in_range= '1') then       -- si detectamos que la dirección nos pertenece vamos al estado de transferencia
      next_state <= Detectado;
      if (direccion_distinta ='1') then
        reset_retardo <= '1';                                -- si se repite la dirección no metemos los retardos iniciales
        load_addr     <= '1';                                -- cargamos  la dirección
      end if;
    -- Estado Detectado: sirve para informar de que hemos visto que la dirección es nuestra y de que vamos a empezar a leer/escribir datos
    elsif (state = Detectado and bus_frame = '1') then
      next_state    <= Transferencia;
      md_bus_devsel <= '1';                                  -- avisamos de que hemos visto que la dirección es nuestra
    -- No empezamos a leer/escribir por si acaso no mandan los datos hasta el ciclo siguiente
    elsif (state = Detectado and bus_frame = '0') then       -- Cuando Bus_Frame es 0 es que hemos terminado. No debería pasar porque todavía no hemos hecho nada
      next_state <= Espera;
    -- Estado Transferencia
    elsif (state = Transferencia and bus_frame = '1') then   -- si estamos en una transferencia seguimos enviando/recibiendo datos hasta que el master diga que no quiere más
      next_state      <= Transferencia;
      md_bus_devsel   <= '1';                                -- avisamos de que hemos visto que la dirección es nuestra
      md_enable       <= '1';                                -- habilitamos la MD para leer o escribir
      contar_retardos <= '1';
      md_bus_trdy     <= memoria_preparada;
      contar_palabras <= memoria_preparada;                  -- cada vez que mandamos una palabra se incrementa el contador
      mem_we          <= bus_we and memoria_preparada;       -- evitamos escribir varias veces
      md_send_data    <= bus_re and memoria_preparada;       -- si la dirección está en rango y es una lectura se carga el dato de MD en el bus
    elsif (state = Transferencia and bus_frame = '0') then   -- Cuando Bus_Frame es 0 es que hemos terminado
      next_state <= Espera;
    end if;

  end process output_decode;

  ---------------------------------------------------------------------------
  -- calculo direcciones
  -- el contador cuenta mientras frame esté activo, la dirección pertenezca a la memoria y la memoria esté preparada para realizar la operación actual.
  ---------------------------------------------------------------------------

  -- Si se desactiva la señal de Frame la cuenta vuelve a 0 al ciclo siguiente. Para que este esquema funcione Frame debe estar un ciclo a 0 entre dos ráfagas. En este sistema esto siempre se cumple.
  resetear_cuenta <= '1' when (bus_frame='0') else
                     '0';

  cont_palabras : component counter
    port map (
      clk          => clk,
      reset        => reset,
      count_enable => contar_palabras,
      load         => resetear_cuenta,
      d_in         => "00000000",
      count        => cuenta_palabras
    );

  -- La dirección se calcula sumando la cuenta de palabras a la dirección inicial almacenada en el registro last_addr
  addr_frame <= last_addr + cuenta_palabras(6 downto 0);
  -- sólo asignamos los bits que se usan. El resto se quedan a 0.
  md_addr(1 downto 0)  <= "00";
  md_addr(12 downto 2)  <= addr_frame;
  md_addr(31 downto 13) <= "0000000000000000000";

  ---------------------------------------------------------------------------
  -- Memoria de datos original
  ---------------------------------------------------------------------------

  md : component ram_128_32
    port map (
      clk    => clk,
      enable => md_enable,
      addr   => md_addr,
      din    => bus_data,
      we     => mem_we,
      re     => bus_re,
      dout   => md_dout
    );

end architecture behavioral;
