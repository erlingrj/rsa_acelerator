library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity exponentiation_tb is
	generic (
		c_block_size : integer := 256
	);
end exponentiation_tb;


architecture tb of exponentiation_tb is
	component exponentiation is
		generic (
			c_block_size : integer := 256;
			c_num_stages : integer := 64
		);
		port (
			--input controll
			msgin_valid	: in STD_LOGIC;
			msgin_ready	: out STD_LOGIC;
	
			--input data
			msgin_data 	: in STD_LOGIC_VECTOR ( c_block_size-1 downto 0 );
			key_in 		: in STD_LOGIC_VECTOR ( c_block_size-1 downto 0 );
	
			--ouput controll
			msgout_ready	: in STD_LOGIC;
			msgout_valid	: out STD_LOGIC;
			msgin_last      : in STD_LOGIC;
	
			--output data
			msgout_data 	: out STD_LOGIC_VECTOR(c_block_size-1 downto 0);
	
			--modulus
			modulus_in 	: in STD_LOGIC_VECTOR(c_block_size-1 downto 0);
	
			--utility
			clk 		: in STD_LOGIC;
			reset_n 	: in STD_LOGIC
		);
	end component;
	

	-- IO
	signal t_msgin_valid	:  STD_LOGIC;
	signal t_msgin_ready	:  STD_LOGIC;
	signal t_msgin_data 	:  STD_LOGIC_VECTOR ( c_block_size-1 downto 0 );
	signal t_key_in 		:  STD_LOGIC_VECTOR ( c_block_size-1 downto 0 );
	signal t_msgin_last     : STD_LOGIC;
	signal t_msgout_ready	:  STD_LOGIC;
	signal t_msgout_valid	:  STD_LOGIC;
	signal t_msgout_data 	:  STD_LOGIC_VECTOR(c_block_size-1 downto 0);
	signal t_modulus_in 	:  STD_LOGIC_VECTOR(c_block_size-1 downto 0);
	signal t_clk 		:  STD_LOGIC := '0';
	signal t_reset_n 	:  STD_LOGIC := '0';

    constant CLK_PERIOD : time := 10 ns;
    constant RESET_TIME : time := 20 ns;

begin
	dut : exponentiation 
	generic map (
	c_block_size => c_block_size,
	c_num_stages => 2)
	port map(
		clk => t_clk,
		msgin_valid => t_msgin_valid,
		msgin_ready => t_msgin_ready,
		msgin_data => t_msgin_data,
		key_in => t_key_in,
		msgout_ready => t_msgout_ready,
		msgin_last => t_msgin_last,
		msgout_valid => t_msgout_valid,
		msgout_data => t_msgout_data,
		modulus_in => t_modulus_in,
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
        file input_file : text open read_mode is "/home/erling/phd/courses/dds1/project/tfe4141_rsa_integration_kit_2020/Exponentiation/testbench/rsa_top_tb_stimuli.txt";
        variable text_line : line;
        variable ok : boolean;
        variable char : character;
        variable input_M : std_logic_vector(c_block_size-1 downto 0);
        variable input_n : std_logic_vector(c_block_size-1 downto 0);
        variable input_e : std_logic_vector(c_block_size-1 downto 0);
		variable input_res : std_logic_vector(c_block_size-1 downto 0);
		variable it : integer := 0;
	begin
        wait for RESET_TIME*2;
        t_msgin_last <= '0';
        t_msgout_ready <= '0';
        while not endfile(input_file) loop
            readline(input_file, text_line);
            -- Skip empty lines and single-line comments
			it := it + 1;
			if text_line.all'length = 0 or text_line.all(1) = '#' then
                next;
            end if;

            
            hread(text_line, input_M, ok);
            assert ok
                report "Read 'A' failed line: " & text_line.all
                severity failure;
            
            hread(text_line, input_n, ok);
            assert ok
                report "Read 'B' failed line: " & text_line.all
                severity failure;
            
            hread(text_line, input_e, ok);
            assert ok
                report "Read 'n' failed line: " & text_line.all
                severity failure;

            hread(text_line, input_res, ok);
            assert ok
                report "Read 'res' failed line: " & text_line.all
                severity failure;
   
   
            -- Apply inputs
            t_msgin_valid <= '1';
            t_msgin_data <= input_M;
            t_key_in <= input_e;
            t_modulus_in <= input_n;    
            t_msgout_ready <= '1';
            
            -- Wait until input is accepted
            wait until t_msgin_ready = '0';
            t_msgin_valid <= '0';
            
            -- Wait until we have the result
            wait until t_msgout_valid = '1';
            -- Verify that output is correct
            assert t_msgout_data = input_res
                report "RSA TOP failed for line: " & text_line.all
                severity failure;
            wait until t_msgout_valid = '0';
            t_msgout_ready <= '0';
            report "Line: " & integer'image(it) & " successful";
        end loop;
        
            assert false
                report "Simulation succeeded Stopping now"
                severity failure;
        
   end process;
end tb;


configuration cfg_tb of exponentiation_tb is
for tb
    for dut: exponentiation
		use entity work.exponentiation(rtl_pipelined);
    end for;
end for;
end configuration cfg_tb;


