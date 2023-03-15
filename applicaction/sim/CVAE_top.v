module CVAE_top #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32
)(
    input wire clk,
    input wire rst_n, // active low reset
    
    input wire start,
    output reg finish,
 
    // Memory burst, initial data
    input wire [DATA_WIDTH-1:0] init_data,
    
    // SRAM states, 1024X32b write-only
    output reg sram_state_wea, 
    output reg [ADDR_WIDTH-1:0] sram_state_addr,
    output reg [DATA_WIDTH-1:0] sram_state_wdata,

    // SRAM weight, 8192X32b, read-only
    output reg [ADDR_WIDTH-1:0] sram_weight_addr,
    input wire [DATA_WIDTH-1:0] sram_weight_rdata,

    // SRAM bias, 1024X32b, read-only
    output reg [ADDR_WIDTH-1:0] sram_bias_addr,
    input wire [DATA_WIDTH-1:0] sram_bias_rdata,

    output reg [5:0] seq_lens
);

// FSM signals
localparam  FSM_INIT    = 5'd0,
            FSM_LOADING = 5'd1,
            FSM_FC_L2H  = 5'd2,
            FSM_FC_IN   = 5'd3,
            FSM_FC_IR   = 5'd4,
            FSM_FC_IZ   = 5'd5,
            FSM_FC_HN   = 5'd6,
            FSM_FC_HR   = 5'd7,
            FSM_FC_HZ   = 5'd8,
            FSM_GRU     = 5'd9,
            FSM_FC_STATE= 5'd10,
            FSM_FC_CONF = 5'd11,
            FSM_CHECK   = 5'd12,
            FSM_FINISH  = 5'd15;
reg [4:0] state, state_next;

// Input FF signals
reg rst_n_FF;
reg start_FF;
reg signed [DATA_WIDTH-1:0] init_data_FF;
reg signed [DATA_WIDTH-1:0] sram_hidden_rdata_FF;
reg signed [DATA_WIDTH-1:0] sram_state_rdata_FF;
reg signed [DATA_WIDTH-1:0] sram_weight_rdata_FF;
reg signed [DATA_WIDTH-1:0] sram_bias_rdata_FF;


// output FF signals
reg finish_next;

reg sram_state_wea_next; 
reg [ADDR_WIDTH-1:0] sram_state_addr_next;
reg [DATA_WIDTH-1:0] sram_state_wdata_next;
reg [ADDR_WIDTH-1:0] sram_state_addr_offset, sram_state_addr_offset_next;
wire [ADDR_WIDTH-1:0] sram_weight_addr_next;
wire [ADDR_WIDTH-1:0] sram_bias_addr_next;

// Load init data
reg [7:0] load_counter, load_counter_next;

// FC signals
reg [ADDR_WIDTH-1:0] weight_offset, bias_offset;
reg [ADDR_WIDTH-1:0] weight_offset_next, bias_offset_next;
reg signed [DATA_WIDTH-1:0] fc_in_reg[0:31];
reg signed [DATA_WIDTH-1:0] fc_ir_reg[0:31];
reg signed [DATA_WIDTH-1:0] fc_iz_reg[0:31];
reg signed [DATA_WIDTH-1:0] fc_hn_reg[0:31];
reg signed [DATA_WIDTH-1:0] fc_hr_reg[0:31];
reg signed [DATA_WIDTH-1:0] fc_hz_reg[0:31];
reg signed [DATA_WIDTH-1:0] hidden_reg[0:31];
reg signed [DATA_WIDTH-1:0] state_reg[0:12];
reg signed [DATA_WIDTH-1:0] conf_reg[0:1];
reg signed [DATA_WIDTH-1:0] goal_reg[0:5];
reg signed [DATA_WIDTH-1:0] Z_reg[0:3];


reg signed [DATA_WIDTH-1:0] fc_input_FF, fc_input_FF_next;



