`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.07.2025 22:52:15
// Design Name: 
// Module Name: FIFO
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fifo #(
    parameter data_width = 32,
    parameter fifo_depth = 16
)(
    input wire clk,
    input wire reset,
    input wire wr_en,
    input wire rd_en,
    input wire [data_width-1:0] wr_data,
    output reg [data_width-1:0] rd_data,
    output reg empty,
    output reg full
);

reg [data_width-1:0] mem [0:fifo_depth-1];
reg [3:0] wr_ptr, rd_ptr, cnt;

always @(posedge clk) begin
    if (reset) wr_ptr <= 0;
    else if (wr_en && !full) begin
        mem[wr_ptr] <= wr_data;
        wr_ptr <= (wr_ptr + 1) % fifo_depth;
    end
end

always @(posedge clk) begin
    if (reset) begin
        rd_ptr <= 0;
        rd_data <= 0;
    end else if (rd_en && !empty) begin
        rd_data <= mem[rd_ptr];
        rd_ptr <= (rd_ptr + 1) % fifo_depth;
    end
end

always @(posedge clk) begin
    if (reset) begin
        cnt <= 0;
        empty <= 1;
        full <= 0;
    end else begin
        case ({wr_en && !full, rd_en && !empty})
            2'b10: cnt <= cnt + 1;
            2'b01: cnt <= cnt - 1;
        endcase
        empty <= (cnt == 0);
        full  <= (cnt == fifo_depth);
    end
end

endmodule
