module fully_connection # (
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32
)(
    input  wire                             clk,
    input  wire                             rst,
    input  wire                             start,
    output reg                              finish,

    input  wire [7:0]                       fc_in,
    input  wire [7:0]                       fc_out,
    // input sram, read-only
    output reg  signed [ADDR_WIDTH-1:0]     sram_input_addr,
    input  wire signed [DATA_WIDTH-1:0]     sram_input_rdata,
    // weight sram, read-only
    output reg         [ADDR_WIDTH-1:0]     sram_weight_addr,
    input  wire signed [DATA_WIDTH-1:0]     sram_weight_rdata,
    // bias sram, read-only
    output reg         [ADDR_WIDTH-1:0]     sram_bias_addr,
    input  wire signed [DATA_WIDTH-1:0]     sram_bias_rdata,
    // output sram, write-only
    output reg                              sram_output_wea,
    output reg         [ADDR_WIDTH-1:0]     sram_output_addr,
    output reg  signed [DATA_WIDTH-1:0]     sram_output_wdata
);

localparam  QUAN_HALF   = 12;
localparam  FSM_INIT    = 2'b00;
localparam  FSM_COMPUTE = 2'b01;
localparam  FSM_FINISH  = 2'b10;

reg         [1:0] state;
reg         [1:0] state_next;
reg               finish_next;

reg  signed [ADDR_WIDTH-1:0] sram_input_addr_r;
reg         [ADDR_WIDTH-1:0] sram_weight_addr_r;
reg         [ADDR_WIDTH-1:0] sram_bias_addr_r;
reg                          sram_output_wea_r;
reg         [ADDR_WIDTH-1:0] sram_output_addr_r;
reg  signed [DATA_WIDTH-1:0] sram_output_wdata_r;

reg         [ADDR_WIDTH-1:0] fc_addr_in;
reg         [ADDR_WIDTH-1:0] fc_addr_out;
reg         [ADDR_WIDTH-1:0] fc_addr_in_r;
reg         [ADDR_WIDTH-1:0] fc_addr_out_r;
reg                          compute_done;
// reg         [ADDR_WIDTH-1:0] cnt_sram_input_addr;
reg         [ADDR_WIDTH-1:0] cnt_sram_bias_addr;
reg         [1:0]            data_cycle;
reg         [1:0]            data_cycle_r;
reg         [ADDR_WIDTH-1:0] fc_data_in;
reg         [ADDR_WIDTH-1:0] fc_data_out;
reg         [ADDR_WIDTH-1:0] fc_data_in_r;
reg         [ADDR_WIDTH-1:0] fc_data_out_r;

always @(posedge clk) begin
    if(rst)
        state <= FSM_INIT;
    else
        state <= state_next;
end

always @(*) begin
    case(state)
        FSM_INIT:       state_next = start ?        FSM_COMPUTE : state;
        FSM_COMPUTE:    state_next = compute_done ? FSM_FINISH  : state;
        FSM_FINISH:     state_next = FSM_INIT;
        default:        state_next = FSM_INIT;
    endcase
end

always @(posedge clk) begin
    if(rst)
        finish <= 0;
    else
        finish <= finish_next;
end

always @(*) begin
    if(state == FSM_INIT)
        finish_next = 1;
    else
        finish_next = 0;
end

// count fully_connection addr input output reg

always @(posedge clk) begin
    if(rst)
        fc_addr_out <= 0;
    else
        fc_addr_out <= fc_addr_out_r;
end

always @(*) begin
    if(state == FSM_COMPUTE) begin
        if(fc_addr_out == fc_out-1 && fc_addr_in == fc_in-1)
            fc_addr_out_r = 0;
        else if(fc_addr_in == fc_in-1)
            fc_addr_out_r = fc_addr_out + 1;
        else
            fc_addr_out_r = fc_addr_out;
    end else begin
        fc_addr_out_r = 0;
    end
end

always @(posedge clk) begin
    if(rst)
        fc_addr_in <= 0;
    else
        fc_addr_in <= fc_addr_in_r;
end

always @(*) begin
    if(state == FSM_COMPUTE) begin
        if(fc_addr_out == fc_out-1 && fc_addr_in == fc_in-1)
            fc_addr_in_r = 0;
        else if(fc_addr_in == fc_in-1)
            fc_addr_in_r = 0;
        else
            fc_addr_in_r = fc_addr_in + 1;
    end else begin
        fc_addr_in_r = 0;
    end
end

// count addr to data delay

always @(posedge clk) begin
    if(rst)
        data_cycle <= 0;
    else
        data_cycle <= data_cycle_r;
end

always @(*) begin
    if(state == FSM_COMPUTE) begin
        if(data_cycle == 3)
            data_cycle_r = 3;
        else
            data_cycle_r = data_cycle + 1;
    end else begin
        data_cycle_r = 0;
    end