// FC instance signals    
wire fc_finish;
wire fc_sram_output_wea;
wire [ADDR_WIDTH-1:0] fc_sram_input_addr;
wire [ADDR_WIDTH-1:0] fc_sram_weight_addr;
wire [ADDR_WIDTH-1:0] fc_sram_bias_addr;
wire [ADDR_WIDTH-1:0] fc_sram_output_addr;
wire [DATA_WIDTH-1:0] fc_sram_output_wdata;

reg fc_start, fc_start_next;
reg [7:0] FC_IN, FC_IN_next;
reg [7:0] FC_OUT, FC_OUT_next;

reg fc_in_start, fc_ir_start, fc_iz_start;
reg fc_hn_start, fc_hr_start, fc_hz_start;
reg fc_state_start, fc_conf_start, fc_l2h_start;

reg fc_in_start_next, fc_ir_start_next, fc_iz_start_next;
reg fc_hn_start_next, fc_hr_start_next, fc_hz_start_next;
reg fc_state_start_next, fc_conf_start_next, fc_l2h_start_next;

// GRU signals

reg [9:0] gru_counter, gru_counter_next;
reg [9:0] gru_in_counter;
reg [9:0] gru_ir_counter;
reg [9:0] gru_iz_counter;
reg [9:0] gru_hn_counter;
reg [9:0] gru_hr_counter;
reg [9:0] gru_hz_counter;
reg [9:0] gru_hidden_in_counter;
reg [9:0] gru_hidden_out_counter;

reg [9:0] gru_in_counter_next;
reg [9:0] gru_ir_counter_next;
reg [9:0] gru_iz_counter_next;
reg [9:0] gru_hn_counter_next;
reg [9:0] gru_hr_counter_next;
reg [9:0] gru_hz_counter_next;
reg [9:0] gru_hidden_in_counter_next;
reg [9:0] gru_hidden_out_counter_next;
reg [DATA_WIDTH-1:0] gru_in;
reg [DATA_WIDTH-1:0] gru_ir;
reg [DATA_WIDTH-1:0] gru_iz;
reg [DATA_WIDTH-1:0] gru_hn;
reg [DATA_WIDTH-1:0] gru_hr;
reg [DATA_WIDTH-1:0] gru_hz;
reg [DATA_WIDTH-1:0] gru_hidden_in;
wire [DATA_WIDTH-1:0] gru_hidden_out;
GRU#(
    .DATA_WIDTH(32), 
    .QUAN(24),
    .CORDIC_QUAN(16)
) gru (
    .clk(clk),
    .data_ir(gru_ir),
    .data_iz(gru_iz),
    .data_in(gru_in),
    .data_hr(gru_hr),
    .data_hz(gru_hz),
    .data_hn(gru_hn),
    .data_hidden_in(gru_hidden_in),

    .data_hidden_out(gru_hidden_out)
);


FullyConnection  #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
)FC(
    .clk(clk),
    .rst((state == FSM_INIT)),
    
    .start(fc_start),
    .finish(fc_finish),

    .FC_IN(FC_IN),
    .FC_OUT(FC_OUT),
    // input sram, read-only
    .sram_input_addr(fc_sram_input_addr),
    .sram_input_rdata(fc_input_FF),
    
    // weight sram, read-only
    .sram_weight_addr(fc_sram_weight_addr),
    .sram_weight_rdata(sram_weight_rdata_FF),

    // bias sram, read-only
    .sram_bias_addr(fc_sram_bias_addr),
    .sram_bias_rdata(sram_bias_rdata_FF),

    // output sram, write-only
    .sram_output_wea(fc_sram_output_wea),
    .sram_output_addr(fc_sram_output_addr),
    .sram_output_wdata(fc_sram_output_wdata)
);

// Input FF
always @(posedge clk) begin
    rst_n_FF             <= rst_n; // active low reset
    start_FF             <= start;
    init_data_FF         <= init_data;
    sram_bias_rdata_FF   <= sram_bias_rdata;
    sram_weight_rdata_FF <= sram_weight_rdata;
    
end

