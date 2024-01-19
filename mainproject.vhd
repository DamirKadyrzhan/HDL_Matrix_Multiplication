--
-- Damir Kadyrzhan 20494312
-- Main Project Design : mainproject.vhd 
-- Matrix Multiplier: D = A x B + C 
-- Input Matrix: A, B, C - Size: 32 x 32 - 16 bits 
-- Output Matrix: D - Size: 32 x 32 - 64 bits 
--

-- Libraries 
library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all;

-- Entity declaration
entity mainproject is
    port(
        Reset, Clock, WriteEnable:in std_logic;
        -- BufferSel: "00" for input buffer A, "01" for input buffer B, "10"for input buffer C
        BufferSel: in std_logic_vector(1 downto 0);
        WriteAddress: in std_logic_vector (9 downto 0);
        WriteData: in std_logic_vector (15 downto 0);
        ReadAddress: in std_logic_vector (9 downto 0);
        ReadEnable: in std_logic;
        ReadData: out std_logic_vector (63 downto 0);
        DataReady: out std_logic
    );
end mainproject;

architecture mainproject_arch of mainproject is
    
-- IP Core components 
COMPONENT dpram1024x16
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    clkb : IN STD_LOGIC;
    enb : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
  );
END COMPONENT;

COMPONENT dpram1024x64
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    clkb : IN STD_LOGIC;
    enb : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
  );
END COMPONENT;

-- state definitions
type    stateType is (stIdle, stWriteBufferA, stWriteBufferB, stWriteBufferC, stReadBufferAB, stReadBufferABC, stInitialiseCbuf , stWaitWriteBufferD, stWriteBufferD, stComplete);
                
signal presState: stateType;
signal nextState: stateType;

-- Write data onto buffers at specific time
signal iWriteEnableA, iWriteEnableB, iWriteEnableC, iWriteEnableD: std_logic_vector(0 downto 0);

-- Read Enable Signals (Enable the calculations) 
signal iReadEnableAB, iReadEnableABC : std_logic;

-- Enable the count of columns and rows at specific times 
signal iMacEnable, iCountEnable, iRowCountAEnable, iColCountAEnable, iColCountBEnable, iColCountCEnable : std_logic;

-- Reset Signals at specific time
signal iMacReset, iCountReset, iRowCountAReset, iColCountAReset, iColCountBReset, iColCountCReset : std_logic;

-- Read and Write to specific buffer address 
signal iWriteAddressD, iWriteAddressD1, iReadAddressA, iReadAddressB, iReadAddressC: std_logic_vector(9 downto 0);

-- Read the data at specific address 
signal iReadDataA, iReadDataB, iReadDataC: std_logic_vector (15 downto 0);

-- Output result signal
signal iMacResult: std_logic_vector (63 downto 0);

-- Counter to count each position of data 
signal iColCountA: unsigned(4 downto 0); 

-- Counter of Rows and Columns of buffer A and B to do matrix multiplication 
signal iRowCountA, iColCountB: unsigned(5 downto 0); 

-- Counter to load data into buffers
signal iCount: unsigned(9 downto 0); 

-- Counter of buffer C address at specific time
signal iColCountC : unsigned(9 downto 0);  

