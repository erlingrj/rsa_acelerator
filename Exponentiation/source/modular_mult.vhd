-- Author: Erling Rennemo Jellum
-- Creation: October 20 - 2020
-- This file describes a module that performs a modular multiplication 
-- We take multiplicands A, B ad modulus n


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use IEEE.math_real.all;


entity modular_mult is
	generic (
        c_block_size : integer := 256;
        c_radix : integer := 16;
        c_radix_bits : integer := 4
        );
	port (
		--input control
        valid_in    : in std_logic;
        ready_in	: in STD_LOGIC;

        --input data
        n_in	    : in STD_LOGIC_VECTOR (c_block_size-1 downto 0); -- n is the mod
        A_in        : in std_logic_vector(c_block_size-1 downto 0);
        B_in        : in std_logic_vector(c_block_size-1 downto 0);

		--ouput controll
		ready_out	: out STD_LOGIC;
		valid_out	: out STD_LOGIC;

		--output data
		P_out 		: out STD_LOGIC_VECTOR(c_block_size-1 downto 0);

		--utility
		clk 		: in STD_LOGIC;
		reset_n 	: in STD_LOGIC
	);
end modular_mult;


architecture rtl_radix4 of modular_mult is
    TYPE State_type is (S_IDLE, S_PROC, S_DONE);
    constant radix_half : integer := 2;
    constant radix : integer := 4;
    constant overflow_size : integer := c_block_size+3;
    signal state: State_type;

    signal cntr : integer range 0 to  ( c_block_size - 1 )  := c_block_size - 1;
    -- n,A,B are regs storing the inputs
    signal n	: STD_LOGIC_VECTOR (c_block_size-1 downto 0); -- n is the mod
    signal  A   : std_logic_vector(c_block_size downto 0);
    signal  B   : std_logic_vector(c_block_size-1 downto 0);

    -- P is the reg attached to the output.
    signal P : std_logic_vector(c_block_size-1 downto 0);

    -- Select signal is based on 2 bits from B and decides which additions and so on to use
    signal sel : std_logic_vector(1 downto 0);

    -- P or zero is selecetd based on the loop counter. its 0 the first iteration
    signal P_or_zero : std_logic_vector(overflow_size downto 0);

    -- sel00 => P = P << 2
    signal sel00 : std_logic_vector(overflow_size downto 0);
    
    -- sel10 => P = (P << 2) + (A << 2)
    signal sel10 : std_logic_vector(overflow_size downto 0);
    
    -- sel01 => P = (P << 2) + (A << 2)
    signal sel01 : std_logic_vector(overflow_size  downto 0);
    
    -- sel11 => P = (P << 4) + (A << 2)
    signal sel11 : std_logic_vector(overflow_size downto 0);

    signal addition_output : std_logic_vector(overflow_size downto 0);

    -- res is an array of std_logic_Vectors. It has the subtractors that calculate the 
    -- mod operation (by subtracting)
    signal res : std_logic_vector(overflow_size downto 0);
    signal res_n : std_logic_vector(overflow_size downto 0);
    signal res_2n : std_logic_vector(overflow_size downto 0);
    signal res_3n : std_logic_vector(overflow_size downto 0);
    signal res_4n : std_logic_vector(overflow_size downto 0);
    signal res_5n : std_logic_vector(overflow_size downto 0);
    signal res_6n : std_logic_vector(overflow_size downto 0);
    
begin

    -- Connect some internal signals to external
    P_out <= P;
    ready_out <= '1' when (state = S_IDLE and reset_n = '1') else '0';
    valid_out <= '1' when (state = S_DONE and reset_n = '1') else '0';

    -- Specify the combinatorial stuff
    P_or_zero <= (others => '0') when cntr = (c_block_size - 1) else  "0000" & P;

    -- The select signal
    sel <= B(cntr downto cntr-1);

    -- The additions
    sel00 <= P_or_zero(overflow_size-2 downto 0) & "00";
    sel10 <= P_or_zero(overflow_size-2 downto 0) & "00" + (A(c_block_size-1 downto 0) & '0');
    sel01 <= P_or_zero(overflow_size-2 downto 0) & "00" + A;
    sel11 <= P_or_zero(overflow_size-2 downto 0) & "00" + ( A(c_block_size-1 downto 0) & '0') + A;

    -- The muxing
    addition_output <= sel00 when (sel = "00") else
                      sel01 when (sel = "01") else
                      sel10 when (sel = "10") else
                      sel11;
    
    -- The subtraction / modulus
    res <= addition_output;
    res_n <= addition_output - n;
    res_2n <= addition_output - ('0' & n & '0');
    res_3n <= addition_output - ('0' & n & '0') - n;
    res_4n <= addition_output - ('0' & n & "00");
    res_5n <= addition_output - ('0' & n & "00") - n;
    res_6n <= addition_output - ('0' & n & "00") - ('0' & n & '0');

    main : process(clk, reset_n) begin
        if (reset_n = '0') then
            state <= S_IDLE;
            n <= (others => '0');
            A <= (others => '0');
            B <= (others => '0');
            P <= (others => '0');

        elsif (rising_edge(clk)) then
            case state is
                when S_IDLE =>
                    if (valid_in = '1') then
                        n <= n_in;
                        A <= '0' & A_in;                
                        B <= B_in;
                        state <= S_PROC;
                        cntr <= c_block_size - 1;
                    else
                        n <= (others => '0');
                        A <= (others => '0');
                        B <= (others => '0');
                    end if;
                when S_PROC =>
                               
                    -- Update P for the next cc

                    if (res_n(overflow_size) = '1') then
                        P <= res(c_block_size-1 downto 0);
                    elsif res_2n(overflow_size) = '1' then
                        P <= res_n(c_block_size-1 downto 0);
                    elsif res_3n(overflow_size) = '1' then
                        P <= res_2n(c_block_size-1 downto 0);
                    elsif res_4n(overflow_size) = '1' then
                        P <= res_3n(c_block_size-1 downto 0);
                    elsif res_5n(overflow_size) = '1' then
                        P <= res_4n(c_block_size-1 downto 0);
                    elsif res_6n(overflow_size) = '1' then
                        P <= res_5n(c_block_size-1 downto 0);
                    else
                        P <= res_6n(c_block_size-1 downto 0);
                    end if;
                    
                    -- Update cntr and possibly state
                    if (cntr = 1) then
                        state <= S_DONE;
                    else
                        cntr <= cntr - 2;
                        state <= S_PROC;    
                    end if;

                when S_DONE =>
                    if (ready_in <= '1') then
                        state <= S_IDLE;
                        cntr <= c_block_size - 1;
                    end if; 
            end case;
        end if;
    end process;