end 

// count fully_connection data input output reg

always @(posedge clk) begin
    if(rst)
        fc_data_out <= 0;
    else
        fc_data_out <= fc_data_out_r;
end

always @(*) begin
    if(state == FSM_COMPUTE) begin
        if(data_cycle == 3) begin
            if(fc_data_out == fc_out-1 && fc_data_in == fc_in-1)
                fc_data_out_r = 0;
            else if(fc_data_out == fc_in-1)
                fc_data_out_r = fc_data_out + 1;
            else
                fc_data_out_r = fc_data_out;
        end else begin 
            fc_data_out_r = fc_data_out;
        end
    end else begin
        fc_data_out_r = 0;
    end
end

always @(posedge clk) begin
    if(rst)
        fc_data_in <= 0;
    else
        fc_data_in <= fc_data_in_r;
end

always @(*) begin
    if(state == FSM_COMPUTE) begin
        if(data_cycle == 3) begin
            if(fc_data_out == fc_out-1 && fc_data_in == fc_in-1)
                fc_data_in_r = 0;
            else if(fc_data_out == fc_in-1)
                fc_data_in_r = 0;
            else
                fc_data_in_r = fc_data_in + 1;
        end else begin 
            fc_data_in_r = fc_data_in;
        end
    end else begin
        fc_data_in_r = 0;
    end
end

// count sram input addr

always @(posedge clk) begin
    if(rst)
        sram_input_addr <= 0;
    else
        sram_input_addr <= sram_input_addr_r;
end

always @(*) begin
    if(state == FSM_COMPUTE) begin
        if(data_cycle >= 2 ) begin
            if(sram_input_addr == fc_in-1)
                sram_input_addr_r = 0;
            else
                sram_input_addr_r = sram_input_addr + 1;
        end else begin
            sram_input_addr_r = sram_input_addr;
        end
    end else begin
        sram_input_addr_r = 0;
    end
end

// count weight addr

always @(*) begin
    if(state == FSM_COMPUTE)
        sram_weight_addr = fc_addr_out * fc_in + fc_addr_in;
    else
        sram_weight_addr = 0;
end

// give bias addr

always @(*) begin
    if(state == FSM_COMPUTE && fc_data_in == fc_in-4)
        sram_bias_addr = fc_data_out; 
    else
        sram_bias_addr = 0;
end

// fully_connection computation
reg  signed [DATA_WIDTH-1:0] compute_buffer;
reg  signed [DATA_WIDTH-1:0] compute_buffer_r;
reg  signed [DATA_WIDTH-1:0] output_ans;
// reg  signed [DATA_WIDTH-1:0] source;
// reg  signed [DATA_WIDTH-1:0] weight;
reg  signed [63:0]           partial_sum;
reg  signed [DATA_WIDTH-1:0] sum;

always @(posedge clk) begin
    if(rst)
        compute_buffer <= 0;
    else if(fc_data_in == fc_in-1)
        compute_buffer <= 0;
    else
        compute_buffer <= compute_buffer_r;
end

always @(*) begin
    compute_buffer_r = 0;
    partial_sum      = 0;
    sum              = 0;
    // output_ans       = 0;
    if(data_cycle == 3) begin
        partial_sum = sram_input_rdata * sram_weight_rdata;
        sum = partial_sum[24+:32];
        compute_buffer_r = compute_buffer + sum;
    end
end

always @(*) begin
    output_ans = compute_buffer_r + sram_bias_rdata;
end

// write enable

always @(posedge clk) begin
    if(rst)
        sram_output_wea <= 0;
    else
        sram_output_wea <= sram_output_wea_r;
end

always @(*) begin
    if(fc_data_in == fc_in-1)
        sram_output_wea_r <= 1;
    else
        sram_output_wea_r <= 0;
end

// write output addr

always @(posedge clk) begin
    if(rst)
        sram_output_addr <= 0;
    else
        sram_output_addr <= sram_output_addr_r;
end

always @(*) begin
    if(fc_data_in == fc_in-1)
        sram_output_addr_r = fc_data_out;
    else
        sram_output_addr_r = 0;
end

// write output data

always @(posedge clk) begin
    if(rst)
        sram_output_wdata <= 0;
    else
        sram_output_wdata <= sram_output_wdata_r;
end

always @(*) begin
    if(fc_data_in == fc_in-1)
        sram_output_wdata_r = output_ans;
    else
        sram_output_wdata_r = 0;
end

// write all output data done

always @(*) begin
    if(fc_data_out == fc_out-1 && fc_data_in == fc_in-1)
        compute_done = 1;
    else
        compute_done = 0;
end

endmodule
