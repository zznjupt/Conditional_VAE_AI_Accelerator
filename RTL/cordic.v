module cordic # (
    parameter        DATA_WIDTH  = 32,
    parameter        CORDIC_QUAN = 16,
    parameter signed X_0         = 32'd704813465,
    parameter signed Y_0         = 0,
    parameter        mode        = 0
) (
    input  wire                         clk,                     
    input  wire signed [DATA_WIDTH-1:0] D_in,
    output reg  signed [DATA_WIDTH-1:0] D_out
);

wire signed [DATA_WIDTH-1:0] X_in[0:41];
wire signed [DATA_WIDTH-1:0] Y_in[0:41];
wire signed [DATA_WIDTH-1:0] Z_in[0:41];
reg  signed [DATA_WIDTH-1:0] D_out_next;

assign X_in[0] = X_0;
assign Y_in[0] = Y_0;
assign Z_in[0] = (mode == 0 ? ((~D_in) + 1) : (D_in << 1));

/*
  NP_RHC iteration
*/


np_rhc #(.DATA_WIDTH(DATA_WIDTH), .M_ATANH(32'd386121), .shift(16)) 
np_rhc_3 (
  .clk(clk), 
  .x_in(X_in[0]), .y_in(Y_in[0]), .z_in(Z_in[0]), 
  .x_out(X_in[1]), .y_out(Y_in[1]), .z_out(Z_in[1])  
);

np_rhc #(.DATA_WIDTH(DATA_WIDTH), .M_ATANH(32'd204353), .shift(8)) 
np_rhc_2 (
  .clk(clk), 
  .x_in(X_in[1]), .y_in(Y_in[1]), .z_in(Z_in[1]), 
  .x_out(X_in[2]), .y_out(Y_in[2]), .z_out(Z_in[2])  
);

np_rhc #(.DATA_WIDTH(DATA_WIDTH), .M_ATANH(32'd112542), .shift(4)) 
np_rhc_1 (
  .clk(clk), 
  .x_in(X_in[2]), .y_in(Y_in[2]), .z_in(Z_in[2]), 
  .x_out(X_in[3]), .y_out(Y_in[3]), .z_out(Z_in[3])  
);

np_rhc #(.DATA_WIDTH(DATA_WIDTH), .M_ATANH(32'd63763), .shift(2)) 
np_rhc_0 (
  .clk(clk), 
  .x_in(X_in[3]), .y_in(Y_in[3]), .z_in(Z_in[3]), 
  .x_out(X_in[4]), .y_out(Y_in[4]), .z_out(Z_in[4])  
);

/*
  P_RHC iteration
*/

p_rhc #(.DATA_WIDTH(DATA_WIDTH), .ATANH(32'd35999), .shift(1)) 
p_rhc_1 (
  .clk(clk), 
  .x_in(X_in[4]), .y_in(Y_in[4]), .z_in(Z_in[4]), 
  .x_out(X_in[5]), .y_out(Y_in[5]), .z_out(Z_in[5])  
);

p_rhc #(.DATA_WIDTH(DATA_WIDTH), .ATANH(32'd16738), .shift(2)) 
p_rhc_2 (
  .clk(clk), 
  .x_in(X_in[5]), .y_in(Y_in[5]), .z_in(Z_in[5]), 
  .x_out(X_in[6]), .y_out(Y_in[6]), .z_out(Z_in[6])  
);

p_rhc #(.DATA_WIDTH(DATA_WIDTH), .ATANH(32'd8235), .shift(3)) 
p_rhc_3 (
  .clk(clk), 
  .x_in(X_in[6]), .y_in(Y_in[6]), .z_in(Z_in[6]), 
  .x_out(X_in[7]), .y_out(Y_in[7]), .z_out(Z_in[7])  
);

p_rhc #(.DATA_WIDTH(DATA_WIDTH), .ATANH(32'd4101), .shift(4)) 
p_rhc_4_0 (
  .clk(clk), 
  .x_in(X_in[7]), .y_in(Y_in[7]), .z_in(Z_in[7]), 
  .x_out(X_in[8]), .y_out(Y_in[8]), .z_out(Z_in[8])  
);

p_rhc #(.DATA_WIDTH(DATA_WIDTH), .ATANH(32'd4101), .shift(4)) 
p_rhc_4_1 (
  .clk(clk), 
  .x_in(X_in[8]), .y_in(Y_in[8]), .z_in(Z_in[8]), 
  .x_out(X_in[9]), .y_out(Y_in[9]), .z_out(Z_in[9])  
);

p_rhc #(.DATA_WIDTH(DATA_WIDTH), .ATANH(32'd2048), .shift(5)) 
p_rhc_5 (
  .clk(clk), 
  .x_in(X_in[9]), .y_in(Y_in[9]), .z_in(Z_in[9]), 
  .x_out(X_in[10]), .y_out(Y_in[10]), .z_out(Z_in[10])  
);

p_rhc #(.DATA_WIDTH(DATA_WIDTH), .ATANH(32'd1024), .shift(6)) 
p_rhc_6 (
  .clk(clk), 
  .x_in(X_in[10]), .y_in(Y_in[10]), .z_in(Z_in[10]), 
  .x_out(X_in[11]), .y_out(Y_in[11]), .z_out(Z_in[11])  
);

