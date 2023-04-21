`timescale 1ns / 1ps
module lfsr_tb;

 // Inputs
 reg clock;
 reg reset;

 // Outputs
 wire [12:0] rnd;
 wire [12:0] random;
 wire [12:0] random_next;

 // Instantiate the Unit Under Test (UUT)
 LFSR uut (
  .clock(clock), 
  .reset(reset), 
  .rnd(rnd), .random(random), .random_next(random_next)
 );
 
 initial begin
  clock = 0;
  forever
   #50 clock = ~clock;
  end
  
 initial begin
  // Initialize Inputs
  
  reset = 0;

  // Wait 100 ns for global reset to finish
  #100;
      reset = 1;
  #200;
  reset = 0;
  // Add stimulus here

 end
 
 initial begin
 $display("clock rnd");
 $monitor("%b,%b", clock, rnd);
 end      
endmodule