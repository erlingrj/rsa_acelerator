library ieee;
use ieee.std_logic_1164.all;

entity exponentiation is
	generic (
		c_block_size : integer := 256;
		c_num_stages : integer := 64
	);
	port (
		--input controll
		msgin_valid	: in STD_LOGIC;
		msgin_ready	: out STD_LOGIC;
		msgin_last : in STD_LOGIC;

		--input data
		msgin_data 	: in STD_LOGIC_VECTOR ( c_block_size-1 downto 0 );
		key_in 		: in STD_LOGIC_VECTOR ( c_block_size-1 downto 0 );

		--ouput controll
		msgout_ready	: in STD_LOGIC;
		msgout_valid	: out STD_LOGIC;

		--output data
		msgout_data 	: out STD_LOGIC_VECTOR(c_block_size-1 downto 0);
		msgout_last		: out std_logic;
		--modulus
		modulus_in 	: in STD_LOGIC_VECTOR(c_block_size-1 downto 0);

		--utility
		clk 		: in STD_LOGIC;
		reset_n 	: in STD_LOGIC
	);
end exponentiation;


architecture rtl_pipelined of exponentiation is
	-- First define the modular mult component
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
	-- Create pipeline register type
	type pipe_reg_t is
		record
			msg_org	: std_logic_vector(c_block_size-1 downto 0);
			msg_run : std_logic_vector(c_block_size-1 downto 0);
			key		: std_logic_vector(c_block_size-1 downto 0);
			modulus : std_logic_vector(c_block_size-1 downto 0);
			valid	: std_logic;
			last	: std_logic;
		end record;
		
	type pipe_reg_arr_t is array (0 to c_num_stages) of pipe_reg_t;
	signal pipe_regs : pipe_reg_arr_t;

	-- FSM state types. We need one FSM per stage
	type state_t is (S_IDLE, S_PROC_MODMULT1, S_PROC_MODMULT2, S_OUTPUT,  S_DONE);
	signal state : state_t;

	-- Counters for each state
	subtype counter_t is integer range 0 to c_block_size / c_num_stages - 1;
	signal counter : counter_t;
	--type counter_arr_t is array 0 to c_num_stages of integer range 0 to c_block_size/c_num_stages - 1
	--signal counters : counter_arr_t;

	-- I/O wires for the modular_mults
	type mm_io_data_t is array (0 to c_num_stages-1) of std_logic_vector(c_block_size-1 downto 0);
	type mm_io_bool_t is array (0 to c_num_stages-1) of std_logic;

	signal mm_A_in : mm_io_data_t;
	signal mm_B_in : mm_io_data_t;
	signal mm_n_in : mm_io_data_t;
	signal mm_P_out : mm_io_data_t;
	signal mm_valid_in : mm_io_bool_t;
	signal mm_ready_in : mm_io_bool_t;
	signal mm_ready_out : mm_io_bool_t;
	signal mm_valid_out : mm_io_bool_t;

	-- Reg for storing output of MM
	signal mm_result : mm_io_data_t;

	-- Reg for doing ready out
	signal msgin_ready_r : std_logic;
