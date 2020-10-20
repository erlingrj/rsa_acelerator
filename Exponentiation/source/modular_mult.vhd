-- Author: Erling Rennemo Jellum
-- Creation: October 20 - 2020
-- This file describes a module that performs a modular multiplication 
-- We take multiplicands A, B ad modulus n


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity modular_mult is
	generic (
		block_size : integer := 256
	);
	port (
		--input control
        valid_in    : in std_logic;
        ready_in	: in STD_LOGIC;

        --input data
        n_in	    : in STD_LOGIC_VECTOR (block_size-1 downto 0); -- n is the mod
        A_in        : in std_logic_vector(block_size-1 downto 0);
        B_in        : in std_logic_vector(block_size-1 downto 0);

		--ouput controll
		ready_out	: out STD_LOGIC;
		valid_out	: out STD_LOGIC;

		--output data
		P_out 		: out STD_LOGIC_VECTOR(block_size-1 downto 0);

		--utility
		clk 		: in STD_LOGIC;
		reset_n 	: in STD_LOGIC
	);
end modular_mult;


architecture rtl of modular_mult is
    TYPE State_type is (S_IDLE, S_PROC, S_DONE);
    signal state: State_type;

    signal cntr : integer range 0 to block_size - 1 := 0;
    -- n,A,B are regs storing the inputs
    signal n	: STD_LOGIC_VECTOR (block_size-1 downto 0); -- n is the mod
    signal  A   : std_logic_vector(block_size-1 downto 0);
    signal  B   : std_logic_vector(block_size-1 downto 0);

    -- P is the reg attached to the output.
    signal P : std_logic_vector(block_size-1 downto 0);

    -- These signals are the the intermediate results in the pipeline
    signal A_or_zero : std_logic_vector(block_size-1 downto 0);
    signal P_or_zero : std_logic_vector(block_size-1 downto 0);
    signal A_plus_P  : std_logic_vector(block_size-1 downto 0);

    signal res : std_logic_vector(block_size-1 downto 0);
    signal res_minus_n : std_logic_vector(block_size-1 downto 0);
    signal res_minus_2n : std_logic_vector(block_size-1 downto 0);

begin

    -- Connect some internal signals to external
    P_out <= P;


    main : process(clk, reset_n) begin
        if (reset_n = '0') then
            state <= S_IDLE;
            n <= (others => '0');
            A <= (others => '0');
            B <= (others => '0');
            P <= (others => '0');
            valid_out <= '0';
        elsif (rising_edge(clk)) then
            case state is
                when S_IDLE =>
                    valid_out <= '0';
                    if (valid_in = '1') then
                        n <= n_in;
                        A <= A_in;                
                        B <= B_in;
                        ready_out <= '1';
                        state <= S_PROC;
                        cntr <= 0;
                    else
                        ready_out <= '0';
                        n <= (others => '0');
                        A <= (others => '0');
                        B <= (others => '0');
                    end if;
                when S_PROC =>
                
                    if (cntr = 0) then
                        P_or_zero <= (others => '0');
                    else
                        P_or_zero <= P;
                    end if;
                    
                    if (B(cntr) = '1') then
                        A_or_zero <= A;
                    else
                        A_or_zero <= (others => '0');
                    end if;
                    
                    A_plus_P <=  (P_or_zero(block_size-2 downto 0) & '0') +  A_or_zero;

                    res <= A_plus_P;
                    res_minus_n <= A_plus_P - n;
                    res_minus_2n <= A_plus_P - (n(block_size-2 downto 0) & '0');
                    
                    -- Update P for the next cc
                    if (res_minus_n(block_size-1) = '1') then
                        P <= res;
                    elsif (res_minus_2n(block_size-1) = '1') then
                        P <= res_minus_n;
                    else
                        P <= res_minus_2n;
                    end if;
                    
                    -- Update cntr and possibly state
                    if (cntr = (block_size - 1)) then
                        state <= S_DONE;
                        cntr <= 0;
                    else
                        cntr <= cntr + 1;
                        state <= S_PROC;    
                    end if;

                when S_DONE =>
                    valid_out <= '1';
                    if (ready_in <= '1') then
                        state <= S_IDLE;
                        cntr <= 0;
                    end if; 
            end case;
        end if;
    end process;


end rtl;
