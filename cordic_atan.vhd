library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Entity for CORDIC atan2 calculation: atan2(y0, x0)
entity cordic_atan is
    Port (
        clk   : in  STD_LOGIC;                     -- Main clock
        reset : in  STD_LOGIC;                     -- Asynchronous reset
        x0    : in  STD_LOGIC_VECTOR (31 downto 0); -- Input x-coordinate
        y0    : in  STD_LOGIC_VECTOR (31 downto 0); -- Input y-coordinate
        atan2 : out STD_LOGIC_VECTOR (31 downto 0); -- Result atan2 in Q22.10 format
        done  : out STD_LOGIC;                     -- Signal indicating calculation is done
        start : in  STD_LOGIC                       -- Signal to start the calculation
    );
end cordic_atan;

architecture Behavioral of cordic_atan is

    -- CORDIC gain constant (K)
    constant K : std_logic_vector(31 downto 0) := "00000000000000000000001001101101";

    -- Fixed-point Q22.10 constants
    constant unoc    : std_logic_vector(31 downto 0) := "00000000000000000000000000000001"; -- 1
    constant cero    : std_logic_vector(31 downto 0) := "00000000000000000000000000000000"; -- 0
    constant noventa : std_logic_vector(31 downto 0) := "00000000000000010110100000000000"; -- 90 degrees
    constant pi      : std_logic_vector(31 downto 0) := "00000000000000101101000000000000"; -- p
    constant dospi   : std_logic_vector(31 downto 0) := "00000000000001011010000000000000"; -- 2p

    -- Finite State Machine (FSM) states
    type Estados is (RS, Sleep, Pre, Pre1, Pro, Op1, Op2, Op3, Op4, Res, Res1);
    signal edo_actual : Estados := Sleep; -- Initial state is Sleep

    -- Array to store precomputed arctan(2^-i) angles in Q22.10
    type mem is array (0 to 20) of std_logic_vector(31 downto 0);
    signal alfat : mem;

    -- Internal signals for calculation
    signal x, xaux, y, yaux, alfaaux, z, xaux1, yaux1, zaux, xaux2, yaux2, angulo_aux, angulo_aux2, atan2s : std_logic_vector(31 downto 0) := (others => '0');
    signal d, signoc, signos : std_logic := '0';
    signal contador : natural range 0 to 21 := 0;          -- Iteration counter
    signal cuadrante : natural range 1 to 4 := 3;          -- Quadrant indicator
    signal x0_aux, y0_aux, x0_aux1, y0_aux1 : std_logic_vector(31 downto 0);

