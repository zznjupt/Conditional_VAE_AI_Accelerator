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

np_rhc #(.DATA_WIDTH(DATA_WIDTH), .M_ATANH(32'd386121), .shift(16)) 
np_rhc_0 (
  .clk(clk), 
  .x_in(X_in[0]), .y_in(Y_in[0]), .z_in(Z_in[0]), 
  . x_out(X_in[1]), .y_out(Y_in[1]), .z_out(Z_in[1])  
);

np_rhc #(.DATA_WIDTH(DATA_WIDTH), .M_ATANH(32'd204353), .shift(8)) 
np_rhc_1 (
  .clk(clk), 
  .x_in(X_in[1]), .y_in(Y_in[1]), .z_in(Z_in[1]), 
  . x_out(X_in[2]), .y_out(Y_in[2]), .z_out(Z_in[2])  
);

np_rhc #(.DATA_WIDTH(DATA_WIDTH), .M_ATANH(32'd112542), .shift(4)) 
np_rhc_2 (
  .clk(clk), 
  .x_in(X_in[2]), .y_in(Y_in[2]), .z_in(Z_in[2]), 
  . x_out(X_in[3]), .y_out(Y_in[3]), .z_out(Z_in[3])  
);

np_rhc #(.DATA_WIDTH(DATA_WIDTH), .M_ATANH(32'd63763), .shift(2)) 
np_rhc_3 (
  .clk(clk), 
  .x_in(X_in[3]), .y_in(Y_in[3]), .z_in(Z_in[3]), 
  . x_out(X_in[4]), .y_out(Y_in[4]), .z_out(Z_in[4])  
);

p_rhc #(.DATA_WIDTH(DATA_WIDTH), .ATANH(32'd35999), .shift(1)) 
p_rhc_1 (
  .clk(clk), 
  .x_in(X_in[0]), .y_in(Y_in[0]), .z_in(Z_in[0]), 
  . x_out(X_in[1]), .y_out(Y_in[1]), .z_out(Z_in[1])  
);



endmodule
