library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity modular_mult_tb is
	generic (
		c_block_size : integer := 256
	);
end modular_mult_tb;


architecture tb of modular_mult_tb is


    component modular_mult is
        generic (
            c_block_size : integer := 256
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
    end component;


    signal t_valid_in : std_logic;
    signal t_ready_in : std_logic;
    signal t_n_in : std_logic_vector(c_block_size-1 downto 0);
    signal t_A_in : std_logic_vector(c_block_size-1 downto 0);
    signal t_B_in : std_logic_vector(c_block_size-1 downto 0);
    signal t_ready_out : std_logic;
    signal t_valid_out : std_logic;
    signal t_P_out : std_logic_vector(c_block_size-1 downto 0);
    signal t_clk : std_logic := '0';
    signal t_reset_n : std_logic := '0';

    constant CLK_PERIOD : time := 10 ns;
    constant RESET_TIME : time := 20 ns;

begin
    dut : modular_mult
        generic map(c_block_size => c_block_size)
		port map (
            valid_in => t_valid_in,
            ready_in => t_ready_in,
            n_in => t_n_in,
            A_in => t_A_in,
            B_in => t_B_in,
            ready_out => t_ready_out,
            valid_out => t_valid_out,
            P_out => t_P_out,
            clk => t_clk,
            reset_n => t_reset_n
        );

    t_clk <= not t_clk after CLK_PERIOD/2;
    
    -- Reset generation
    reset_proc : process
    begin  
        wait for RESET_TIME;
        t_reset_n <= '1';
        wait;
    end process;


    main_tb : process
        file input_file : text open read_mode is "/home/erling/phd/courses/dds1/project/tfe4141_rsa_integration_kit_2020/Exponentiation/testbench/modular_mult_tb_stimuli.txt";
        variable text_line : line;
        variable ok : boolean;
        variable char : character;
        variable input_A : std_logic_vector(c_block_size-1 downto 0);
        variable input_B : std_logic_vector(c_block_size-1 downto 0);
        variable input_n : std_logic_vector(c_block_size-1 downto 0);
        variable input_res : std_logic_vector(c_block_size-1 downto 0);
    begin
        wait for RESET_TIME*2;

        while not endfile(input_file) loop
            readline(input_file, text_line);
            -- Skip empty lines and single-line comments
            if text_line.all'length = 0 or text_line.all(1) = '#' then
                next;
            end if;

            
            hread(text_line, input_A, ok);
            assert ok
                report "Read 'A' failed line: " & text_line.all
                severity failure;
            
            hread(text_line, input_B, ok);
            assert ok
                report "Read 'B' failed line: " & text_line.all
                severity failure;
            
            hread(text_line, input_n, ok);
            assert ok
                report "Read 'n' failed line: " & text_line.all
                severity failure;

            hread(text_line, input_res, ok);
            assert ok
                report "Read 'res' failed line: " & text_line.all
                severity failure;
   
   
            -- Apply inputs
            t_valid_in <= '1';
            t_A_in <= input_A;
            t_B_in <= input_B;
            t_n_in <= input_n;    
            
            -- Wait until input is accepted
            wait until t_ready_out = '0';
            t_valid_in <= '0';
            
            -- Wait until we have the result
            wait until t_valid_out = '1';
            -- Verify that output is correct
            assert t_P_out = input_res
                report "Modular_mult failed for line: " & text_line.all
                severity failure;
            -- Accept output
            t_ready_in <= '1';

            wait until t_valid_out = '0';
            
            report "Line: " & text_line.all & "successful";
        end loop;
        
   end process;
end tb;


configuration tb_cfg of modular_mult_tb is
for tb
    for dut : modular_mult
        use entity work.modular_mult(rtl_simple);
     end for;
end for;
end configuration tb_cfg;