// Output FF
always @(posedge clk) begin
    finish <= finish_next;
end

always @(posedge clk) begin
    sram_state_wea <= sram_state_wea_next; 
end

always @(posedge clk) begin
    sram_state_addr <= sram_state_addr_next;
end

always @(posedge clk) begin
    sram_state_wdata <= sram_state_wdata_next;
end

always @(posedge clk) begin
    sram_weight_addr <= sram_weight_addr_next;
end

always @(posedge clk) begin
    sram_bias_addr <= sram_bias_addr_next;
end

reg [5:0] seq_lens_next;

always @(posedge clk) begin
    if(!rst_n_FF)
        seq_lens <= 0;
    else
        seq_lens <= seq_lens_next;
end

always @(*) begin
    if(state == FSM_CHECK)
        seq_lens_next = seq_lens + 1;
    else
        seq_lens_next = seq_lens;
end

always @(*) begin
    if(state == FSM_FINISH)
        finish_next = 1;
    else
        finish_next = 0;
end

always @(posedge clk) begin
    if(!rst_n_FF)
        sram_state_addr_offset <= 16'd13;
    else
        sram_state_addr_offset <= sram_state_addr_offset_next;
end
always @(*) begin
    case(state)
        FSM_CHECK:
            sram_state_addr_offset_next = sram_state_addr_offset + 16'd13;
        default:
            sram_state_addr_offset_next = sram_state_addr_offset;
    endcase
end

always @(*) begin
    if(state == FSM_FC_STATE) begin

        sram_state_wea_next = fc_sram_output_wea; 
        sram_state_addr_next = fc_sram_output_addr + sram_state_addr_offset;
        sram_state_wdata_next = fc_sram_output_wdata;
    end
    else begin
        
        sram_state_wea_next = 0; 
        sram_state_addr_next = 0;
        sram_state_wdata_next = 0;
    end
end

assign sram_weight_addr_next = fc_sram_weight_addr + weight_offset;
assign sram_bias_addr_next = fc_sram_bias_addr + bias_offset;


/////////////////////
// ===== FSM ===== //
always @(posedge clk) begin
    if(!rst_n_FF)
        state <= FSM_INIT;
    else
        state <= state_next;
end

always @(*) begin
    case(state)
        FSM_INIT: begin
            state_next = (start_FF == 1 ? FSM_LOADING : state);
        end
        FSM_LOADING: begin
            state_next = (load_counter == 41 ? FSM_FC_L2H : state);
        end
        FSM_FC_L2H: begin
            state_next = (fc_finish ? FSM_FC_IN : state);
        end
        FSM_FC_IN: begin
            state_next = (fc_finish ? FSM_FC_IR : state);
        end
        FSM_FC_IR: begin
            state_next = (fc_finish ? FSM_FC_IZ : state);
        end
        FSM_FC_IZ: begin
            state_next = (fc_finish ? FSM_FC_HN : state);
        end
        FSM_FC_HN: begin
            state_next = (fc_finish ? FSM_FC_HR : state);
        end
        FSM_FC_HR: begin
            state_next = (fc_finish ? FSM_FC_HZ : state);
        end
        FSM_FC_HZ: begin
            state_next = (fc_finish ? FSM_GRU : state);
        end
        FSM_GRU: begin
            state_next = (gru_hidden_out_counter == 31 ? FSM_FC_STATE  : state);
        end
        FSM_FC_STATE: begin
            state_next = (fc_finish ? FSM_FC_CONF : state);
        end
        FSM_FC_CONF: begin
            state_next = (fc_finish ? FSM_CHECK : state);
        end
        FSM_CHECK: begin
            state_next = (conf_reg[0] < conf_reg[1] ? FSM_FINISH : FSM_FC_IN);
        end
        FSM_FINISH: begin
            state_next = state;
        end
        default: begin
            state_next = FSM_INIT;
        end
    endcase
end

// ===== FSM ===== //
/////////////////////