end rtl_radix4;



architecture rtl_simple of modular_mult is
    TYPE State_type is (S_IDLE, S_PROC, S_DONE);
    signal state: State_type;

    signal cntr : integer range 0 to c_block_size - 1 := c_block_size - 1;
    -- n,A,B are regs storing the inputs
    signal n	: STD_LOGIC_VECTOR (c_block_size-1 downto 0); -- n is the mod
    signal  A   : std_logic_vector(c_block_size-1 downto 0);
    signal  B   : std_logic_vector(c_block_size-1 downto 0);

    -- P is the reg attached to the output.
    signal P : std_logic_vector(c_block_size-1 downto 0);

    -- These signals are the the intermediate results in the pipeline
    signal A_or_zero : std_logic_vector(c_block_size downto 0);
    signal P_or_zero : std_logic_vector(c_block_size downto 0);
    signal A_plus_P  : std_logic_vector(c_block_size+1 downto 0);

    signal res : std_logic_vector(c_block_size+1 downto 0);
    signal res_minus_n : std_logic_vector(c_block_size+1 downto 0);
    signal res_minus_2n : std_logic_vector(c_block_size+1 downto 0);

begin

    -- Connect some internal signals to external
    P_out <= P;
    ready_out <= '1' when (state = S_IDLE and reset_n = '1') else '0';
    valid_out <= '1' when (state = S_DONE and reset_n = '1') else '0';

    -- Specify the combinatorial stuff
    P_or_zero <= (others => '0') when cntr = (c_block_size - 1) else  '0' & P;
    A_or_zero <= (others => '0') when B(cntr) = '0' else '0' & A;
    A_plus_P <=  '0' &(P_or_zero(c_block_size-1 downto 0) & '0') +  A_or_zero;
    res <= A_plus_P;
    res_minus_n <= A_plus_P - ('0' & n); -- make sure n is positive
    res_minus_2n <= A_plus_P - ('0' & (n(c_block_size-1 downto 0) & '0')); --sign extend n   


    main : process(clk, reset_n) begin
        if (reset_n = '0') then
            state <= S_IDLE;
            n <= (others => '0');
            A <= (others => '0');
            B <= (others => '0');
            P <= (others => '0');
            -- valid_out <= '0';
            -- ready_out <= '0';

            -- A_or_zero <= (others => '0');
            -- P_or_zero <= (others => '0');
            -- A_plus_P <= (others => '0');
            -- res <= (others => '0');
            -- res_minus_2n <= (others => '0');
            -- res_minus_n <= (others => '0');

        elsif (rising_edge(clk)) then
            case state is
                when S_IDLE =>
                    if (valid_in = '1') then
                        n <= n_in;
                        A <= A_in;                
                        B <= B_in;
                        state <= S_PROC;
                        cntr <= c_block_size - 1;
                    else
                        n <= (others => '0');
                        A <= (others => '0');
                        B <= (others => '0');
                    end if;
                when S_PROC =>
                
                    -- if (cntr = 0) then
                    --     P_or_zero <= (others => '0');
                    -- else
                    --     P_or_zero <= P;
                    -- end if;
                    
                    -- if (B(cntr) = '1') then
                    --     A_or_zero <= A;
                    -- else
                    --     A_or_zero <= (others => '0');
                    -- end if;
                    
                    -- A_plus_P <=  (P_or_zero(c_block_size-2 downto 0) & '0') +  A_or_zero;

                    -- res <= A_plus_P;
                    -- res_minus_n <= A_plus_P - n;
                    -- res_minus_2n <= A_plus_P - (n(c_block_size-2 downto 0) & '0');
                    
                    -- Update P for the next cc
                    if (res_minus_n(c_block_size+1) = '1') then
                        P <= res(c_block_size-1 downto 0);
                    elsif (res_minus_2n(c_block_size+1) = '1') then
                        P <= res_minus_n(c_block_size-1 downto 0);
                    else
                        P <= res_minus_2n(c_block_size-1 downto 0);
                    end if;
                    
                    -- Update cntr and possibly state
                    if (cntr = 0) then
                        state <= S_DONE;
                    else
                        cntr <= cntr - 1;
                        state <= S_PROC;    
                    end if;

                when S_DONE =>
                    if (ready_in <= '1') then
                        state <= S_IDLE;
                        cntr <= c_block_size - 10;
                    end if; 
            end case;
        end if;
    end process;


end rtl_simple;
