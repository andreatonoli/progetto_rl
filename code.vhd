library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity project_reti_logiche is
    port (
        i_clk     : in std_logic;                     
        i_rst     : in std_logic;                     
        i_start   : in std_logic;                     
        i_add     : in std_logic_vector(15 downto 0); 
        i_k       : in std_logic_vector(9 downto 0);  
        
        o_done    : out std_logic;                     
        o_mem_addr : out std_logic_vector(15 downto 0); 
        i_mem_data : in std_logic_vector(7 downto 0);   
        o_mem_data : out std_logic_vector(7 downto 0);  
        o_mem_we   : out std_logic;                     
        o_mem_en   : out std_logic                      
     );
end project_reti_logiche;

ARCHITECTURE Behavioral OF project_reti_logiche IS

    signal counter: unsigned(9 downto 0) := (others => '0');              -- Contatore delle parole lette
    signal w: std_logic_vector(7 downto 0) := (others => '0');            -- Dati letti dalla memoria
    signal last_valid_w: std_logic_vector(7 downto 0) := (others => '0'); -- Ultimo dato valido letto
    signal c: unsigned(7 downto 0) := to_unsigned(31, 8);                 -- Valore di credibilità
    
    TYPE states IS (READY_TO_START, SETUP_READING, READING, SETUP_WRITING, WRITE_W, WRITE_C, DONE_STATE);
    signal curr_state, next_state : states;

begin 

    -- processo per impostare lo stato futuro della fsm
    fsm_next_state: process(curr_state, i_start, counter, i_k)
    begin
    
        case curr_state is

            when READY_TO_START =>
                if i_start = '1' then
                    next_state <= SETUP_READING;
                else
                    next_state <= READY_TO_START;
                end if;

            when SETUP_READING =>
                next_state <= READING;

            when READING =>
                next_state <= SETUP_WRITING;

            when SETUP_WRITING =>
                next_state <= WRITE_W;

            when WRITE_W =>
                next_state <= WRITE_C;

            when WRITE_C =>
                if counter >= unsigned(i_k) - 1 then
                    next_state <= DONE_STATE;
                else
                    next_state <= SETUP_READING;
                end if;

            when DONE_STATE =>
                if i_start = '0' then
                    next_state <= READY_TO_START;
                else
                    next_state <= DONE_STATE;
                end if;

        end case;
    end process;
    
    -- processo per impostare lo stato corrente della fsm
    fsm_curr_state: process(i_clk, i_rst)
    begin
    
    if i_rst = '1' then       
            curr_state <= READY_TO_START;
    elsif rising_edge(i_clk) then        
            curr_state <= next_state;
    end if;
    
    end process;
    
    -- processo per definire cosa succederà nei vari stati della fsm
    fsm_operations: process(i_clk, i_rst)
    begin
        
        if i_rst = '1' then
        
           o_mem_addr <= (others => '0');
           o_mem_en <= '0';
           o_mem_we <= '0';
           o_mem_data <= (others => '0');
           o_done <= '0';
           w <= (others => '0');                
           counter <= (others => '0');
           last_valid_w <= (others => '0');
           c <= to_unsigned(0, 8);
         
        elsif rising_edge(i_clk) then
              
            o_mem_addr <= (others => '0');
            o_mem_en <= '0';
            o_mem_we <= '0';
            o_mem_data <= (others => '0');
            o_done <= '0';
    
            case curr_state is 
            
                -- stato per resettare tutti i segnali interni
                when READY_TO_START =>
                    w <= (others => '0');                
                    counter <= (others => '0');
                    last_valid_w <= (others => '0');
                    c <= to_unsigned(0, 8);
                
                -- stato per preparare la memoria alla lettura
                when SETUP_READING =>
                    o_mem_en <= '1';
                    o_mem_we <= '0';
                    o_mem_addr <= std_logic_vector(unsigned(i_add) + (counter & '0'));
                
                 -- stato utilizzato per impostare il segnale i_mem_data   
                when READING =>
                    o_mem_en <= '1';
                    o_mem_we <= '0';
                    o_mem_addr <= std_logic_vector(unsigned(i_add) + (counter & '0'));
                
                -- stato per preparare la memoria alla scrittura
                when SETUP_WRITING =>
                    w <= i_mem_data;                             
                    o_mem_en <= '1';
                    o_mem_we <= '1';
                    o_mem_addr <= std_logic_vector(unsigned(i_add) + (counter & '0'));
                
                -- stato per scrivere in memoria il valore della parola W       
                when WRITE_W =>
                    o_mem_en <= '1';
                    o_mem_we <= '1';
                    o_mem_addr <= std_logic_vector(unsigned(i_add) + (counter & '0'));
                    if w = std_logic_vector(to_unsigned(0, 8)) then
                        if counter = 0 then
                            o_mem_data <= std_logic_vector(to_unsigned(0, 8));
                            c <= to_unsigned(0, 8);
                        else
                            o_mem_data <= last_valid_w;
                            if c > 0 then
                                c <= c - 1;
                            end if;
                        end if;
                    else
                        o_mem_data <= w;
                        last_valid_w <= w;
                        c <= to_unsigned(31, 8);
                    end if;
                
                -- stato per scrivere in memoria il valore di credibilità C  
                when WRITE_C =>
                    o_mem_en <= '1';
                    o_mem_we <= '1';
                    o_mem_addr <= std_logic_vector(unsigned(i_add) + (counter & '0') + 1);
                    o_mem_data <= std_logic_vector(c);
                    counter <= counter + 1;
                
                -- stato per terminare l' elaborazione       
                when DONE_STATE =>
                    o_done <= '1';
                    
            end case; 
        end if;                        
    end process;

end Behavioral;