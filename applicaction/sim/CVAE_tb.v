`timescale 1ns/1ps

module CVAE_tb();

real CYCLE = 24;
parameter END_CYCLES = 220000;
parameter DATA_WIDTH = 32;
parameter ADDR_WIDTH = 16;

reg clk, rst_n;


// ===== Instance signals ===== //

reg start; 
wire finish; 

// Memory burst;  initial data
reg [DATA_WIDTH-1:0] init_data; 

// SRAM states;  1024X32b write-only
wire sram_state_wea;  
wire [ADDR_WIDTH-1:0] sram_state_addr; 
wire [DATA_WIDTH-1:0] sram_state_wdata; 

// SRAM weight;  8192X32b;  read-only
wire [ADDR_WIDTH-1:0] sram_weight_addr; 
wire [DATA_WIDTH-1:0] sram_weight_rdata; 

// SRAM bias;  1024X32b;  read-only
wire [ADDR_WIDTH-1:0] sram_bias_addr; 
wire [DATA_WIDTH-1:0] sram_bias_rdata;
wire [5:0] seq_lens;

// Golden Memory
reg [DATA_WIDTH-1:0] golden_state[0:779];
reg [DATA_WIDTH-1:0] goal[0:5];
reg [DATA_WIDTH-1:0] golden_hidden[0:1919];
reg [7:0] golden_seq_lens[0:0];
reg [DATA_WIDTH-1:0] init_Z[0:3];



CVAE_top cvae (
//CHIP cvae (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .finish(finish),
    // Memory burst, initial data
    .init_data(init_data),
    // SRAM states, 1024X32b write-only
    .sram_state_wea(sram_state_wea), 
    .sram_state_addr(sram_state_addr),
    .sram_state_wdata(sram_state_wdata),
    // SRAM weight, 8192X32b, read-only
    .sram_weight_addr(sram_weight_addr),
    .sram_weight_rdata(sram_weight_rdata),
    // SRAM bias, 1024X32b, read-only
    .sram_bias_addr(sram_bias_addr),
    .sram_bias_rdata(sram_bias_rdata),
    .seq_lens(seq_lens)
);

// State SRAM, write-only
rams_sp_wf #(
    .depth(780),
    .data_width(DATA_WIDTH),
    .addr_width(ADDR_WIDTH)
)
SRAM_STATE_780x32b (
    .clka(clk),
    .wea(sram_state_wea),
    .addra(sram_state_addr),
    .dina(sram_state_wdata),
    .douta()
);

// Weight SRAM, read-only
rams_sp_wf #(
    .depth(8192),
    .data_width(DATA_WIDTH),
    .addr_width(ADDR_WIDTH)
)
SRAM_WEIGHT_5388x32b (
    .clka(clk),
    .wea(1'b0),
    .addra(sram_weight_addr),
    .dina(32'b0),
    .douta(sram_weight_rdata)
);

// Bias SRAM, read-only
rams_sp_wf #(
    .depth(512),
    .data_width(DATA_WIDTH),
    .addr_width(ADDR_WIDTH)
)
SRAM_BIAS_211x32b (
    .clka(clk),
    .wea(1'b0),
    .addra(sram_bias_addr),
    .dina(32'b0),
    .douta(sram_bias_rdata)
);


// ===== system reset ===== //
reg start_count;
integer count;
initial begin
    clk = 0;
    rst_n = 1;
    start = 0;
    init_data = 0; 
    count = 0;
end


// ===== Counter ===== //

initial begin
    wait(start == 1);
    start_count = 1;
    wait(finish == 1);
    start_count = 0;
end

always @(posedge clk) begin
    if(start_count)
        count <= count + 1;
end 

// ===== Load data ===== //
initial begin
    SRAM_WEIGHT_5388x32b.load_data("./data/TP/weights/weights.csv");
    SRAM_BIAS_211x32b.load_data("./data/TP/bias/bias.csv");
    $readmemh("./data/TP/debug/hidden.csv", golden_hidden);
    $readmemh("./data/TP/outputs/state.csv", golden_state);
    $readmemh("./data/TP/inputs/s_goal.csv", goal);
    $readmemh("./data/TP/inputs/z_in.csv", init_Z);
    $readmemh("./data/TP/outputs/seq_lens.csv", golden_seq_lens);

end

// ===== waveform dumpping ===== //

// initial begin
//     `ifdef GATESIM
//         // $fsdbDumpfile("CVAE_syn.fsdb");
//         // $fsdbDumpvars;
//         $sdf_annotate("../../SYN/DC/CVAE_top_syn.sdf",cvae);
//     `else
//         // $fsdbDumpfile("CVAE.fsdb");
//         // $fsdbDumpvars;
//     `endif
// end

