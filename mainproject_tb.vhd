--
-- Damir Kadyrzhan 20494312
-- Test Bench: mainproiect_tb.vhd 
-- Read A B C and write D buffer 
-- 


-- Libraries 
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;
use std.textio.all;
library std;
 
entity mainproject_tb is
end mainproject_tb;
 
architecture behavior of mainproject_tb is 

-- Component declaration
component mainproject
    port(
        Reset, Clock,   WriteEnable :     in std_logic;
        BufferSel:      in std_logic_vector (1 downto 0);
        WriteAddress:   in std_logic_vector (9 downto 0);
        WriteData:      in std_logic_vector (15 downto 0);

        ReadAddress:    in std_logic_vector (9 downto 0);
        ReadEnable:     in std_logic;
        ReadData:       out std_logic_vector (63 downto 0);
        
        DataReady:      out std_logic
    );
end component;   
     
-- Test Bench Signal Declaration 
signal tb_Reset : std_logic := '0';
signal tb_Clock : std_logic := '0';
signal tb_BufferSel : std_logic_vector(1 downto 0) := "00";
signal tb_WriteEnable : std_logic := '0';
signal tb_WriteAddress : std_logic_vector(9 downto 0) := (others => '0');
signal tb_WriteData : std_logic_vector(15 downto 0) := (others => '0');
signal tb_ReadEnable : std_logic := '0';
signal tb_ReadAddress : std_logic_vector(9 downto 0) := (others => '0');

signal tb_DataReady : std_logic;
signal tb_ReadData : std_logic_vector(63 downto 0);


-- Clock period definitions
constant period : time := 200 ns;    

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: mainproject 
        PORT MAP (
            Reset           => tb_Reset,
            Clock           => tb_Clock,
            WriteEnable     => tb_WriteEnable,
            BufferSel       => tb_BufferSel,

            WriteAddress    => tb_WriteAddress,
            WriteData       => tb_WriteData,        

            ReadEnable      => tb_ReadEnable,
            ReadAddress     => tb_ReadAddress,
            ReadData        => tb_ReadData,
        
            DataReady       => tb_DataReady
      );
    
    -- Clock Process
    process 
    begin
        while now <= 100000 * period loop
            tb_Clock <= '0';
            wait for period/2;
            tb_Clock <= '1';
            wait for period/2;
        end loop;
        wait;
    end process;
    
    -- Reset Process 
    process is  
    begin
        tb_Reset <= '1';
        wait for 10*period;
        tb_Reset <= '0';
        wait;   
    end process;
        
        
    reading: process is                     
        
        -- Assign variables for input files 
        file FIA: TEXT open READ_MODE is "InputA.txt";    
        file FIB: TEXT open READ_MODE is "InputB.txt";
        file FIC: TEXT open READ_MODE is "InputC.txt";    
        
        -- Read Line Variable 
        variable L: LINE;
        
        -- Detect the spaces for each line (4)
        variable tb_PreCharacterSpace: string(5 downto 1);
        
        -- Collected data from the line that will be passed to main design 
        variable tb_MatrixData: std_logic_vector(7 downto 0);
    begin
        
        
        -- Set default values 
        tb_WriteEnable <= '0';
        tb_WriteAddress <= "11" & x"FF"; -- Max number of lines 0 to 1023 
        wait for 20*period;
        
        -- Read file to Buffer A 
        while not ENDFILE(FIA)  loop
            READLINE(FIA, L);   -- Read line     
            READ(L, tb_PreCharacterSpace); -- Skip 4 spaces 
            HREAD(L, tb_MatrixData);    -- Read the data and assign to tb_MatrixData
            wait until falling_edge(tb_Clock);
            tb_WriteAddress <= std_logic_vector(unsigned(tb_WriteAddress)+1);
            tb_BufferSel <= "00";
            tb_WriteEnable <= '1';
            tb_WriteData <= ("00000000" & tb_MatrixData(7 downto 0)); -- Write data to tb_WriteData
        end loop;
        
        -- Read file to Buffer B
        while not ENDFILE(FIB)  loop
            READLINE(FIB, L);       
            READ(L, tb_PreCharacterSpace);
            HREAD(L, tb_MatrixData);    
            wait until falling_edge(tb_Clock);
            tb_WriteAddress <= std_logic_vector(unsigned(tb_WriteAddress)+1);
            tb_BufferSel <= "01";
            tb_WriteEnable <= '1';
            tb_WriteData <=("00000000" & tb_MatrixData(7 downto 0));
        end loop;
        
        -- Read file to Buffer C
        while not ENDFILE(FIC)  loop
            READLINE(FIC, L);       
            READ(L, tb_PreCharacterSpace);
            HREAD(L, tb_MatrixData);    
            wait until falling_edge(tb_Clock);
            tb_WriteAddress <= std_logic_vector(unsigned(tb_WriteAddress)+1);
            tb_BufferSel <= "10";
            tb_WriteEnable <= '1';
            tb_WriteData <= ("00000000" & tb_MatrixData(7 downto 0));
        end loop;
        
        wait for period;
        tb_WriteEnable <= '0';      
        wait; 
    end process;    
    
    -- Process to write output to OutputD.txt 
    writing: process is                     
        file FO: TEXT open WRITE_MODE is "OutputD.txt";
        file FI: TEXT open READ_MODE is "OutputD_matlab.txt";
        variable L, Lm: LINE;
        variable tb_PreCharacterSpace: string(5 downto 1);
        variable v_ReadDatam: std_logic_vector(19 downto 0);
        variable v_OK: boolean;
    begin
        tb_ReadEnable <= '0';
        tb_ReadAddress <=(others =>'0');
        
        ---wait for Multiplication done 
        wait until rising_edge(tb_DataReady); 
        
        wait until falling_edge(tb_DataReady); 

        -- After the processing is done write Matlab and simulation data into one file 
        Write(L, STRING'("Results"));
        WRITELINE(FO, L);
        Write(L, STRING'("Data from Matlab"), Left, 20);
        Write(L, STRING'("Data from Simulation"), Left, 20);
        WRITELINE(FO, L);
        tb_ReadEnable<= '1';
        while not ENDFILE(FI)  loop
            wait until rising_edge(tb_Clock);
            wait for 5 ns;
            
            READLINE(FI, Lm);
            READ(Lm, tb_PreCharacterSpace);
            HREAD(Lm, v_ReadDatam);     
            if v_ReadDatam = tb_ReadData(19 downto 0) then
                v_OK := True;
            else
                v_OK := False;
            end if;
            HWRITE(L, v_ReadDatam, Left, 20);
            HWRITE(L, tb_ReadData(19 downto 0), Left, 20);
            WRITE(L, v_OK, Left, 10);           
            WRITELINE(FO, L);       

            tb_ReadAddress <= std_logic_vector(unsigned(tb_ReadAddress)+1);

        end loop;
        tb_ReadEnable <= '0';
        wait;  
    end process;
    
end;