always @(posedge clk) begin
    if(!rst_n_FF)
        weight_offset <= 0;
    else
        weight_offset <= weight_offset_next;
end

always @(posedge clk) begin
    if(!rst_n_FF)
        bias_offset <= 0;
    else
        bias_offset <= bias_offset_next;
end

always @(*) begin
    case(state)
        FSM_FC_IN:
            weight_offset_next = 0;
        FSM_FC_IR: 
            weight_offset_next = 608;
        FSM_FC_IZ: 
            weight_offset_next = 1216;
        FSM_FC_HN: 
            weight_offset_next =1824 ;
        FSM_FC_HR: 
            weight_offset_next = 2848;
        FSM_FC_HZ: 
            weight_offset_next = 3872;
        FSM_FC_STATE: 
            weight_offset_next = 4896;
        FSM_FC_CONF: 
            weight_offset_next = 5312;
        FSM_FC_L2H:
            weight_offset_next = 5388;
        FSM_FINISH:
            weight_offset_next = 0;
        default:
            weight_offset_next = 0;
    endcase
end

always @(*) begin
    case(state)
        FSM_FC_IN:
            bias_offset_next = 0;
        FSM_FC_IR: 
            bias_offset_next = 32;
        FSM_FC_IZ: 
            bias_offset_next = 64;
        FSM_FC_HN: 
            bias_offset_next = 96;
        FSM_FC_HR:
            bias_offset_next = 128;
        FSM_FC_HZ: 
            bias_offset_next = 160;
        FSM_FC_STATE: 
            bias_offset_next = 192;
        FSM_FC_CONF: 
            bias_offset_next = 205;
        FSM_FC_L2H: 
            bias_offset_next = 207;
        FSM_FINISH:
            bias_offset_next = 0;
        default:
            bias_offset_next = 0;
    endcase
end

// ===== FC start reg  =====

always @(posedge clk) begin
    if(!rst_n_FF)
        fc_hn_start <= 0;
    else
        fc_hn_start <= fc_hn_start_next;
end

always @(*) begin
    if(state == FSM_FC_HN)
        fc_hn_start_next = 0;
    else
        fc_hn_start_next = 1;
end

always @(posedge clk) begin
    if(!rst_n_FF)
        fc_hr_start <= 0;
    else
        fc_hr_start <= fc_hr_start_next;
end
always @(*) begin
    if(state == FSM_FC_HR)
        fc_hr_start_next = 0;
    else
        fc_hr_start_next = 1;
end

always @(posedge clk) begin
    if(!rst_n_FF)
        fc_hz_start <= 0;
    else
        fc_hz_start <= fc_hz_start_next;
end
always @(*) begin
    if(state == FSM_FC_HZ)
        fc_hz_start_next = 0;
    else
        fc_hz_start_next = 1;
end

always @(posedge clk) begin
    if(!rst_n_FF)
        fc_in_start <= 0;
    else
        fc_in_start <= fc_in_start_next;
end
always @(*) begin
    if(state == FSM_FC_IN)
        fc_in_start_next = 0;
    else
        fc_in_start_next = 1;
end

always @(posedge clk) begin
    if(!rst_n_FF)
        fc_ir_start <= 0;
    else
        fc_ir_start <= fc_ir_start_next;
end
always @(*) begin
    if(state == FSM_FC_IR)
        fc_ir_start_next = 0;
    else
        fc_ir_start_next = 1;
end

always @(posedge clk) begin
    if(!rst_n_FF)
        fc_iz_start <= 0;
    else
        fc_iz_start <= fc_iz_start_next;
end
always @(*) begin
    if(state == FSM_FC_IZ)
        fc_iz_start_next = 0;
    else
        fc_iz_start_next = 1;
end

always @(posedge clk) begin
    if(!rst_n_FF)
        fc_state_start <= 0;
    else
        fc_state_start <= fc_state_start_next;
end
always @(*) begin
    if(state == FSM_FC_STATE)
        fc_state_start_next = 0;
    else
        fc_state_start_next = 1;