// ===== Clk fliping ===== //
always #(CYCLE/2) begin
    clk = ~clk;
end 

// ===== Time Exceed Abortion ===== //
initial begin
    #(CYCLE*END_CYCLES);
    $display("\n========================================================");
    $display("You have exceeded the cycle count limit.");
    $display("Simulation abort");
    $display("========================================================");
    $finish;    
end

integer i;
reg same;
// ===== System Simulation =====
initial begin
    $monitor("Seqlens: %d", seq_lens);
    #(CYCLE*100);
    $display("Reset System");
    @(negedge clk);
    rst_n = 1'b0;
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    rst_n = 1'b1;
    $display("Simulation Start");
    @(negedge clk);
    start = 1'b1;
    @(negedge clk);
    start = 1'b0;

    for(i = 0 ; i < 13 ; i = i + 1) begin
        init_data = golden_state[i]; 
        @(negedge clk);
    end
    
    for(i = 0 ; i < 6 ; i = i + 1) begin
        init_data = goal[i]; 
        @(negedge clk);
    end
    
    for(i = 0 ; i < 4 ; i = i + 1) begin
        init_data = init_Z[i];
        @(negedge clk);
    end
        

    wait(finish == 1);

    //$display("Start checking inital data of CVAE");
    // same = 1;
    // for(i = 0 ; i < 13 ; i = i + 1) begin
    //     //$display("CVAE inital state[%d]: %h", i, cvae.state_reg[i]);
    //     if(cvae.state_reg[i] !== golden_state[i])
    //         same = 0;
    // end
    // $display("=============================");
    // $display("       Init state %s !!", (same == 1 ? "PASS" : "FAIL"));
    // $display("=============================");


    // same = 1;
    // for(i = 0 ; i < 6 ; i = i + 1) begin
        
    //     //$display("CVAE inital goal[%d]: %h", i, cvae.goal_reg[i]); 
    //     if(cvae.goal_reg[i] !== goal[i])
    //         same = 0;
    // end
    // $display("=============================");
    // $display("       Init goal %s !!", (same == 1 ? "PASS" : "FAIL"));
    // $display("=============================");

    //$display("Initial Simulation Finish");
end

// ===== output comparision ===== //
//golden debug FC
reg [DATA_WIDTH-1:0] golden_fc_hn[0:1919];
reg [DATA_WIDTH-1:0] golden_fc_hr[0:1919];
reg [DATA_WIDTH-1:0] golden_fc_hz[0:1919];
reg [DATA_WIDTH-1:0] golden_fc_in[0:1919];
reg [DATA_WIDTH-1:0] golden_fc_ir[0:1919];
reg [DATA_WIDTH-1:0] golden_fc_iz[0:1919];
integer j;
integer error;

//load data
initial begin
    $readmemh("./data/TP/debug/FC_HN.csv", golden_fc_hn);
    $readmemh("./data/TP/debug/FC_HR.csv", golden_fc_hr);
    $readmemh("./data/TP/debug/FC_HZ.csv", golden_fc_hz);
    $readmemh("./data/TP/debug/FC_IN.csv", golden_fc_in);
    $readmemh("./data/TP/debug/FC_IR.csv", golden_fc_ir);
    $readmemh("./data/TP/debug/FC_IZ.csv", golden_fc_iz);
end

