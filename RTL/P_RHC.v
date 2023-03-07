// 双曲CORDIC的旋转模式计算自然指数函数
// rotation mode of hyperbolic CORDIC (RHC)
module P_RHC #(
    parameter           DATA_WIDTH  = 32,
    parameter signed    ATANH       = 32'd35999,
    parameter           shift       = 0
)(
    input  wire                         clk,
    input  wire signed [DATA_WIDTH-1:0] x_in,
    input  wire signed [DATA_WIDTH-1:0] y_in,
    input  wire signed [DATA_WIDTH-1:0] z_in,

    output reg  signed [DATA_WIDTH-1:0] x_out,
    output reg  signed [DATA_WIDTH-1:0] y_out,
    output reg  signed [DATA_WIDTH-1:0] z_out
);

reg  signed [DATA_WIDTH-1:0] x_out_next, y_out_next, z_out_next;
wire signed [DATA_WIDTH-1:0] shift_x, shift_y;

always @(posedge clk) begin
    x_out <= x_out_next;
end

always @(posedge clk) begin
    y_out <= y_out_next;
end

always @(posedge clk) begin
    z_out <= z_out_next;
end

assign shift_x = x_in >>> shift;
assign shift_y = y_in >>> shift;

always @(*) begin
    if(z_in[DATA_WIDTH-1] == 1)
        x_out_next = x_in - shift_y;
    else 
        x_out_next = x_in + shift_y; 
end

always @(*) begin
    if(z_in[DATA_WIDTH-1] == 1)
        y_out_next = y_in - shift_x;
    else 
        y_out_next = y_in + shift_x; 
end


always @(*) begin
    if(z_in[DATA_WIDTH-1] == 1)
        z_out_next = z_in + ATANH;
    else 
        z_out_next = z_in - ATANH; 
end

endmodule