p_rhc #(.DATA_WIDTH(DATA_WIDTH), .ATANH(32'd512), .shift(7)) 
p_rhc_7 (
  .clk(clk), 
  .x_in(X_in[11]), .y_in(Y_in[11]), .z_in(Z_in[11]), 
  .x_out(X_in[12]), .y_out(Y_in[12]), .z_out(Z_in[12])  
);

p_rhc #(.DATA_WIDTH(DATA_WIDTH), .ATANH(32'd256), .shift(8)) 
p_rhc_8 (
  .clk(clk), 
  .x_in(X_in[12]), .y_in(Y_in[12]), .z_in(Z_in[12]), 
  .x_out(X_in[13]), .y_out(Y_in[13]), .z_out(Z_in[13])  
);

p_rhc #(.DATA_WIDTH(DATA_WIDTH), .ATANH(32'd128), .shift(9)) 
p_rhc_9 (
  .clk(clk), 
  .x_in(X_in[13]), .y_in(Y_in[13]), .z_in(Z_in[13]), 
  .x_out(X_in[14]), .y_out(Y_in[14]), .z_out(Z_in[14])  
);

p_rhc #(.DATA_WIDTH(DATA_WIDTH), .ATANH(32'd64), .shift(10)) 
p_rhc_10 (
  .clk(clk), 
  .x_in(X_in[14]), .y_in(Y_in[14]), .z_in(Z_in[14]), 
  .x_out(X_in[15]), .y_out(Y_in[15]), .z_out(Z_in[15])  
);

p_rhc #(.DATA_WIDTH(DATA_WIDTH), .ATANH(32'd32), .shift(11)) 
p_rhc_11 (
  .clk(clk), 
  .x_in(X_in[15]), .y_in(Y_in[15]), .z_in(Z_in[15]), 
  .x_out(X_in[16]), .y_out(Y_in[16]), .z_out(Z_in[16])  
);

p_rhc #(.DATA_WIDTH(DATA_WIDTH), .ATANH(32'd16), .shift(12)) 
p_rhc_12 (
  .clk(clk), 
  .x_in(X_in[16]), .y_in(Y_in[16]), .z_in(Z_in[16]), 
  .x_out(X_in[17]), .y_out(Y_in[17]), .z_out(Z_in[17])  
);

p_rhc #(.DATA_WIDTH(DATA_WIDTH), .ATANH(32'd8), .shift(13)) 
p_rhc_13_0 (
  .clk(clk), 
  .x_in(X_in[17]), .y_in(Y_in[17]), .z_in(Z_in[17]), 
  .x_out(X_in[18]), .y_out(Y_in[18]), .z_out(Z_in[18])  
);

p_rhc #(.DATA_WIDTH(DATA_WIDTH), .ATANH(32'd8), .shift(13)) 
p_rhc_13_1 (
  .clk(clk), 
  .x_in(X_in[18]), .y_in(Y_in[18]), .z_in(Z_in[18]), 
  .x_out(X_in[19]), .y_out(Y_in[19]), .z_out(Z_in[19])  
);

p_rhc #(.DATA_WIDTH(DATA_WIDTH), .ATANH(32'd4), .shift(14)) 
p_rhc_14 (
  .clk(clk), 
  .x_in(X_in[19]), .y_in(Y_in[19]), .z_in(Z_in[19]), 
  .x_out(X_in[20]), .y_out(Y_in[20]), .z_out(Z_in[20])  
);

p_rhc #(.DATA_WIDTH(DATA_WIDTH), .ATANH(32'd2), .shift(15)) 
p_rhc_15 (
  .clk(clk), 
  .x_in(X_in[20]), .y_in(Y_in[20]), .z_in(Z_in[20]), 
  .x_out(X_in[21]), .y_out(Y_in[21]), .z_out(Z_in[21])  
);

/*
  VLC iteration
*/

assign X_in[22] = (X_in[21] + Y_in[21] + (32'd1 << CORDIC_QUAN));
assign Y_in[22] = (32'd1 << CORDIC_QUAN);
assign Z_in[22] = 0;

genvar i;
generate
  for(i = 0; i <= 18; i=i+1) begin:vlc_iteration
    vlc #(
      .DATA_WIDTH   (DATA_WIDTH),
      .CORDIC_QUAN  (CORDIC_QUAN),
      .K            (i)
    ) vlc_ (
      .clk          (clk),
      .x_in         (X_in[22+i]),
      .y_in         (Y_in[22+i]),
      .z_in         (Z_in[22+i]),
      .x_out        (X_in[22+i + 1]),
      .y_out        (Y_in[22+i + 1]),
      .z_out        (Z_in[22+i + 1])
    );
  end
endgenerate

always @(posedge clk) begin
  D_out <= D_out_next;
end

always @(*) begin
  if(mode == 0)
    D_out_next = Z_in[41];
  else
    D_out_next = (32'd1 << CORDIC_QUAN) - (Z_in[41] << 1);
end


endmodule