begin
	GEN_MM : for i in 0 to c_num_stages-1 generate
		mod_mult : modular_mult
			generic map(c_block_size => c_block_size)
			port map
			(
				clk => clk,
				reset_n => reset_n,
				A_in => mm_A_in(i),
				B_in => mm_B_in(i),
				n_in => mm_n_in(i),
				ready_out => mm_ready_out(i),
				valid_out => mm_valid_out(i),
				ready_in => mm_ready_in(i),
				valid_in => mm_valid_in(i),
				P_out => mm_P_out(i)
			);
	end generate;

	-- Mux the inputs to the modular mults except the first where we have starting condition edge case
	-- This is very hard to just understand. Look at the diagrams in the report. It is further complicated that each modmult 
	-- operates in two-step. First the mm1 and then mm2.
	GEN_MUX_IN : for i in 1 to c_num_stages-1 generate
	   -- A input is:
	   -- MODMULT1: count=0 : pipe_regs(i).msg
	   --           count > 0 : mm_result(i)
	   -- MODMULT2: mm_result(i)
		mm_A_in(i) <= pipe_regs(i).msg_run when state = S_PROC_MODMULT1 else
					  mm_result(i) when state=S_PROC_MODMULT2 else
					  (others => '0');
	   -- B input is:
	   -- MODMULT1: count=0 : pipe_regs(i).msg
	   --           count>0 : mm_result(i)
	   -- MODMULT2: always pipe_regs(i)
		mm_B_in(i) <= pipe_regs(i).msg_run when state = S_PROC_MODMULT1 else
					  pipe_regs(i).msg_org when state=S_PROC_MODMULT2 else
					  (others => '0');
		mm_n_in(i) <= pipe_regs(i).modulus;
		-- mm_valid_in(i) <= pipe_regs(i).valid when state = S_PROC_MODMULT1 and counter = counter_t'HIGH else
		-- 			pipe_regs(i+1).valid when state = S_PROC_MODMULT1 and  counter < counter_t'HIGH else
		-- 			pipe_regs(i).msg when state=S_PROC_MODMULT2 else
		-- 			(others => '0');
	end generate;
	
	-- The first modular mult have a starting condition. Either its 1 or its msg_in, based on the value of key(c_block_size-1)
	-- When MODMULT1: Count=0 M if key(end)=e else 1
	--                Count>0 mm_result(0)
	-- When MODMULT2: Always mm_result(0)
	mm_A_in(0) <= (0 => '1', others => '0') when state = S_PROC_MODMULT1 and counter = 0 and pipe_regs(0).key(c_block_size-1) = '0' else
	              pipe_regs(0).msg_org when state = S_PROC_MODMULT1 and counter = 0 and pipe_regs(0).key(c_block_size-1) = '1' else
	              pipe_regs(0).msg_run when state=S_PROC_MODMULT1 and counter > 0 else
	              mm_result(0) when state = S_PROC_MODMULT2 else
	              (others => '0');
	              
	              
	-- First B-input has:
	-- when MODMULT1: Count=0 M if key(end)=1 else 1
	--                 Count>0 mm_result(0)
	-- When MODMULT2: Always M
	mm_B_in(0) <= (0 => '1', others => '0') when state = S_PROC_MODMULT1 and counter = 0 and pipe_regs(0).key(c_block_size-1) = '0' else
	              pipe_regs(0).msg_org when state = S_PROC_MODMULT1 and counter = 0 and pipe_regs(0).key(c_block_size-1) = '1' else
	              pipe_regs(0).msg_run when state = S_PROC_MODMULT1  and counter > 0 else
	              pipe_regs(0).msg_org when state = S_PROC_MODMULT2 else
	              (others => '0');
	              
	mm_n_in(0) <= pipe_regs(0).modulus;



	-- Outputs
	msgout_data <= pipe_regs(c_num_stages).msg_run;
	msgout_valid <= pipe_regs(c_num_stages).valid;
	msgout_last <= pipe_regs(c_num_stages).last;

	-- Inputs
	msgin_ready <= '1' when ( state=S_IDLE or (state=S_DONE and msgout_ready='1') ) else '0';


	main : process(clk, reset_n) 
		variable s_modmult1_done : std_logic := '0';
		variable s_modmult2_done : std_logic := '0';
		variable any_valid : std_logic := '0';
		variable key_idx : integer;
	begin
		s_modmult1_done := '0';
		s_modmult2_done := '0';
		if (reset_n = '0') then
			state <= S_IDLE;
			counter <= 0;
			for i in 0 to c_num_stages loop
				pipe_regs(i).msg_run <= (others => '0');
				pipe_regs(i).msg_org <= (others => '0');
				pipe_regs(i).key <= (others => '0');
				pipe_regs(i).modulus <= (others => '0');
				pipe_regs(i).valid <= '0';
				pipe_regs(i).last <= '0';
			end loop;
			
			for i in 0 to c_num_stages-1 loop
			 mm_valid_in(i) <= '0';
			 mm_result(i) <= (others => '0');
			end loop;

		elsif (rising_edge(clk)) then

			case state is
				when S_IDLE =>
					if (msgin_valid = '1') then
						pipe_regs(0).msg_org <= msgin_data;
						pipe_regs(0).msg_run <= msgin_data;
						pipe_regs(0).key <= key_in;
						pipe_regs(0).modulus <= modulus_in;
						pipe_regs(0).valid <= '1';
						pipe_regs(0).last <= msgin_last;	
						mm_valid_in(0) <= '1';	
						mm_ready_in(0) <= '1';
						state <= S_PROC_MODMULT1;
					end if;	

				when S_PROC_MODMULT1 => --processing first mod_mult
					for i in 0 to c_num_stages-1 loop
						if ( mm_valid_in(i)='1' and mm_ready_out(i)='1' ) then -- ready/valid at input
							mm_valid_in(i) <= '0'; -- Disable input
						elsif (mm_ready_in(i) = '1' and mm_valid_out(i) = '1') then -- ready/valid at output
							mm_result(i) <= mm_P_out(i); --Store result in reg
							s_modmult1_done := '1'; -- TODO: Can we fix this?
							mm_valid_in(i) <= '1';
							mm_ready_in(i) <= '1';
						end if;
					end loop;

					if s_modmult1_done = '1' then
						state <= S_PROC_MODMULT2;
					end if;

				when S_PROC_MODMULT2 =>
					for i in 0 to c_num_stages-1 loop
						if ( mm_valid_in(i)='1' and mm_ready_out(i)='1' ) then -- ready/valid at input
							mm_valid_in(i) <= '0'; -- Disable input
						elsif (mm_ready_in(i) = '1' and mm_ready_out(i) = '1') then -- ready/valid at output
							-- First store the output in the next pipeline register
							key_idx := (c_block_size / c_num_stages) * (c_num_stages - i) - (counter + 1);
							if (pipe_regs(i).key(key_idx) = '1') then
								
								if counter=counter_t'high then
								    pipe_regs(i+1).msg_run <= mm_P_out(i);
								else
								    pipe_regs(i).msg_run <= mm_P_out(i);
								end if;
							else
							    if counter=counter_t'high then
								    pipe_regs(i+1).msg_run <= mm_result(i);
								else
								    pipe_regs(i).msg_run <= mm_result(i); -- The store output of the prevoious mod mult
								end if;
							end if;

							s_modmult2_done := '1';
						end if;
					end loop;
								
					if s_modmult2_done = '1' then
						if counter = counter_t'HIGH then
							state <= S_OUTPUT;
							for i in 0 to c_num_stages-1 loop
								pipe_regs(i+1).key <= pipe_regs(i).key;
								pipe_regs(i+1).valid <= pipe_regs(i).valid;
								pipe_regs(i+1).last <= pipe_regs(i).last;
								pipe_regs(i+1).modulus <= pipe_regs(i).modulus;
								pipe_regs(i+1).msg_org <= pipe_regs(i).msg_org;
							end loop;
						else
							counter <= counter + 1;
							state <= S_PROC_MODMULT1;
							
							for i in 0 to c_num_stages-1 loop
								mm_valid_in(i) <= pipe_regs(i).valid;
								mm_ready_in(i) <= pipe_regs(i).valid;
							end loop;

						end if;
					end if;

				when S_OUTPUT => 
					-- We move to this stage when a pipeline stage is done. At this point the pipeline registers have been updated
					-- And we have moved all the data forward. So we should check if there is any data available on input
					-- Only mpve forward when the environment is ready to accept data out
					if (msgout_ready = '1') then
						-- Lastly check wheter we had valid output. In that case toggle valid since it was read
						if (pipe_regs(c_num_stages).valid = '1') then
							pipe_regs(c_num_stages).valid <= '0';
						end if;
						state <= S_DONE;
					end if;
					
				when S_DONE =>
				    -- We have outputted whatever was potentially on the output port
				    -- Now we must check wether we have any new data or what
				    for i in 0 to c_num_stages-1 loop
					   if pipe_regs(i).valid = '1' then
						  any_valid := '1';
					   end if;
					   mm_valid_in(i) <= pipe_regs(i).valid;
					   mm_ready_in(i) <= pipe_regs(i).valid;
					end loop;
					counter <= 0;
				    
				    if (msgin_valid = '1') then
						pipe_regs(0).msg_org <= msgin_data;
						pipe_regs(0).msg_run <= msgin_data;
						pipe_regs(0).key <= key_in;
						pipe_regs(0).modulus <= modulus_in;
						pipe_regs(0).valid <= '1';
						pipe_regs(0).last <= msgin_last;	
						mm_valid_in(0) <= '1';	
						mm_ready_in(0) <= '1';
						state <= S_PROC_MODMULT1;
					elsif(any_valid = '1') then
					   state <= S_PROC_MODMULT1;
					   mm_valid_in(0) <= '0';
					   mm_ready_in(0) <= '0';
					   pipe_regs(0).valid <= '0';
					else
					   state <= S_IDLE;
					end if;	
					
			end case;
		end if;
	end process;


