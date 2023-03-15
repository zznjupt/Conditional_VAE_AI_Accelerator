// Single-Port Block RAM Write-First Mode (recommended template)
// File: rams_sp_wf.v
module rams_sp_wf #(
    parameter depth = 16,
    parameter data_width = 32,
    parameter addr_width = 32, // ceil(log(2, 16)), 32 is for default value
    parameter file_name = "rams_20c.data"
)(
    input wire clka,
    input wire wea,
    input wire [addr_width-1:0] addra,
    input wire [data_width-1:0] dina,
    output reg [data_width-1:0] douta
);

    reg [data_width-1:0] RAM [depth-1:0];

    always @(posedge clka) begin  
        if (wea) begin        
            RAM[addra] <= #2 dina;      
        end   
    end
    
    always @(posedge clka) begin  
        if (wea) begin              
            douta <= #1 dina;      
        end   
        else    
            douta <= #1 RAM[addra];  
    end

        
    task load_data(
        input [511:0] file_name
    );
        $readmemh(file_name, RAM);
    endtask

endmodule