end

always @(posedge clk) begin
    if(!rst_n_FF)
        fc_conf_start <= 0;
    else
        fc_conf_start <= fc_conf_start_next;
end
always @(*) begin
    if(state == FSM_FC_CONF)
        fc_conf_start_next = 0;
    else
        fc_conf_start_next = 1;
end


always @(posedge clk) begin
    if(!rst_n_FF)
        fc_l2h_start <= 0;
    else
        fc_l2h_start <= fc_l2h_start_next;
end
always @(*) begin
    if(state == FSM_FC_L2H)
        fc_l2h_start_next = 0;
    else
        fc_l2h_start_next = 1;
end


always @(posedge clk) begin
    if(!rst_n_FF)
        fc_start <= 0;
    else
        fc_start <= fc_start_next;
end

always @(*) begin
    case(state)
        FSM_FC_L2H:
            fc_start_next = fc_l2h_start;
        FSM_FC_IN:
            fc_start_next = fc_in_start;
        FSM_FC_IR:
            fc_start_next = fc_ir_start;
        FSM_FC_IZ:
            fc_start_next = fc_iz_start;
        FSM_FC_HN:
            fc_start_next = fc_hn_start;
        FSM_FC_HR:
            fc_start_next = fc_hr_start;
        FSM_FC_HZ:
            fc_start_next = fc_hz_start;
        FSM_FC_STATE:
            fc_start_next = fc_state_start;
        FSM_FC_CONF:
            fc_start_next = fc_conf_start;
        default:
            fc_start_next = 0;
    endcase
end


// ===== FC IN/OUT =====

always @(posedge clk) begin
    if(!rst_n_FF)
        FC_IN <= 0;
    else
        FC_IN <= FC_IN_next;
end

always @(*) begin
    case(state)
        FSM_FC_L2H:
            FC_IN_next = 4;
        FSM_FC_IN:
            FC_IN_next = 19;
        FSM_FC_IR:
            FC_IN_next = 19;
        FSM_FC_IZ:
            FC_IN_next = 19;
        FSM_FC_HN:
            FC_IN_next = 32;
        FSM_FC_HR:
            FC_IN_next = 32;
        FSM_FC_HZ:
            FC_IN_next = 32;
        FSM_FC_STATE:
            FC_IN_next = 32;
        FSM_FC_CONF:
            FC_IN_next = 38;
        default:
            FC_IN_next = 0;
    endcase
end

always @(posedge clk) begin
    if(!rst_n_FF)
        FC_OUT <= 0;
    else
        FC_OUT <= FC_OUT_next;
end
always @(*) begin
    case(state)
        FSM_FC_L2H:
            FC_OUT_next = 32;
        FSM_FC_IN:
            FC_OUT_next = 32;
        FSM_FC_IR:
            FC_OUT_next = 32;
        FSM_FC_IZ:
            FC_OUT_next = 32;
        FSM_FC_HN:
            FC_OUT_next = 32;
        FSM_FC_HR:
            FC_OUT_next = 32;
        FSM_FC_HZ:
            FC_OUT_next = 32;
        FSM_FC_STATE:
            FC_OUT_next = 13;
        FSM_FC_CONF:
            FC_OUT_next = 2;
        default:
            FC_OUT_next = 0;
    endcase
end

// ===== SRAM signals =====

always @(posedge clk) begin
    if(!rst_n_FF)
        fc_input_FF <= 0;
    else
        fc_input_FF <= fc_input_FF_next;
end

