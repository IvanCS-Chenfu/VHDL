----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 19.10.2020 12:14:30
-- Design Name: 
-- Module Name: Test_Bench - Comportamiento
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use STD.textIO.ALL;				-- Se va a hacer uso de ficheros.

use work.Tipos_FSM_PLC.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Test_Bench is
--  Port ( );
end Test_Bench;

architecture Comportamiento of Test_Bench is

component FSM_PLC is
     generic( k    : natural := 32;    -- k entradas.
             p    : natural := 32;    -- p salidas.
             m    : natural := 32;    -- m biestables. (Hasta 16 estados)
             T_DM : time    := 10 ps; -- Tiempo de retardo desde el cambio de dirección del MUX hasta la actualización de la salida Q.
             T_D  : time    := 10 ps; -- Tiempo de retardo desde el flanco activo del reloj hasta la actualización de la salida Q.
             T_SU : time    := 10 ps; -- Tiempo de Setup.
             T_H  : time    := 10 ps; -- Tiempo de Hold.
             T_W  : time    := 10 ps); -- Anchura de pulso.
     port   (   x : in  STD_LOGIC_VECTOR( k - 1 downto 0 );     -- x es el bus de entrada.
                y : out STD_LOGIC_VECTOR( p - 1 downto 0 );     -- y es el bus de salida.
              Tabla_De_Estado : in Tabla_FSM( 0 to 2**m - 1 );  -- Contiene la Tabla de Estado estilo Moore: Z(n+1)=T1(Z(n),x(n))
              Tabla_De_Salida : in Tabla_FSM( 0 to 2**m - 1 );  -- Contiene la Tabla de Salida estilo Moore: Y(n  )=T2(Z(n))
              clk     : in STD_LOGIC;   -- La señal de reloj.
              cke     : in STD_LOGIC;   -- La señal de habilitación de avance: si vale '1' el autómata avanza a ritmo de clk y si vale '0' manda Trigger.              
              reset   : in STD_LOGIC;   -- La señal de inicialización.
              Trigger : in STD_LOGIC ); -- La señal de disparo (single shot) asíncrono y posíblemente con rebotes para hacer un avance único. Ha de llevar un sincronizador.
end Component FSM_PLC;

constant k_max : NATURAL := 3;
constant p_max : NATURAL := 4;
constant m_max : NATURAL := 4;

constant SEMI_PERIODO : Time := 10ns;
constant PERIODO : Time := 2*SEMI_PERIODO;
constant PERIODO_3 : Time := 3*PERIODO;

signal x : STD_LOGIC_VECTOR( k_max - 1 downto 0 );
signal Y : STD_LOGIC_VECTOR( p_max - 1 downto 0 );
signal clk,cke,reset,Trigger : STD_LOGIC := 'U';


signal Tabla_De_Estado : Tabla_FSM( 0 to 2**m_max - 1 ) := (    
    b"0000_0000_0001_0000_0000_0000_0001_0000",
    b"0010_0000_0001_0010_0010_0000_0001_0010",
    b"0010_0011_0010_0010_0010_0011_0010_0010",
    b"0000_0011_0010_0000_0000_0011_0010_0000",
    
    (others => '0'),
    (others => '0'),
    (others => '0'),
    (others => '0'),
    
    (others => '0'),
    (others => '0'),
    (others => '0'),
    (others => '0'),
    
    (others => '0'),
    (others => '0'),
    (others => '0'),
    (others => '0')
);


signal Tabla_De_Salida : Tabla_FSM( 0 to 2**m_max - 1 ) := (
    b"0000_0000_0000_0000_0000_0000_0000_0000",
    b"0001_0000_0000_0001_0001_0000_0000_0001",
    b"0001_0001_0001_0001_0001_0001_0001_0001",
    b"0000_0001_0001_0000_0000_0001_0001_0000",
     
    (others => '0'),
    (others => '0'),
    (others => '0'),
    (others => '0'),
    
    (others => '0'),
    (others => '0'),
    (others => '0'),
    (others => '0'),
    
    (others => '0'),
    (others => '0'),
    (others => '0'),
    (others => '0')
    );


