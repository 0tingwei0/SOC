// set the timescale for the simulation
 `timescale 1ns/1ps 
module testbench;  // module of testbench
//  parameter defined
parameter CYCLE = 10; // use CYCLE to describe the clock period
parameter LARGE_NUMBER  = 1000;// max cycle time=>timeout

// localparam
localparam DATA_WIDTH= 16;
localparam N=9;


// input signal use reg
reg clk;
reg rst_n;
reg  [DATA_WIDTH-1:0] A;
reg  [DATA_WIDTH-1:0] B;

// output signal use wire
wire  [DATA_WIDTH-1:0] Y;

// interger 
integer i, j, error;
///// instantiate  module /////
// instantiate the module you finished in following format //
// module_name #(.parameter1(5),.parameter2(3)) unit_name (.port1(...), .port2(...), ...); //
adder adder(
.clk(clk),
.rst_n(rst_n),
.A0(A),
.A1(B),
.Y(Y)
);

//  dump the waveform of the simulation for fsdb//
/*initial begin
 $fsdbDumpfile("testbench.fsdb"); 
 $fsdbDumpvars;              
end*/

// dump the waveform of the simulation for vcd//
initial begin
  $dumpfile("testbench.vcd");
  $dumpvars("+mda");
end

// there you can read data from the file,and store in the register.
reg [55:0] golden [0:N];
initial begin
  $readmemh("golden.dat",golden);
end



// generate clk 
always #(CYCLE/2) clk = ~clk; 

// System block set only clock,reset signal and the timeout finish. 
initial begin
  clk = 1;
  rst_n = 1;
  // system reset
  #(CYCLE) rst_n = 0;
  #(CYCLE) rst_n = 1;

  #(CYCLE*LARGE_NUMBER) $finish;
end

// input signal setting, pattern feeding and set control signal blcok.

initial begin
  // 1. set the initial state of the testing signal
  // 2. you can use wait or @(negedge clk), to control when to feed your pattern
  // ex: wait(rst_n==1) do something.../ @(negedge clk) do something...
  // 3. you can use for or while loop to generate all possible inputs to verify your answer
  // ex: for(i=0;i<50;i=i+1)begin   // no i++ in verilog
  // 4. the input data can from external file, or you can generate the pattern in the testbench
  A = 0;
  B = 0;
  wait(rst_n==0);
  wait(rst_n==1);

  for(i=0; i<N; i=i+1) begin
    @(negedge clk)A=golden[i][47:32]; B=golden[i][31:16];
  end
end

// output result checking block, control when to sample and verify the result.
integer  fp_w;
initial begin
// error count
  error = 0;
// Use the same control technique to control when to sample output result.
  wait(rst_n==0);
  wait(rst_n==1);
// adder output for two cycle from input to output
  #(CYCLE*2);
  // you can also write the result to a text file
  fp_w = $fopen("answer.txt");
  for(j=0; j<N; j=j+1) begin
    @(negedge clk);
    if(Y!==golden[j][15:0])begin
      error = error + 1;
      // print the text on the termial by display.
      $display("************* Pattern No.%d is wrong at %t ************", j,$time);
      $display("A = %b, B = %b,",golden[j][47:32],golden[j][31:16]);  
      $display("golden = %b, but your answer is %b QQ Orz ",golden[j][15:0], Y);  
      //$finish;
    end
    // write the text in .txt by fdisplay.
    $fdisplay(fp_w, "%h_%h_%h",golden[j][47:32],golden[j][31:16],Y);
  end
  $fclose(fp_w); 
  // check the error count
  if(error==0) begin
    $display("Congratulations!! The functionality of your adder is correct!!");
  end
  else begin
    $display("error !!");
  end 
  #(CYCLE) $finish;
end

endmodule