end rtl_pipelined;
	

architecture rtl of exponentiation is
	-- First define the modular mult component
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
	-- Make are state type
	TYPE State_type is (S_IDLE, S_PROC_MODMULT1, S_PROC_MODMULT2, S_DONE);
	signal state: State_type;
	signal cntr : integer range 0 to c_block_size - 2	;

	-- Registers for storing the input message and key and modulus
	signal msgin : std_logic_vector(c_block_size-1 downto 0);
	signal modulus : std_logic_vector(c_block_size-1 downto 0);
	signal key : std_logic_vector(c_block_size-1 downto 0);
	signal msgout : std_logic_vector(c_block_size-1 downto 0);

	-- Signals attaching to the modular mults
	signal mm1_A_in : std_logic_vector(c_block_size-1 downto 0);
	signal mm1_B_in : std_logic_vector(c_block_size-1 downto 0);
	signal mm1_n_in : std_logic_vector(c_block_size-1 downto 0);
	signal mm1_valid_in : std_logic;
	signal mm1_ready_out : std_logic;
	signal mm1_valid_out : std_logic;
	signal mm1_ready_in : std_logic; 
	signal mm1_res_out : std_logic_vector(c_block_size-1 downto 0);

	signal mm1_result : std_logic_vector(c_block_size-1 downto 0);


	-- Output of the multiplexer selecting between output of modular mult1 and 2
	signal modmult1_or_modmult2 : std_logic_vector(c_block_size-1 downto 0);
	-- Output of the multiplexer between msg_in and the feedback
	signal msgin_or_msgout : std_logic_vector(c_block_size-1 downto 0);