begin

CLOCK : process
    begin
        clk <= '0';
        wait for SEMI_PERIODO;
        clk <= '1';
        wait for SEMI_PERIODO;
end process CLOCK;

CLOCK_E : process
    begin
        cke <= '0';
        wait;
end process CLOCK_E;

RESETEAR : process
    begin
        reset <= '0';
        wait for 4*20*PERIODO;
        reset <= '1';
        wait for PERIODO;
        reset <= '0';
        wait;
end process RESETEAR;

TRIGG : process
    begin
        for i in 0 to 22 loop
            Trigger <= '1';
            wait for PERIODO_3;
            Trigger <= '0';
            wait for PERIODO;
        end loop;
        
        Trigger <= '1';
        wait for PERIODO;
        Trigger <= '0';
        wait for PERIODO;
end process TRIGG;

DUT : FSM_PLC generic map(k => k_max, p => p_max, m => m_max)
            port map(x => x,y => y,Tabla_De_Estado => Tabla_De_Estado,Tabla_De_Salida => Tabla_De_Salida,clk => clk,cke => cke,reset => reset,Trigger => Trigger);

Estimulos_Desde_Fichero : process

    file  Input_File : text;
    file Output_File : text;
    
    variable     Input_Data : BIT_VECTOR( k_max-1 downto 0 ) := ( OTHERS => '0' );
    variable          Delay :      time := 0 ms;
    variable     Input_Line :      line := NULL;
    variable    Output_Line :      line := NULL;
    variable   Std_Out_Line :      line := NULL;
    variable       Correcto :   Boolean := True;
    constant           Coma : character := ',';

    
    begin
    
-- Semisumador_Estimulos.txt contiene los estímulos y los tiempos de retardo para el semisumador.
        file_open(  Input_File, "C:\Users\Chenfu\Desktop\Estimulos.txt", read_mode );
-- Semisumador_Estimulos.csv contiene los estímulos y los tiempos de retardo para el Analog Discovery 2.
        file_open( Output_File, "C:\Users\Chenfu\Desktop\Estimulos.csv", write_mode );
        
-- Titles: Son para el formato EXCEL *.CSV (Comma Separated Values):
        write( Std_Out_Line, string'(  "Retardo" ), right, 7 );
        write( Std_Out_Line,                  Coma, right, 1 );
        write( Std_Out_Line, string'( "Entradas" ), right, 8 );
                
        Output_Line := Std_Out_Line;
               
        writeline(      output, Std_Out_Line );
        writeline( Output_File,  Output_Line );

        while ( not endfile( Input_File ) ) loop    
        
            readline( Input_File, Input_Line );
            
            read( Input_Line, Delay, Correcto );	-- Comprobación de que se trata de un texto que representa
													-- el retardo, si no es así leemos la siguiente línea.           
            if Correcto then

                read( Input_Line, Input_Data );		-- El siguiente campo es el vector de pruebas.
                x <= TO_STDLOGICVECTOR( Input_Data )( k_max-1 downto 0 ); 
													-- De forma simultánea lo volcaremos en consola en csv.
                write( Std_Out_Line,        Delay, right, 5 ); -- Longitud del retardo, ej. "20 ms".
                write( Std_Out_Line,         Coma, right, 1 );
                write( Std_Out_Line,   Input_Data, right, 2 ); --Longitud de los datos de entrada.
                
                Output_Line := Std_Out_Line;
                
                writeline(      output, Std_Out_Line );
                writeline( Output_File, Output_Line );
        
                wait for Delay;
            end if;
         end loop;
         
         file_close(  Input_File );	-- Cerramos el fichero de entrada.
         file_close( Output_File );	-- Cerramos el fichero de salida.
         wait;		 
    end process Estimulos_Desde_Fichero;


end Comportamiento;