always @(*) begin
    case(state)
        FSM_FC_L2H:
            fc_input_FF_next = Z_reg[fc_sram_input_addr];
        FSM_FC_HN:
            fc_input_FF_next = hidden_reg[fc_sram_input_addr];
        FSM_FC_HR:
            fc_input_FF_next = hidden_reg[fc_sram_input_addr];
        FSM_FC_HZ:
            fc_input_FF_next = hidden_reg[fc_sram_input_addr];
        FSM_FC_IN:
            fc_input_FF_next = (fc_sram_input_addr < 13 ? state_reg[fc_sram_input_addr] : goal_reg[fc_sram_input_addr-13]);
        FSM_FC_IR:
            fc_input_FF_next = (fc_sram_input_addr < 13 ? state_reg[fc_sram_input_addr] : goal_reg[fc_sram_input_addr-13]);
        FSM_FC_IZ:
            fc_input_FF_next = (fc_sram_input_addr < 13 ? state_reg[fc_sram_input_addr] : goal_reg[fc_sram_input_addr-13]);
        FSM_FC_STATE:
            fc_input_FF_next = hidden_reg[fc_sram_input_addr];
        FSM_FC_CONF:
            fc_input_FF_next = (fc_sram_input_addr < 32 ? hidden_reg[fc_sram_input_addr] : goal_reg[fc_sram_input_addr-32]);
        default:
            fc_input_FF_next = 0;
    endcase
end

always @(posedge clk) begin
    if(fc_sram_output_wea && state == FSM_FC_IN) 
        fc_in_reg[fc_sram_output_addr] <= fc_sram_output_wdata;
end

always @(posedge clk) begin
    if(fc_sram_output_wea && state == FSM_FC_IR) 
        fc_ir_reg[fc_sram_output_addr] <= fc_sram_output_wdata;
end

always @(posedge clk) begin
    if(fc_sram_output_wea && state == FSM_FC_IZ) 
        fc_iz_reg[fc_sram_output_addr] <= fc_sram_output_wdata;
end

always @(posedge clk) begin
    if(fc_sram_output_wea && state == FSM_FC_HN) 
        fc_hn_reg[fc_sram_output_addr] <= fc_sram_output_wdata;
end

always @(posedge clk) begin
    if(fc_sram_output_wea && state == FSM_FC_HR) 
        fc_hr_reg[fc_sram_output_addr] <= fc_sram_output_wdata;
end

always @(posedge clk) begin
    if(fc_sram_output_wea && state == FSM_FC_HZ) 
        fc_hz_reg[fc_sram_output_addr] <= fc_sram_output_wdata;
end


always @(posedge clk) begin
    if(fc_sram_output_wea && state == FSM_FC_CONF) 
        conf_reg[fc_sram_output_addr] <= fc_sram_output_wdata;
end


// ===== Load initial data =====
always @(posedge clk) begin
    if(!rst_n_FF)
        load_counter <= 0;
    else
        load_counter <= load_counter_next;
end
always @(*) begin
    if(state == FSM_LOADING)
        load_counter_next = load_counter + 1;
    else
        load_counter_next = 0;
end

always @(posedge clk) begin
    case(state)
        FSM_LOADING:
            if(19 <= load_counter &&  load_counter < 23)
                Z_reg[load_counter-19] <= init_data_FF;
    endcase
end

always @(posedge clk) begin
    case(state)
        FSM_FC_L2H:
            if(fc_sram_output_wea)
                hidden_reg[fc_sram_output_addr] <= fc_sram_output_wdata;

        FSM_GRU:
            if(gru_counter >= 88)
                hidden_reg[gru_hidden_out_counter] <= gru_hidden_out;
    endcase
end
always @(posedge clk) begin
    case(state)
        FSM_LOADING:
            if(load_counter < 13)
                state_reg[load_counter] <= init_data_FF;
        FSM_FC_STATE:
            if(fc_sram_output_wea)
                state_reg[fc_sram_output_addr] <= fc_sram_output_wdata;
    endcase
end
always @(posedge clk) begin
    case(state)
        FSM_LOADING:
            if(13 <= load_counter &&  load_counter < 19)
                goal_reg[load_counter-13] <= init_data_FF;
    endcase
end

// =================== GRU ======================//

