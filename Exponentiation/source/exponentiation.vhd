library ieee;
use ieee.std_logic_1164.all;

entity exponentiation is
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
end exponentiation;


architecture rtl of exponentiation is
	-- First define the modular mult component
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
	-- Make are state type
	TYPE State_type is (S_IDLE, S_PROC_MODMULT1, S_PROC_MODMULT2, S_DONE);
	signal state: State_type;
	signal cntr : integer range 0 to block_size - 2	;

	-- Registers for storing the input message and key and modulus
	signal msgin : std_logic_vector(block_size-1 downto 0);
	signal modulus : std_logic_vector(block_size-1 downto 0);
	signal key : std_logic_vector(block_size-1 downto 0);
	signal msgout : std_logic_vector(block_size-1 downto 0);

	-- Signals attaching to the modular mults
	signal mm1_A_in : std_logic_vector(block_size-1 downto 0);
	signal mm1_B_in : std_logic_vector(block_size-1 downto 0);
	signal mm1_n_in : std_logic_vector(block_size-1 downto 0);
	signal mm1_valid_in : std_logic;
	signal mm1_ready_out : std_logic;
	signal mm1_valid_out : std_logic;
	signal mm1_ready_in : std_logic; 
	signal mm1_res_out : std_logic_vector(block_size-1 downto 0);

	signal mm2_A_in : std_logic_vector(block_size-1 downto 0);
	signal mm2_B_in : std_logic_vector(block_size-1 downto 0);
	signal mm2_n_in : std_logic_vector(block_size-1 downto 0);
	signal mm2_valid_in : std_logic;
	signal mm2_ready_out : std_logic;
	signal mm2_valid_out : std_logic;
	signal mm2_ready_in : std_logic;
	signal mm2_res_out : std_logic_vector(block_size-1 downto 0);

	signal mm1_result : std_logic_vector(block_size-1 downto 0);
	signal mm2_result : std_logic_vector(block_size-1 downto 0);


	-- Output of the multiplexer selecting between output of modular mult1 and 2
	signal modmult1_or_modmult2 : std_logic_vector(block_size-1 downto 0);
	-- Output of the multiplexer between msg_in and the feedback
	signal msgin_or_msgout : std_logic_vector(block_size-1 downto 0);



begin
	-- First connect some signals
	msgout_data <= msgout;
	msgin_ready <= '1' when (state = S_IDLE and reset_n = '1') else '0';
	msgout_valid <= '1' when (state = S_DONE and reset_n = '1') else '0';

	-- Add the modular mults
	mm1 : modular_mult
		generic map(block_size => block_size)
		port map(
			clk => clk,
			reset_n => reset_n,
			A_in => mm1_A_in,
			B_in => mm1_B_in,
			n_in => mm1_n_in,
			ready_out => mm1_ready_out,
			valid_out => mm1_valid_out,
			ready_in => mm1_ready_in,
			valid_in => mm1_valid_in,
			P_out => mm1_res_out
		);
	mm2 : modular_mult
		generic map(block_size => block_size)
		port map(
			clk => clk,
			reset_n => reset_n,
			A_in => mm2_A_in,
			B_in => mm2_B_in,
			n_in => mm2_n_in,
			ready_out => mm2_ready_out,
			valid_out => mm2_valid_out,
			ready_in => mm2_ready_in,
			valid_in => mm2_valid_in,
			P_out => mm2_res_out
		);

	-- Combinatorial part
	-- 1. Output of that first MUX
		msgin_or_msgout <= msgin when ( key(block_size-1) = '1' and cntr = block_size - 2)  else
		                  (block_size-1 downto 1 => '0') & '1' when (cntr = block_size - 2) else
		                  msgout;   
		                         
	-- 2. Output of that second MUX
	modmult1_or_modmult2 <= mm1_result when key(cntr) = '0' else mm2_result;

	-- 3 Input to modular mult 1
	mm1_A_in <= msgin_or_msgout;
	mm1_B_in <= msgin_or_msgout;
	mm1_n_in <= modulus;

	-- 4. Input to modular mult 2
	mm2_A_in <= mm1_result;
	mm2_B_in <= msgin;
	mm2_n_in <= modulus;

	main : process(clk, reset_n) begin
		if (reset_n = '0') then
			state <= S_IDLE;
			msgin <= (others => '0');
			msgout <= (others => '0');
			key <= (others => '0');
			modulus <= (others => '0');
			
			mm1_ready_in <= '0';
			mm1_valid_in <= '0';
			mm2_ready_in <= '0';
			mm2_valid_in <= '0';

			cntr <= block_size - 2;

			mm1_result <= (others => '0');
			mm2_result <= (others => '0');

		elsif (rising_edge(clk)) then
			msgout <= modmult1_or_modmult2; --msgout is a register
			case state is
				when S_IDLE =>
					if (msgin_valid = '1') then
						msgin <= msgin_data;
						key <= key_in;
						modulus <= modulus_in;
						
						state <= S_PROC_MODMULT1;
						mm1_valid_in <= '1';
						mm1_ready_in <= '1';
					end if;		
				when S_PROC_MODMULT1 => --processing first mod_mult
					if (mm1_valid_in ='1' and mm1_ready_out = '1') then -- ready_valid handshake input
						mm1_valid_in <= '0';
					elsif (mm1_ready_in = '1' and mm1_valid_out = '1') then -- ready/valid handshake output
						mm1_ready_in <= '0'; -- move to modmult2
						mm1_result <= mm1_res_out; -- store the output for modmult1 in a register
						state <= S_PROC_MODMULT2;
						mm2_valid_in <='1';
						mm2_ready_in <='1';
					end if;
				when S_PROC_MODMULT2 => 
					if (mm2_valid_in ='1' and mm2_ready_out = '1') then -- ready/valid handshake input
						mm2_valid_in <= '0';
					elsif (mm2_ready_in = '1' and mm2_valid_out = '1') then -- ready/valid handshake output
						mm2_ready_in <= '0';

						-- Mux out the result
						if key(cntr) = '0' then
							msgout <= mm1_result;
						else
							msgout <= mm2_res_out;
						end if;
						
						if cntr = 0 then
							state <= S_DONE;

						else
							cntr <= cntr - 1;
							state <= S_PROC_MODMULT1;
							mm1_valid_in <= '1';
							mm1_ready_in <= '1';
						end if;
					end if;

				when S_DONE => 
					if (msgout_ready = '1') then
						cntr <= block_size - 2;
						state <= S_IDLE;
					end if;
			end case;
		end if;
	end process;
end rtl;