initial begin

    wait(finish == 1);

    // // check FC_IN
    // error = 0;
    // $display("Start checking FC_IN ...");
    // for (j=0 ; j<32 ; j=j+1) begin
    //     if (cvae.fc_in_reg[j] !== golden_fc_in[j]) begin
    //         $display("fc_in_reg[%0d] = %8h  golden = %8h", j , cvae.fc_in_reg[j] ,golden_fc_in[j]);
    //         error = error + 1;
    //     end
    // end
    // if (error>0) begin
    //     $display("=============================");
    //     $display("       FC_IN FAIL!!          ");
    //     $display("=============================");
    // end
    // else begin
    //     $display("=============================");
    //     $display("       FC_IN PASS!!          ");
    //     $display("=============================");
    // end

    // // check FC_IR
    // error = 0;
    // $display("Start checking FC_IR ...");
    // for (j=0 ; j<32 ; j=j+1) begin
    //     if (cvae.fc_ir_reg[j] !== golden_fc_ir[j]) begin
    //         $display("fc_ir_reg[%0d] = %8h  golden = %8h", j , cvae.fc_ir_reg[j] ,golden_fc_ir[j]);
    //         error = error + 1;
    //     end
    // end 
    // if (error>0) begin
    //     $display("=============================");
    //     $display("       FC_IR FAIL!!          ");
    //     $display("=============================");
    // end
    // else begin
    //     $display("=============================");
    //     $display("       FC_IR PASS!!          ");
    //     $display("=============================");
    // end  

    // // check FC_IZ
    // error = 0;
    // $display("Start checking FC_IZ ...");
    // for (j=0 ; j<32 ; j=j+1) begin
    //     if (cvae.fc_iz_reg[j] !== golden_fc_iz[j]) begin
    //         $display("fc_iz_reg[%0d] = %8h  golden = %8h", j , cvae.fc_iz_reg[j] ,golden_fc_iz[j]);
    //         error = error + 1;
    //     end
    // end 
    // if (error>0) begin
    //     $display("=============================");
    //     $display("       FC_IZ FAIL!!          ");
    //     $display("=============================");
    // end
    // else begin
    //     $display("=============================");
    //     $display("       FC_IZ PASS!!          ");
    //     $display("=============================");
    // end  

    // // check FC_HN
    // error = 0;
    // $display("Start checking FC_HN ...");
    // for (j=0 ; j<32 ; j=j+1) begin
    //     if (cvae.fc_hn_reg[j] !== golden_fc_hn[j]) begin
    //         $display("fc_hn_reg[%0d] = %8h  golden = %8h", j , cvae.fc_hn_reg[j] ,golden_fc_hn[j]);
    //         error = error + 1;
    //     end
    // end
    // if (error>0) begin
    //     $display("=============================");
    //     $display("       FC_HN FAIL!!          ");
    //     $display("=============================");
    // end
    // else begin
    //     $display("=============================");
    //     $display("       FC_HN PASS!!          ");
    //     $display("=============================");
    // end  

    // // check FC_HR
    // error = 0;
    // $display("Start checking FC_HR ...");
    // for (j=0 ; j<32 ; j=j+1) begin
    //     if (cvae.fc_hr_reg[j] !== golden_fc_hr[j]) begin
    //         $display("fc_hr_reg[%0d] = %8h  golden = %8h", j , cvae.fc_hr_reg[j] ,golden_fc_hr[j]);
    //         error = error + 1;
    //     end
    // end
    // if (error>0) begin
    //     $display("=============================");
    //     $display("       FC_HR FAIL!!          ");
    //     $display("=============================");
    // end
    // else begin
    //     $display("=============================");
    //     $display("       FC_HR PASS!!          ");
    //     $display("=============================");
    // end     

    // // check FC_HZ
    // error = 0;
    // $display("Start checking FC_HZ ...");
    // for (j=0 ; j<32 ; j=j+1) begin
    //     if (cvae.fc_hz_reg[j] !== golden_fc_hz[j]) begin
    //         $display("fc_hz_reg[%0d] = %8h  golden = %8h", j , cvae.fc_hz_reg[j] ,golden_fc_hz[j]);
    //         error = error + 1;
    //     end
    // end     
    // if (error>0) begin
    //     $display("=============================");
    //     $display("       FC_HZ FAIL!!          ");
    //     $display("=============================");
    // end
    // else begin
    //     $display("=============================");
    //     $display("       FC_HZ PASS!!          ");
    //     $display("=============================");
    // end     

    $display("Start checking Result...");
    $display("Using Cycles: %d", count);
    if(golden_seq_lens[0] !== {2'b0,seq_lens})
        $display("[ERROR]: Golden:%d , Yours:%d", golden_seq_lens[0] , {2'b0,seq_lens});
    else
        $display("[CORRECT]: Seqlens: %d", {2'b0,seq_lens});

    error = 0;
    for (j=0 ; j<seq_lens*13 ; j=j+1) begin
        if (SRAM_STATE_780x32b.RAM[13+j] !== golden_state[13+j]) begin
            $display("state_reg[%0d] = %8h  golden = %8h", 13+j , SRAM_STATE_780x32b.RAM[13+j] ,golden_state[13+j]);
            error = error + 1;
        end
    end     
    if (error>0) begin
        $display("=============================");
        $display("       State FAIL!!          ");
        $display("=============================");
    end
    else begin
        $display("=============================");
        $display("          PASS!!          ");
        $display("=============================");
    end     

    $finish;
end


initial begin
$fsdbDumpfile("tb.fsdb");
// $fsdbDumpvars(0,"+mda");
$fsdbDumpvars();
end

endmodule