begin   


    -- Enable load data into buffers when BufferSel is at specific number 
    iWriteEnableA(0) <= WriteEnable when (BufferSel = "00") else '0';
    iWriteEnableB(0) <= WriteEnable when (BufferSel = "01") else '0';
    iWriteEnableC(0) <= WriteEnable when (BufferSel = "10") else '0';
    
    
    -- Port maps of IP cores to declared components 
    InputBufferA : dpram1024x16
        PORT MAP (
            clka    => Clock,
            wea     => iWriteEnableA,
            addra   => WriteAddress,
            dina    => WriteData,
            clkb    => Clock,
            enb     => iReadEnableAB,
            addrb   => iReadAddressA,
            doutb   => iReadDataA
        );
        
    InputBufferB : dpram1024x16
        PORT MAP (
            clka    => Clock,
            wea     => iWriteEnableB,
            addra   => WriteAddress,
            dina    => WriteData,
            clkb    => Clock,
            enb     => iReadEnableAB,
            addrb   => iReadAddressB,
            doutb   => iReadDataB
        );  
        
    InputBufferC : dpram1024x16
        PORT MAP (
            clka    => Clock,
            wea     => iWriteEnableC,
            addra   => WriteAddress,
            dina    => WriteData,
            clkb    => Clock,
            enb     => iReadEnableABC,
            addrb   => iReadAddressC,
            doutb   => iReadDataC
        );  

    OutputBufferD : dpram1024x64
        PORT MAP (
            clka    => Clock,
            wea     => iWriteEnableD,
            addra   => iWriteAddressD,
            dina    => iMacResult,
            clkb    => Clock,
            enb     => ReadEnable,
            addrb   => ReadAddress,
            doutb   => ReadData
        );
    
    -- Clock Process when iReadEnableAB (buffer A and B) alligns and becomes '1' then multiply and add to result
    -- When  iReadEnableABC (buffer C) alligns and becomes '1' then add to result
    process (Clock)
    begin
        if rising_edge(Clock) then      
            if iMacReset = '1' then
                iMacResult <= (others=>'0');
            elsif iMacEnable = '1' then
                iMacResult <= std_logic_vector(signed(iReadDataA) * signed(iReadDataB) + signed(iMacResult));
            end if;
            
            if iReadEnableABC = '1' then
                iMacResult <= std_logic_vector(signed(iReadDataC) + signed(iMacResult));
            end if;
        end if;
    end process;        
    
    
    -- Read specific address alligned with counters 
    iReadAddressA <= std_logic_vector(iRowCountA(4 downto 0) & iColCountA); 
    iReadAddressB <= std_logic_vector(iColCountA & iColCountB(4 downto 0));     
    iReadAddressC <= std_logic_vector(iColCountC);
    
    
    -- Clock process to load output data into buffer D at specific address
    process (Clock)
    begin
        if rising_edge(Clock) then    
  
            iMacEnable <= iReadEnableAB;
        
            iWriteAddressD1 <= std_logic_vector(iRowCountA(4 downto 0) & iColCountB(4 downto 0));
            iWriteAddressD      <= iWriteAddressD1;
        end if;
    end process;            
    
   
    -- Clock process for counters to add up unless they are reset      
    process (Clock)
    begin
        if rising_edge (Clock) then    
            if Reset = '1' then
                presState <= stIdle;
            else
                presState <= nextState;
            end if;
            
            if iCountReset = '1' then       
                iCount <= (others=>'0');
            elsif iCountEnable = '1' then
                iCount <= iCount + 1;
            end if;

            if iRowCountAReset = '1' then       
                iRowCountA <= (others=>'0');
            elsif iRowCountAEnable = '1' then
                iRowCountA <= iRowCountA + 1;
            end if;

            if iColCountAReset = '1' then       
                iColCountA <= (others=>'0');
            elsif iColCountAEnable = '1' then
                iColCountA <= iColCountA + 1;
            end if;     

            if iColCountBReset = '1' then       
                iColCountB <= (others=>'0');
            elsif iColCountBEnable = '1' then
                iColCountB <= iColCountB + 1;
            end if;     
            
            if iColCountCReset = '1' then 
               iColCountC <= (others=>'0');
            elsif iColCountCEnable = '1' then
                iColCountC <= iColCountC + 1;
            end if;                        
        end if;
    end process;
    
    
    -- Process for Finite State Machine
    process (presState, WriteEnable, BufferSel, iCount, iRowCountA, iColCountA, iColCountB, iColCountC)
    begin
        -- signal defaults
        iCountReset <= '0';
        iCountEnable <= '1'; 
        
        iRowCountAReset <= '0';
        iRowCountAEnable <= '0';

        iColCountAReset <= '0';
        iColCountAEnable <= '0';

        iColCountBReset <= '0'; 
        iColCountBEnable <= '0';
        
        iColCountCReset <= '0'; 
        iColCountCEnable <= '0';
        
        iReadEnableAB <= '0'; 
        iReadEnableABC <= '0';
    
        iWriteEnableD(0) <= '0';        
        iMacReset <= '0';
        
        DataReady <= '0';
        
        
        case presState is
            when stIdle =>
                if (WriteEnable = '1' and BufferSel = "00") then
                    nextState <= stWriteBufferA;
                else
                    iCountReset <= '1';
                    nextState <= stIdle;
                end if;
                
            -- State stWriteBufferA, stWriteBufferB, stWriteBufferC loads data into buffers to address set by iCount
            -- Then reset all counters after all data is loaded
            when stWriteBufferA =>
                if iCount = "11" & x"FF" then
                    iCountReset <= '1';             
                    nextState <= stWriteBufferB;
                else
                    nextState <= stWriteBufferA;
                end if;
            when stWriteBufferB =>
                if iCount = "11" & x"FF" then
                    iCountReset <= '1';
                    nextState <= stWriteBufferC;
                else
                    nextState <= stWriteBufferB;
                end if;
                
            when stWriteBufferC =>
                if iCount = "11" & x"FF" then
                    iCountReset <= '1';
                    iRowCountAReset <= '1';
                    iColCountAReset <= '1';
                    iColCountBReset <= '1';
                    iColCountCReset <= '1';
                    iMacReset <= '1';
                    nextState <= stInitialiseCbuf;
                else
                    nextState <= stWriteBufferC;
                end if;
            
            -- Enable addition with buffer C 
            when stInitialiseCbuf => 
                iReadEnableABC <= '1';
                nextState <= stReadBufferAB;
                
            -- Perform reading of data at positions of two counters where it will perform multiplication at specific address 
            -- While maintaining the counter for buffer C for later addition
            when stReadBufferAB =>
                if iRowCountA = "100000" then
                    iRowCountAReset <= '1';
                    iColCountBReset <= '1';
                    iColCountAReset <= '1';
                    nextState <= stComplete;
                elsif iColCountB = "100000" then
                    iRowCountAEnable <= '1';
                    iColCountBReset <= '1';
                    iColCountAReset <= '1';
                    nextState <= stReadBufferAB;
                elsif iColCountC = "11" & x"FF" then  
                    iColCountCReset <= '1';
                    nextState <= stReadBufferAB;
                elsif iColCountA = "11111" then
                    iReadEnableAB <= '1';
                    iColCountAReset <= '1';
                    nextState <= stWaitWriteBufferD;
                else
                    iReadEnableAB <= '1';
                    iColCountAEnable <= '1';
                    nextState <= stReadBufferAB;
                end if;
            
            -- Enable counters of columns for B and counter for C 
            when stWaitWriteBufferD =>
                iColCountBEnable <= '1';
                iColCountCEnable <= '1';
                nextState <= stReadBufferABC;
                
            -- Enable addition with buffer C 
            when stReadBufferABC => 
                iReadEnableABC <= '1';
                nextState <= stWriteBufferD;
                
            -- Write data into buffer D 
            when stWriteBufferD =>
                iWriteEnableD(0) <= '1';
                iMacReset <= '1';
                nextState <= stReadBufferAB;
                
            -- Complete and stay Idle 
            when stComplete =>
                DataReady <= '1';
                nextState <= stIdle;            
        end case;
    end process;
    
end mainproject_arch;