begin
	-- First connect some signals
	msgout_data <= msgout;
	msgin_ready <= '1' when (state = S_IDLE and reset_n = '1') else '0';
	msgout_valid <= '1' when (state = S_DONE and reset_n = '1') else '0';

	-- Add the modular mults
	mm1 : modular_mult
		generic map(c_block_size => c_block_size)
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

	-- Combinatorial part
	-- 1. Output of that first MUX
		msgin_or_msgout <= msgin when ( key(c_block_size-1) = '1' and cntr = c_block_size - 2)  else
		                  (c_block_size-1 downto 1 => '0') & '1' when (cntr = c_block_size - 2) else
		                  msgout;   
		                         
	-- 2. Output of that second MUX
	modmult1_or_modmult2 <= mm1_result when key(cntr) = '0' else mm1_res_out;

	-- 3 Input to modular mult 1
	mm1_A_in <= msgin_or_msgout when state = S_IDLE or state = S_PROC_MODMULT1 else mm1_result;
	mm1_B_in <= msgin_or_msgout when state = S_IDLE or state = S_PROC_MODMULT1 else msgin;
	mm1_n_in <= modulus;

	-- 4. Input to modular mult 2
	-- mm2_A_in <= mm1_result;
	-- mm2_B_in <= msgin;
	-- mm2_n_in <= modulus;

	main : process(clk, reset_n) begin
		if (reset_n = '0') then
			state <= S_IDLE;
			msgin <= (others => '0');
			msgout <= (others => '0');
			key <= (others => '0');
			modulus <= (others => '0');
			
			mm1_ready_in <= '0';
			mm1_valid_in <= '0';
			--mm2_ready_in <= '0';
			--mm2_valid_in <= '0';

			cntr <= c_block_size - 2;

			mm1_result <= (others => '0');
			--mm2_result <= (others => '0');

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
						-- mm1_ready_in <= '0'; -- move to modmult2
						mm1_result <= mm1_res_out; -- store the output for modmult1 in a register
						state <= S_PROC_MODMULT2;
						mm1_valid_in <='1';
						mm1_ready_in <='1';
					end if;
				when S_PROC_MODMULT2 => 
					if (mm1_valid_in ='1' and mm1_ready_out = '1') then -- ready/valid handshake input
						mm1_valid_in <= '0';
					elsif (mm1_ready_in = '1' and mm1_valid_out = '1') then -- ready/valid handshake output
						mm1_ready_in <= '0';

						-- Mux out the result
						if key(cntr) = '0' then
							msgout <= mm1_result;
						else
							msgout <= mm1_res_out;
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
						cntr <= c_block_size - 2;
						state <= S_IDLE;
					end if;
			end case;
		end if;
	end process;
end rtl;


configuration cfg of exponentiation is
for rtl_pipelined
    for ALL : modular_mult
		use entity work.modular_mult(rtl_simple);
    end for;
end for;
end configuration cfg;
