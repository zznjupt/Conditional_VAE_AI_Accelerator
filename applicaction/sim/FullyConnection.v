module FullyConnection #(
    parameter ADDR_WIDTH  = 16,
    parameter DATA_WIDTH  = 32
)(
    input wire clk,
    input wire rst,
    
    input wire start,
    output reg finish,

    input wire [7:0] FC_IN,
    input wire [7:0] FC_OUT,
    // input sram, read-only
    output reg signed [ADDR_WIDTH-1:0] sram_input_addr,
    input wire signed [DATA_WIDTH-1:0] sram_input_rdata,
    
    // weight sram, read-only
    output reg [ADDR_WIDTH-1:0] sram_weight_addr,
    input wire signed [DATA_WIDTH-1:0] sram_weight_rdata,

    // bias sram, read-only
    output reg [ADDR_WIDTH-1:0] sram_bias_addr,
    input wire signed [DATA_WIDTH-1:0] sram_bias_rdata,

    // output sram, write-only
    output reg sram_output_wea, // set to 1 if want to write data
    output reg [ADDR_WIDTH-1:0] sram_output_addr,
    output reg  signed [DATA_WIDTH-1:0] sram_output_wdata
);

reg signed [ADDR_WIDTH-1:0] sram_input_addr_next;
reg [ADDR_WIDTH-1:0] sram_weight_addr_next;
reg [ADDR_WIDTH-1:0] sram_bias_addr_next;
reg sram_output_wea_next;
reg [ADDR_WIDTH-1:0] sram_output_addr_next;
reg  signed [DATA_WIDTH-1:0] sram_output_wdata_next;

reg [ADDR_WIDTH-1:0] fc_addr_in,fc_addr_out;
reg [ADDR_WIDTH-1:0] fc_addr_in_next,fc_addr_out_next;
reg comput_done;
//reg [ADDR_WIDTH-1:0] cnt_sram_input_addr;
reg [ADDR_WIDTH-1:0] cnt_sram_bias_addr;
reg [1:0] data_cycle, data_cycle_next;
reg [ADDR_WIDTH-1:0] fc_data_in,fc_data_out;
reg [ADDR_WIDTH-1:0] fc_data_in_next,fc_data_out_next;
localparam QUAN_HALF = 12;

localparam  FSM_INITIAL = 2'd0,
            FSM_COMPUTE = 2'd1,
            FSM_FINISH  = 2'd2;
reg [1:0] state, state_next;
reg finish_next;

always @(posedge clk) begin
    if(rst)
        state <= FSM_INITIAL;
    else
        state <= state_next;
end

always @(*) begin
    case(state)
        FSM_INITIAL:
            state_next = (start == 1 ? FSM_COMPUTE : state);
        FSM_COMPUTE:
            state_next = (comput_done == 1 ? FSM_FINISH : state);
        FSM_FINISH:
            state_next = FSM_INITIAL;
        default:
            state_next = FSM_INITIAL;
    endcase
end

always @(posedge clk) begin
    if(rst)
        finish <= 0;
    else
        finish <= finish_next;
end

always @(*) begin
    if(state == FSM_FINISH)
        finish_next = 1;
    else
        finish_next = 0;
end

//=====count FC addr input output reg=====//

always @(posedge clk) begin
    if (rst)
        fc_addr_out <= 0;
    else
        fc_addr_out <= fc_addr_out_next;
end


always @(*) begin
    
    if (state == FSM_COMPUTE) begin
        if (fc_addr_out == FC_OUT - 1 && fc_addr_in == FC_IN - 1) 
            fc_addr_out_next = 0;
        else  if (fc_addr_in == FC_IN - 1) 
            fc_addr_out_next = fc_addr_out + 1;
        else 
            fc_addr_out_next = fc_addr_out;
    end
    else begin
        fc_addr_out_next = 0;
    end
end


always @(posedge clk) begin
    if (rst)
        fc_addr_in <= 0;
    else
        fc_addr_in <= fc_addr_in_next;
end
always @(*) begin
    
    if (state == FSM_COMPUTE) begin
        if (fc_addr_out == FC_OUT - 1 && fc_addr_in == FC_IN - 1) 
            fc_addr_in_next = 0;
        else  if (fc_addr_in == FC_IN - 1) 
            fc_addr_in_next = 0;
        else 
            fc_addr_in_next = fc_addr_in + 1;
    end
    else begin
        fc_addr_in_next = 0;
    end
end


//=====count addr to data delay=====//
always @(posedge clk) begin
    if (rst) 
        data_cycle <= 0;
    else
        data_cycle <= data_cycle_next;
end 

always @(*) begin
    if (state == FSM_COMPUTE)begin
        if (data_cycle == 3) 
            data_cycle_next = 3;
        else
            data_cycle_next = data_cycle + 1;
    end
    else begin
        data_cycle_next = 0;
    end
