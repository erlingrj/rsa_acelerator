library ieee;
use ieee.std_logic_1164.all;


entity modular_mult_tb is
	generic (
		block_size : integer := 256
	);
end modular_mult_tb;


architecture tb of modular_mult_tb is


    component modular_mult is
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
    end component;


    signal t_valid_in : std_logic;
    signal t_ready_in : std_logic;
    signal t_n_in : std_logic_vector(block_size-1 downto 0);
    signal t_A_in : std_logic_vector(block_size-1 downto 0);
    signal t_B_in : std_logic_vector(block_size-1 downto 0);
    signal t_ready_out : std_logic;
    signal t_valid_out : std_logic;
    signal t_P_out : std_logic_vector(block_size-1 downto 0);
    signal t_clk : std_logic := '0';
    signal t_reset_n : std_logic := '0';

    constant CLK_PERIOD : time := 10 ns;
    constant RESET_TIME : time := 20 ns;

begin
    dut : modular_mult
        generic map(block_size => block_size)
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

end tb;