begin

    -- Initialize the arctangent lookup table for CORDIC iterations
    alfat(0)  <= "00000010110100000000000000000000";
    alfat(1)  <= "00000001101010010000101001110011";
    alfat(2)  <= "00000000111000001001010001110100";
    alfat(3)  <= "00000000011100100000000000010001";
    alfat(4)  <= "00000000001110010011100010101010";
    alfat(5)  <= "00000000000111001010001101111001";
    alfat(6)  <= "00000000000011100101001010100001";
    alfat(7)  <= "00000000000001110010100101101101";
    alfat(8)  <= "00000000000000111001010010111010";
    alfat(9)  <= "00000000000000011100101001011101";
    alfat(10) <= "00000000000000001110010100101110";
    alfat(11) <= "00000000000000000111001010010111";
    alfat(12) <= "00000000000000000011100101001011";
    alfat(13) <= "00000000000000000001110010100101";
    alfat(14) <= "00000000000000000000111001010010";
    alfat(15) <= "00000000000000000000011100101001";
    alfat(16) <= "00000000000000000000001110010100";
    alfat(17) <= "00000000000000000000000111001010";
    alfat(18) <= "00000000000000000000000011100101";
    alfat(19) <= "00000000000000000000000001110010";
    alfat(20) <= "00000000000000000000000000111001";

    -- Main process triggered on clock or reset
    process (clk, reset)
    begin
        if reset = '1' then
            -- Asynchronous reset: reset all internal signals and FSM
            edo_actual <= RS;
            contador <= 0;

        elsif rising_edge(clk) then
            case edo_actual is

                -- Reset state: initialize outputs and internal signals
                when RS =>
                    atan2 <= (others => '0');
                    x <= (others => '0');
                    y <= (others => '0');
                    xaux <= (others => '0');
                    yaux <= (others => '0');
                    d <= '0';
                    alfaaux <= (others => '0');
                    done <= '0';
                    cuadrante <= 3;
                    signoc <= '0';
                    signos <= '0';
                    edo_actual <= Sleep;

                -- Sleep state: wait for start signal
                when Sleep =>
                    if start = '1' then
                        edo_actual <= Pre;
                    end if;

                -- Preprocessing: convert inputs to absolute values if negative
                when Pre =>
                    if y0(31) = '1' then
                        y0_aux <= std_logic_vector(unsigned(NOT(y0)) + unsigned(unoc));
                    else
                        y0_aux <= y0;
                    end if;

                    if x0(31) = '1' then
                        x0_aux <= std_logic_vector(unsigned(NOT(x0)) + unsigned(unoc));
                    else
                        x0_aux <= x0;
                    end if;
                    
                    edo_actual <= Pre1;

                -- Convert to Q22.10 fixed-point format
                when Pre1 =>
                    x0_aux1 <= std_logic_vector(shift_left(signed(x0_aux), 10));
                    y0_aux1 <= std_logic_vector(shift_left(signed(y0_aux), 10));
                    edo_actual <= Pro;

                -- Initialize CORDIC iteration
                when Pro =>
                    x <= x0_aux1;
                    y <= y0_aux1;
                    z <= (others => '0');   -- Accumulated angle
                    d <= '0';               -- Direction flag
                    alfaaux <= alfat(0);    -- First arctangent value
                    edo_actual <= Op1;

                -- Operation 1: apply direction and prepare auxiliary signals
                when Op1 =>
                    if d = '1' then
                        xaux <= std_logic_vector(unsigned(NOT(x)) + unsigned(unoc));
                        yaux <= std_logic_vector(unsigned(NOT(y)) + unsigned(unoc));
                        alfaaux <= std_logic_vector(unsigned(NOT(alfat(contador))) + unsigned(unoc));
                    else
                        xaux <= x;
                        yaux <= y;
                        alfaaux <= alfat(contador);
                    end if;
                    edo_actual <= Op2;

                -- Operation 2: shift by iteration index (2^-i)
                when Op2 =>
                    xaux2 <= std_logic_vector(shift_right(signed(xaux), contador));
                    yaux2 <= std_logic_vector(shift_right(signed(yaux), contador));
                    edo_actual <= Op3;

                -- Operation 3: CORDIC rotation update
                when Op3 =>
                    x <= std_logic_vector(signed(x) + signed(yaux2));
                    y <= std_logic_vector(signed(y) - signed(xaux2));
                    z <= std_logic_vector(signed(z) + signed(alfaaux));
                    edo_actual <= Op4;

                -- Operation 4: determine direction for next iteration
                when Op4 =>
                    if y(31) = '0' then
                        d <= '0';
                    else
                        d <= '1';
                    end if;

                    if contador < 16 then
                        contador <= contador + 1;
                        edo_actual <= Op1;
                    else
                        contador <= 0;
                        edo_actual <= Res;
                    end if;

                -- Result state: shift accumulated angle to Q22.10
                when Res =>
                    atan2s <= std_logic_vector(shift_right(signed(z), 10));
                    edo_actual <= Res1;

                -- Final adjustment based on quadrant and sign of inputs
                when Res1 =>
                    if (((x0(31 downto 4) = "0000000000000000000000000000") OR (x0(31 downto 4) = "1111111111111111111111111111")) 
                        AND ((y0(31 downto 4) = "0000000000000000000000000000") OR (y0(31 downto 4) = "1111111111111111111111111111"))) then
                        atan2 <= (others => '0');
                    else
                        if x0(31) = '1' then
                            if y0(31) = '1' then 
                                atan2 <= std_logic_vector(signed(atan2s) - signed(pi));
                            else
                                atan2 <= std_logic_vector(signed(pi) - signed(atan2s));
                            end if;
                        else
                            if y0(31) = '1' then 
                                atan2 <= std_logic_vector(unsigned(NOT(atan2s)) + unsigned(unoc));
                            else
                                atan2 <= atan2s;
                            end if;
                        end if;
                    end if;
                    done <= '1';
                    edo_actual <= Sleep;

            end case;
        end if;
    end process;

end Behavioral;