always @(posedge clk) begin
    gru_hidden_in <= hidden_reg[gru_hidden_in_counter];
    gru_in <= fc_in_reg[gru_in_counter];
    gru_ir <= fc_ir_reg[gru_ir_counter];
    gru_iz <= fc_iz_reg[gru_iz_counter];
    gru_hn <= fc_hn_reg[gru_hn_counter];
    gru_hr <= fc_hr_reg[gru_hr_counter];
    gru_hz <= fc_hz_reg[gru_hz_counter];
end
always @(posedge clk) begin
    if(!rst_n_FF)
        gru_counter <= 0;
    else
        gru_counter <= gru_counter_next;
end

always @(*) begin
    if(state == FSM_GRU)
        gru_counter_next = gru_counter + 1;
    else
        gru_counter_next = 0;
end


always @(posedge clk) begin
    if(!rst_n_FF)
        gru_hr_counter <= 0;
    else
        gru_hr_counter <= gru_hr_counter_next;
end
always @(*) begin
    if(state == FSM_GRU)
        gru_hr_counter_next = (gru_hr_counter == 31 ? 31 : gru_hr_counter + 1);
    else
        gru_hr_counter_next = 0;
end

always @(posedge clk) begin
    if(!rst_n_FF)
        gru_ir_counter <= 0;
    else
        gru_ir_counter <=gru_ir_counter_next;
end
always @(*) begin
    if(state == FSM_GRU)
        gru_ir_counter_next = (gru_ir_counter == 31 ? 31 : gru_ir_counter + 1);
    else
        gru_ir_counter_next = 0;
end

always @(posedge clk) begin
    if(!rst_n_FF)
        gru_hz_counter <= 0;
    else
        gru_hz_counter <= gru_hz_counter_next;
end
always @(*) begin
    if(state == FSM_GRU && gru_counter >= 42)
        gru_hz_counter_next = (gru_hz_counter == 31 ? 31 : gru_hz_counter + 1);
    else
        gru_hz_counter_next = 0;
end

always @(posedge clk) begin
    if(!rst_n_FF)
        gru_iz_counter <= 0;
    else
        gru_iz_counter <= gru_iz_counter_next;
end
always @(*) begin
    if(state == FSM_GRU && gru_counter >= 42)
        gru_iz_counter_next = (gru_iz_counter == 31 ? 31 : gru_iz_counter + 1);
    else
        gru_iz_counter_next = 0;
end


always @(posedge clk) begin
    if(!rst_n_FF)
        gru_hn_counter <= 0;
    else
        gru_hn_counter <= gru_hn_counter_next;
end
always @(*) begin
    if(state == FSM_GRU && gru_counter >= 42)
        gru_hn_counter_next = (gru_hn_counter == 31 ? 31 : gru_hn_counter + 1);
    else
        gru_hn_counter_next = 0;
end


always @(posedge clk) begin
    if(!rst_n_FF)
        gru_in_counter <= 0;
    else
        gru_in_counter <= gru_in_counter_next;
end
always @(*) begin
    if(state == FSM_GRU && gru_counter >= 43)
        gru_in_counter_next = (gru_in_counter == 31 ? 31 : gru_in_counter + 1);
    else
        gru_in_counter_next = 0;
end


always @(posedge clk) begin
    if(!rst_n_FF)
        gru_hidden_in_counter <= 0;
    else
        gru_hidden_in_counter <= gru_hidden_in_counter_next;
end
always @(*) begin
    if(state == FSM_GRU && gru_counter >= 85)
        gru_hidden_in_counter_next = (gru_hidden_in_counter == 31 ? 31 : gru_hidden_in_counter + 1);
    else
        gru_hidden_in_counter_next = 0;
end

always @(posedge clk) begin
    if(!rst_n_FF)
        gru_hidden_out_counter <= 0;
    else
        gru_hidden_out_counter <= gru_hidden_out_counter_next;
end
always @(*) begin
    if(state == FSM_GRU && gru_counter >= 88)
        gru_hidden_out_counter_next = (gru_hidden_out_counter == 31 ? 31 : gru_hidden_out_counter + 1);
    else
        gru_hidden_out_counter_next = 0;
end


endmodule
