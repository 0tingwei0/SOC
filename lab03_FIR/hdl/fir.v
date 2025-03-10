
module fir
    #(  parameter pADDR_WIDTH = 12,
        parameter pDATA_WIDTH = 32
     )
     (
        //AXI4-Lite
			//write channel
         output  reg                      awready,  
         output  reg                      wready,   
         input   wire                     awvalid,  
         input   wire [(pADDR_WIDTH-1):0] awaddr,   
         input   wire                     wvalid,   
         input   wire [(pDATA_WIDTH-1):0] wdata,    
			//read channel
         output  reg                      arready,  
         input   wire                     rready,   
         input   wire                     arvalid,  
         input   wire [(pADDR_WIDTH-1):0] araddr,   
         output  reg                      rvalid,   
         output  wire [(pDATA_WIDTH-1):0] rdata,    

        //AXI4-Stream
			//for x input
         input   wire                     ss_tvalid,
         input   wire [(pDATA_WIDTH-1):0] ss_tdata,
         input   wire                     ss_tlast,
         output  reg                      ss_tready,

			//for y output
         input   wire                     sm_tready,
         output  reg                      sm_tvalid,
         output  reg [(pDATA_WIDTH-1):0]  sm_tdata,
         output  reg                      sm_tlast,

         //bram for tap RAM
         output  reg [3:0]                tap_WE,
         output  reg                      tap_EN,
         output  reg [(pDATA_WIDTH-1):0]  tap_Di,
         output  reg [(pADDR_WIDTH-1):0]  tap_A,
         input   wire [(pDATA_WIDTH-1):0] tap_Do,

         //bram for data RAM
         output  reg [3:0]                data_WE,
         output  reg                      data_EN,
         output  reg  [(pDATA_WIDTH-1):0] data_Di,
         output  reg  [(pADDR_WIDTH-1):0] data_A,
         input   wire [(pDATA_WIDTH-1):0] data_Do,

         input   wire                     axis_clk,
         input   wire                     axis_rst_n
     );

    reg [31:0] ap_ctrl;
    reg ap_idle, ap_done, ap_start;// 0x00: ap_idle, ap_done, ap_start

    reg is_writing;   
    reg is_reading;

	reg awready_tmp;
	reg wready_tmp;
	reg arready_tmp;
	reg rvalid_tmp; 

    reg [1:0] state, next_state;

    //FSM_state_number
    localparam IDLE = 2'b00;
    localparam COMPUTUNG  = 2'b01;
    localparam DONE = 2'b10;

    reg  [31:0] data_length;
    wire [31:0] data_length_reg; 
    reg  [31:0] num_of_tap;
    wire [31:0] num_of_tap_reg;
    
    reg [(pADDR_WIDTH-1):0] tap_A_tmp;
    reg [4:0] tap_cnt;

    wire ss_tready_tmp;

    reg  [4:0] data_cnt;
    reg  [4:0] data_cnt_tmp;

    reg  [4:0] data_ptr;
    reg [4:0] data_ptr_tmp;

    wire [(pDATA_WIDTH-1):0] sm_tdata_tmp;
    wire sm_tvalid_tmp;
    
    always @(*) is_writing = (awvalid && wvalid) && (awready && wready);
    always @(*) is_reading = (arvalid && rvalid) && (rready && arready);


    // axi-lite 
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n) begin
            awready_tmp <= 1'b0;
            wready_tmp  <= 1'b0;
            arready_tmp <= 1'b0;
            rvalid_tmp  <= 1'b0;
        end else begin
            awready_tmp <= ({awvalid,awready} == 2'b10) ? 1 :
                                                            ({awvalid,awready} == 2'b11)? 0 : arready;   
            wready_tmp  <= ({wvalid,wready} == 2'b10) ? 1 :
                                                            ({wvalid,wready} == 2'b11)? 0 : arready;      
            arready_tmp <= ({arvalid,arready} == 2'b10) ? 1 :
                                                            ({arvalid,arready} == 2'b11)? 0 : arready;     
            rvalid_tmp  <= (arvalid && arready) ? 1 : 0;      
        end
    end

	always@(*)	awready = awready_tmp;		
	always@(*)  wready  = wready_tmp;	
	always@(*)  arready = arready_tmp;
	always@(*)  rvalid  = rvalid_tmp;   
        
    assign rdata   = (araddr[7:0] == 8'h00)? ap_ctrl : tap_Do; // if read 0x00, ap_ctrl  

    // FSM for fir operation
    // FSM_cs
    always@(posedge axis_clk or negedge axis_rst_n) begin
        if(!axis_rst_n) state <= IDLE;
        else            state <= next_state;
    end

    //FSM for FIR stage 
    always@* begin
        case(state)
            IDLE : next_state = (ap_start)? COMPUTUNG  : IDLE ;       
            COMPUTUNG  : next_state = (sm_tvalid && sm_tlast && ss_tlast)? DONE : COMPUTUNG ;// transfer last data of y and recieve last x   
            DONE : next_state = (araddr == 12'h000 && is_reading)? IDLE : DONE;// read 0x00 
            default : next_state = IDLE;
        endcase
    end
   //0x00 : ap_reg
    always @(*)
        {ap_ctrl[2], ap_ctrl[1], ap_ctrl[0]} = {ap_idle, ap_done, ap_start};
    
    always @(*) begin
        ap_ctrl[31:3] = 29'b0;
        ap_idle = (state == IDLE) ? 1'b1 : 
                     (state == DONE) ? 1'b1 : 1'b0;
        ap_done = (state == DONE) ? 1'b1 : 1'b0;
        ap_start = (is_writing && awaddr == 12'h000 && wdata [0] == 1'b1) ? 1'b1 : 1'b0;
    end

    //0x10-14: data_length
    //0x14-18: num_of_tap 
    assign data_length_reg = (awaddr == 12'h0_10 && is_writing) ? wdata : data_length;
    assign num_of_tap_reg     = (awaddr == 12'h0_14 && is_writing) ? wdata : num_of_tap;

    always@ (posedge axis_clk or negedge axis_rst_n) begin
        if(!axis_rst_n) begin
            data_length <= 32'd0;
            num_of_tap     <= 32'd0;
        end else begin
            data_length <= data_length_reg;
            num_of_tap     <= num_of_tap_reg;
        end
    end

//tap RAM
    //tap RAM counter
    always@(posedge axis_clk or negedge axis_rst_n) begin
        if(!axis_rst_n)         tap_cnt <= num_of_tap;       
        else if(state == COMPUTUNG )  tap_cnt <= (tap_cnt + 1 < num_of_tap) ? tap_cnt + 1 : 0;           
        else                    tap_cnt <= num_of_tap;     
    end

    reg address_in_tapRAM;
    always@*
        address_in_tapRAM = (awaddr[11:0] >= 12'h080 && awaddr[11:0] <= 12'h0FF);
    //tap RAM(R/W) 
    always@* begin
        if (address_in_tapRAM && ((awvalid && wvalid)))    tap_A_tmp = awaddr[6:0];          
        else if (address_in_tapRAM && (arvalid && rready)) tap_A_tmp = araddr[6:0];        
        else                                               tap_A_tmp = 12'hFFF;
    end

    // tapRAM signal
    always@* begin
        tap_EN = 1'b1;
        tap_WE = ((is_writing) && (address_in_tapRAM)) ? 4'b1111 : 4'b0000;
        tap_Di = (awvalid && wvalid) ? wdata : 12'h000;
        tap_A = (state == COMPUTUNG ) ? 4 * tap_cnt : tap_A_tmp;
    end

//axi-stream for x input
    assign ss_tready_tmp = (state == COMPUTUNG ) && ss_tvalid && (tap_cnt == num_of_tap - 1);

    always@(posedge axis_clk or negedge axis_rst_n) begin
        if(!axis_rst_n) ss_tready <= 1'b0;
        else            ss_tready <= ss_tready_tmp & (~ss_tready);//for glith free
    end    

//data RAM
    //data counter
    always@(*)begin
        if (tap_cnt == num_of_tap - 1) data_cnt_tmp = (data_cnt == num_of_tap - 1) ? 0 : (data_cnt + 1);   
        else                        data_cnt_tmp = data_cnt; 
    end

    always@ (posedge axis_clk or negedge axis_rst_n) begin
        if(!axis_rst_n)  data_cnt <= num_of_tap - 1;     
        else data_cnt <= (state == IDLE) ? num_of_tap - 1 : data_cnt_tmp;      
    end

    //for reading  x_data (data pointter)
    always@(*)begin
        if(tap_cnt == num_of_tap - 1) data_ptr_tmp = data_cnt + 1;      
        else  data_ptr_tmp = (data_ptr == 0) ? (num_of_tap - 1) : (data_ptr - 1);       
    end

    always@ (posedge axis_clk or negedge axis_rst_n) begin
        if(!axis_rst_n)     data_ptr <= num_of_tap - 1;            
        else if(ap_start)   data_ptr <= 0;       
        else                data_ptr <= data_ptr_tmp;      
    end

    // dataRAM signal 
    always@* begin
        data_EN = 1'b1;
        data_WE = (state == COMPUTUNG  && ss_tvalid && ss_tready || state == IDLE) ? 4'b1111 : 4'b0000; 
        data_Di = (state == COMPUTUNG  && ss_tvalid && ss_tready) ? ss_tdata : 32'h000;
        data_A =  (ss_tvalid && ss_tready) ? 4 * data_cnt : 4 * data_ptr;
    end

//convolution
    wire [(pDATA_WIDTH-1):0] x_in;
    wire [(pDATA_WIDTH-1):0] h;
    reg  [(pDATA_WIDTH-1):0] y_out;

    assign x_in = data_Do;
    assign h = tap_Do;

    always@ (posedge axis_clk or negedge axis_rst_n) begin
        if(!axis_rst_n)             y_out <= 0;        
        else if(state == IDLE)      y_out <= 0;  
        else                        y_out <= (tap_cnt == 1) ? (x_in * h) : y_out + (x_in * h);  
    end
    
    //axi-stream
    //y_out conter 
    reg  [8:0] y_cnt;
    wire [8:0] y_cnt_tmp;
    
    assign y_cnt_tmp = y_cnt;
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if(!axis_rst_n)          y_cnt <= 0;  
        else if(state == IDLE)   y_cnt <= 0;       
        else y_cnt <= (tap_cnt == 1) ? y_cnt_tmp + 1 : y_cnt_tmp;  
    end

    //axi-stream : sm
    assign sm_tdata_tmp = (sm_tready && ((tap_cnt == 9'd1) && (y_cnt > 9'd1))) ? y_out : 32'h000;
    assign sm_tvalid_tmp = (sm_tready && ((tap_cnt == 9'd1) && (y_cnt > 9'd1))) ? 1'b1 : 1'b0;  

    always@(posedge axis_clk or negedge axis_rst_n) begin
        if(!axis_rst_n) begin
            sm_tdata <= 32'h0000_0000;
            sm_tvalid <= 1'b0;
        end else if(state == IDLE) begin
            sm_tdata <= 32'h0000_0000;
            sm_tvalid <= 1'b0;
        end else begin
            sm_tdata  <= sm_tdata_tmp;
            sm_tvalid <= sm_tvalid_tmp;
        end
    end    

    //tlast: for y output transfer
    wire   sm_tlast_tmp;
    assign sm_tlast_tmp = (y_cnt == data_length + 1) ? 1'b1 : 1'b0;

    always@(posedge axis_clk or negedge axis_rst_n) begin
        if(!axis_rst_n) sm_tlast <= 1'b0;
        else            sm_tlast <= (state == IDLE) ? 1'b0 : sm_tlast_tmp;
    end

endmodule