end 

//=====count FC data input output reg=====//  

always @(posedge clk) begin
    if (rst)
        fc_data_out <= 0;
    else
        fc_data_out <= fc_data_out_next;
end

always @(*) begin
    
    if (state == FSM_COMPUTE) begin
        if (data_cycle == 3) begin
            if (fc_data_out == FC_OUT - 1 && fc_data_in == FC_IN - 1)
                fc_data_out_next = 0;
            else  if (fc_data_in == FC_IN - 1) 
                fc_data_out_next = fc_data_out + 1;
            else 
                fc_data_out_next = fc_data_out;
        end
        else 
            fc_data_out_next = fc_data_out;
    end
    else begin
        fc_data_out_next = 0;
    end
end

always @(posedge clk) begin
    if (rst)
        fc_data_in <= 0;
    else
        fc_data_in <= fc_data_in_next;
end

always @(*) begin
    
    if (state == FSM_COMPUTE) begin
        if (data_cycle == 3) begin
            if (fc_data_out == FC_OUT - 1 && fc_data_in == FC_IN - 1)
                fc_data_in_next = 0;
            else  if (fc_data_in == FC_IN - 1) 
                fc_data_in_next = 0;
            else 
                fc_data_in_next = fc_data_in + 1;
        end
        else begin
            fc_data_in_next = fc_data_in;
        end
    end
    else begin
        fc_data_in_next = 0;
    end
end

//=====count sram input addr=====//

always @(posedge clk) begin
    if (rst)
        sram_input_addr <= 0;
    else
        sram_input_addr <= sram_input_addr_next;
end

always @(*) begin
    if (state == FSM_COMPUTE) begin
        if (data_cycle >= 2) begin
            if (sram_input_addr == FC_IN - 1) 
                sram_input_addr_next = 0;
            else 
                sram_input_addr_next = sram_input_addr + 1;
        end
        else begin
            sram_input_addr_next = sram_input_addr;
        end
    end
    else begin
        sram_input_addr_next = 0;
    end
end


//=====count weight addr=====//
always @(*) begin
    if (state == FSM_COMPUTE)
        sram_weight_addr = fc_addr_out*FC_IN + fc_addr_in;
    else
        sram_weight_addr = 0;
end

//=====give bias addr=====//
always @(*) begin
    if (state == FSM_COMPUTE && fc_data_in == FC_IN - 4) 
        sram_bias_addr = fc_data_out;
    else 
        sram_bias_addr = 0;
end

//=====fc computation=====//
reg signed [DATA_WIDTH-1:0] comput_buffer,comput_buffer_n;
reg signed [DATA_WIDTH-1:0] output_ans;
//reg signed [DATA_WIDTH-1:0] source,weight;
reg signed [63:0] partial_sum;
reg signed [DATA_WIDTH-1:0] sum;
always @(posedge clk) begin
    if (rst) 
        comput_buffer <= 0;
    else if (fc_data_in == FC_IN - 1)
        comput_buffer <= 0;
    else
        comput_buffer <= comput_buffer_n;
end

always @(*) begin
    comput_buffer_n = 0;
    partial_sum = 0;
    sum = 0;
    //output_ans = 0;
    if (data_cycle == 3) begin
        partial_sum = sram_input_rdata * sram_weight_rdata;
        sum = partial_sum[24+:32];
        comput_buffer_n = comput_buffer + sum;
    
    end
end

always @(*) begin
    
    output_ans = comput_buffer_n + sram_bias_rdata;
end

//=====write enable=====//
always @(posedge clk) begin
    if(rst)
        sram_output_wea <= 0;
    else
        sram_output_wea <= sram_output_wea_next;
end
always @(*) begin
    if (fc_data_in == FC_IN - 1)
        sram_output_wea_next = 1;
    else
        sram_output_wea_next = 0;
end

//=====write output addr=====//
always @(posedge clk) begin
    if(rst)
        sram_output_addr <= 0;
    else
        sram_output_addr <= sram_output_addr_next;
end
always @(*) begin
    if (fc_data_in == FC_IN - 1)
        sram_output_addr_next = fc_data_out;
    else
        sram_output_addr_next = 0;
end

//=====write output data=====//
always @(posedge clk) begin
    if(rst)
        sram_output_wdata <= 0;
    else
        sram_output_wdata <= sram_output_wdata_next;
end
always @(*) begin
    if (fc_data_in == FC_IN - 1)
        sram_output_wdata_next = output_ans;
    else
        sram_output_wdata_next = 0;
end

//=====write all output data done=====//
always @(*) begin
    if (fc_data_out == FC_OUT - 1 && fc_data_in == FC_IN - 1)
        comput_done = 1;
    else
        comput_done = 0;
end

endmodule
