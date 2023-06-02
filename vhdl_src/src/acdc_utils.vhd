library ieee;
  use ieee.math_real.ceil;
  use ieee.math_real.log2;
  use ieee.numeric_std.all;
  use ieee.std_logic_1164.all;

package acdc_utils is

  function ilog2 (num : in integer) return integer;

  function to_uint (num : in std_logic_vector) return integer;

end package acdc_utils;

package body acdc_utils is

  function ilog2 (num : in integer) return integer is
  begin

    return integer(ceil(log2(real(num))));

  end function;

  function to_uint (num : in std_logic_vector) return integer is
  begin

    return to_integer(unsigned(num));

  end function;

end package body acdc_utils;
