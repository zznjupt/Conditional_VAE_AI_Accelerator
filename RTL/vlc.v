// 线性CORDIC的向量模式计算除法
// vector mode of linear CORDIC (VLC)
module vlc # (
    parameter        DATA_WIDTH  = 32,
    parameter signed CORDIC_QUAN = 16,
    parameter        K           = 0
) (
    input  wire                             clk,
    input  wire signed [DATA_WIDTH-1:0]     x_in,
    input  wire signed [DATA_WIDTH-1:0]     y_in,
    input  wire signed [DATA_WIDTH-1:0]     z_in,

    output reg  signed [DATA_WIDTH-1:0]     x_out,
    output reg  signed [DATA_WIDTH-1:0]     y_out,
    output reg  signed [DATA_WIDTH-1:0]     z_out
);

reg  signed [DATA_WIDTH-1:0] y_out_next;
reg  signed [DATA_WIDTH-1:0] z_out_next;
wire signed [DATA_WIDTH-1:0] shift; 


always @(posedge clk) begin
    x_out <= x_in;
end

always @(posedge clk) begin
    y_out <= y_out_next;
end

always @(posedge clk) begin
    z_out <= z_out_next;
end

always @(*) begin
    if(y_in[DATA_WIDTH-1] == 1)
        y_out_next = y_in + (x_in >>> K);
    else 
        y_out_next = y_in - (x_in >>> K); 
end

assign shift = (1 << CORDIC_QUAN);

always @(*) begin
    if(y_in[DATA_WIDTH-1] == 1)
        z_out_next = z_in - (shift >>> K);
    else 
        z_out_next = z_in + (shift >>> K); 
end

endmodule