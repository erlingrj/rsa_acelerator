library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity exponentiation_tb is
	generic (
		block_size : integer := 256
	);
end exponentiation_tb;


architecture tb of exponentiation_tb is
	component exponentiation is
		generic (
			block_size : integer := 256
		);
		port (
			--input controll
			msgin_valid	: in STD_LOGIC;
			msgin_ready	: out STD_LOGIC;
	
			--input data
			msgin_data 	: in STD_LOGIC_VECTOR ( block_size-1 downto 0 );
			key_in 		: in STD_LOGIC_VECTOR ( block_size-1 downto 0 );
	
			--ouput controll
			msgout_ready	: in STD_LOGIC;
			msgout_valid	: out STD_LOGIC;
	
			--output data
			msgout_data 	: out STD_LOGIC_VECTOR(block_size-1 downto 0);
	
			--modulus
			modulus_in 	: in STD_LOGIC_VECTOR(block_size-1 downto 0);
	
			--utility
			clk 		: in STD_LOGIC;
			reset_n 	: in STD_LOGIC
		);
	end component;
	

	-- IO
	signal t_msgin_valid	:  STD_LOGIC;
	signal t_msgin_ready	:  STD_LOGIC;
	signal t_msgin_data 	:  STD_LOGIC_VECTOR ( block_size-1 downto 0 );
	signal t_key_in 		:  STD_LOGIC_VECTOR ( block_size-1 downto 0 );
	signal t_msgout_ready	:  STD_LOGIC;
	signal t_msgout_valid	:  STD_LOGIC;
	signal t_msgout_data 	:  STD_LOGIC_VECTOR(block_size-1 downto 0);
	signal t_modulus_in 	:  STD_LOGIC_VECTOR(block_size-1 downto 0);
	signal t_clk 		:  STD_LOGIC := '0';
	signal t_reset_n 	:  STD_LOGIC := '0';

    constant CLK_PERIOD : time := 10 ns;
    constant RESET_TIME : time := 20 ns;

begin
	dut : exponentiation 
	generic map (block_size => block_size)
	port map(
		clk => t_clk,
		msgin_valid => t_msgin_valid,
		msgin_ready => t_msgin_ready,
		msgin_data => t_msgin_data,
		key_in => t_key_in,
		msgout_ready => t_msgout_ready,
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
    begin
        wait for RESET_TIME*2;
        -- Send A = 115792089237316195423570985008687901296399, B = 1089237315423570985000785326998466564056574007929639936, n = 2357098500868790785326998466564056403945758400791312963993634
        -- Expected result: 17701029
        
        --t_A_in <= std_logic_vector(to_unsigned(8923731,block_size));
        --t_B_in <= std_logic_vector(to_unsigned(850089,block_size));
        --t_n_in <= std_logic_vector(to_unsigned(73154235,block_size));
		t_msgin_data <=   x"000000000000000000000000000000000000c00d00e023004123b000a0010001";

		t_key_in <=       x"0000000000000000000000000000000000000000000000000000000000010001";
		t_modulus_in <=   x"d5286d56ea8485df7e3124f15bac98b065fc8e385dfba734382efdf88a28796b";

        wait for CLK_PERIOD;
        t_msgin_valid <= '1';
        t_msgout_ready <= '1';
        wait;
        -- Should return 28564769079275904533887512124673906025635931168140158811629299862180222723732 dec
        -- 5d2c1abe2f58ee48f4d24abf762cae3be2707c144385186a4b221c06dcff1711
   end process;
end tb;
