module GRU # (
    parameter DATA_WIDTH    = 32, 
    parameter QUAN          = 24,
    parameter CORDIC_QUAN   = 16
) (
    input  wire                         clk,
    input  wire signed [DATA_WIDTH-1:0] data_ir,
    input  wire signed [DATA_WIDTH-1:0] data_iz,
    input  wire signed [DATA_WIDTH-1:0] data_in,
    input  wire signed [DATA_WIDTH-1:0] data_hr,
    input  wire signed [DATA_WIDTH-1:0] data_hz,
    input  wire signed [DATA_WIDTH-1:0] data_hn,
    input  wire signed [DATA_WIDTH-1:0] data_hidden_in,

    output reg  signed [DATA_WIDTH-1:0] data_hidden_out
);

wire signed [DATA_WIDTH-1:0] R_reg, Z_reg, T_reg;
reg  signed [DATA_WIDTH-1:0] R_add_reg, Z_add_reg, Z_reg_buffer;
reg  signed [DATA_WIDTH-1:0] N_reg;
reg  signed [DATA_WIDTH-1:0] T_add_reg;
reg  signed [DATA_WIDTH-1:0] Z_minus_reg;
reg  signed [DATA_WIDTH-1:0] T_cross_reg, Z_cross_reg;

cordic # (
    .DATA_WIDTH     (DATA_WIDTH),
    .CORDIC_QUAN    (16),
    .X_0            (32'd704813465),
    .Y_0            (0),
    .mode           (0)
) sigmoid_0 (
    .clk            (clk),
    .D_in           (R_add_reg),
    .D_out          (R_reg)
);

cordic # (
    .DATA_WIDTH     (DATA_WIDTH),
    .CORDIC_QUAN    (16),
    .X_0            (32'd704813465),
    .Y_0            (0),
    .mode           (0)
) sigmoid_1 (
    .clk            (clk),
    .D_in           (Z_add_reg),
    .D_out          (Z_reg)
);


cordic # (
    .DATA_WIDTH     (DATA_WIDTH),
    .CORDIC_QUAN    (16),
    .X_0            (32'd704813465),
    .Y_0            (0),
    .mode           (1)
) tanh (
    .clk            (clk),
    .D_in           (T_add_reg),
    .D_out          (T_reg)
);

reg signed [DATA_WIDTH-1:0] R_add_reg_next, R_add_reg_temp;

always @(posedge clk) begin
    R_add_reg <=  R_add_reg_next;
end
always @(*) begin
    R_add_reg_temp = (data_hr + data_ir);
    R_add_reg_next = {{8{R_add_reg_temp[31]}}, R_add_reg_temp[8+:24]};
end

reg signed [DATA_WIDTH-1:0] Z_add_reg_next, Z_add_reg_temp;

always @(posedge clk) begin
    Z_add_reg <=  Z_add_reg_next;
end
always @(*) begin
    Z_add_reg_temp = (data_iz + data_hz);
    Z_add_reg_next = {{8{Z_add_reg_temp[31]}}, Z_add_reg_temp[8+:24]};
end

reg signed [63:0] N_part;
reg signed [63:0] N_part_temp;
always @(posedge clk) begin
    //N_reg <= ((R_reg << (QUAN - CORDIC_QUAN)) >>> (QUAN/2)) * (data_hn >>> (QUAN/2));
    N_reg <= N_part[24+:32];
end
always @(*) begin
    N_part_temp = {R_reg[0+:24], 8'b0};
    N_part = N_part_temp * data_hn;
end

reg signed [DATA_WIDTH-1:0] T_add_reg_next, T_add_reg_temp;
always @(posedge clk) begin
    T_add_reg <= T_add_reg_next;
end
always @(*) begin
    T_add_reg_temp = (data_in + N_reg);
    T_add_reg_next = {{8{T_add_reg_temp[31]}}, T_add_reg_temp[8+:24]};
end

reg signed [DATA_WIDTH-1:0] Z_minus_reg_next,Z_minus_reg_temp;
always @(posedge clk) begin
    Z_minus_reg <= Z_minus_reg_next;
end
always @(*) begin
    Z_minus_reg_temp = {Z_reg[0+:24], 8'b0};
    Z_minus_reg_next = $signed(32'h0100_0000) - Z_minus_reg_temp;
end


reg signed [63:0] T_cross_part;
reg signed [31:0] T_cross_temp;
always @(posedge clk) begin
    //T_cross_reg <= ((T_reg << (QUAN - CORDIC_QUAN)) >>> (QUAN/2)) * (Z_minus_reg >>> (QUAN/2));
    T_cross_reg <= T_cross_part[24+:32];
end

always @(*) begin
    T_cross_temp = {T_reg[0+:24], 8'b0};
    T_cross_part = T_cross_temp * Z_minus_reg;
end


always @(posedge clk) begin
    Z_reg_buffer <= Z_reg;
end
reg signed [63:0] Z_cross_part;
reg signed [31:0] Z_cross_temp;
always @(posedge clk) begin
    //Z_cross_reg <= ((Z_reg_buffer << (QUAN - CORDIC_QUAN)) >>> (QUAN/2)) * (data_hidden_in >>> (QUAN/2));
    Z_cross_reg <= Z_cross_part[24+:32];
end

always @(*) begin
    Z_cross_temp = {Z_reg_buffer[0+:24], 8'b0};
    Z_cross_part = Z_cross_temp * data_hidden_in;
end

always @(posedge clk) begin
    data_hidden_out <= T_cross_reg + Z_cross_reg;
end

endmodule