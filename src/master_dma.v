`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.07.2025 22:52:15
// Design Name: 
// Module Name: DMA
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

module master_dma(
    input wire clk,
    input wire reset,
    input wire trigger,
    input wire [4:0] length,
    input wire [31:0] source_address,
    input wire [31:0] destination_address,
    output reg done,

    // AXI Read Address Channel
    output reg [31:0] ARADDR,
    output reg ARVALID,
    input wire ARREADY,

    // AXI Read Data Channel
    input wire [31:0] RDATA,
    input wire RVALID,
    output reg RREADY,

    // AXI Write Address Channel
    output reg [31:0] AWADDR,
    output reg AWVALID,
    input wire AWREADY,

    // AXI Write Data Channel
    output reg [31:0] WDATA,
    output reg WVALID,
    input wire WREADY,

    // Write Response Channel
    input wire BVALID,
    output reg BREADY,

    // FIFO Interface
    output reg fifo_wr_en,
    output reg fifo_rd_en,
    output reg [31:0] fifo_din,
    input wire [31:0] fifo_dout,
    input wire fifo_full,
    input wire fifo_empty,

    // Debug Signals
    output reg [31:0] wr_data_buf,
    output reg [4:0] read_count,
    output reg [4:0] write_count,
    output reg read_done,
    output reg write_done
);

// FSM state definitions
parameter
    READ_IDLE        = 3'd0,
    READ_ADDR_PHASE  = 3'd1,
    WAIT_READ_DATA   = 3'd2,
    FIFO_WRITE       = 3'd3,
    READ_INCR_ADDR   = 3'd4,
    READ_DONE        = 3'd5;

parameter
    WRITE_IDLE        = 3'd0,
    WRITE_RD_FIFO     = 3'd1,
    WRITE_BUFFER_WAIT = 3'd2,
    WRITE_ADDR_PHASE  = 3'd3,
    WRITE_DATA_PHASE  = 3'd4,
    WAIT_WRITE_RESP   = 3'd5,
    WRITE_DONE        = 3'd6;

// Internal state and buffer registers
reg [2:0] read_state, write_state;
reg [31:0] current_read_addr, current_write_addr;
reg fifo_data_valid;

//  reg [31:0] wr_data_buf;
//  reg [4:0] read_count;
//  reg [4:0] write_count;
//  reg read_done;
//  reg write_done ;

// ------------------
// READ FSM
// ------------------
always @(posedge clk) begin
    if (reset) begin
        read_state <= READ_IDLE;
        read_count <= 0;
        current_read_addr <= 0;
        ARVALID <= 0;
        RREADY <= 0;
        fifo_wr_en <= 0;
        fifo_din <= 0;
        read_done <= 0;
        ARADDR <= 0;
    end else begin
        ARVALID <= 0;
        RREADY <= 0;
        fifo_wr_en <= 0;

        case (read_state)
            READ_IDLE: begin
                if (trigger) begin
                    current_read_addr <= source_address;
                    read_count <= 0;
                    read_done <= 0;
                    read_state <= READ_ADDR_PHASE;
                end
            end

            READ_ADDR_PHASE: begin
                if (!ARVALID && !fifo_full) begin
                    ARADDR <= current_read_addr;
                    ARVALID <= 1;
                end else if (ARVALID && ARREADY) begin
                    ARVALID <= 0;
                    read_state <= WAIT_READ_DATA;
                end
            end

            WAIT_READ_DATA: begin
                if (RVALID && !fifo_full) begin
                    RREADY <= 1;
                    read_state <= FIFO_WRITE;
                end
            end

            FIFO_WRITE: begin
                fifo_din <= RDATA;
                fifo_wr_en <= 1;
                read_state <= READ_INCR_ADDR;
            end

            READ_INCR_ADDR: begin
                read_count <= read_count + 1;
                current_read_addr <= current_read_addr + 4;
                read_state <= (read_count == (length >> 2) - 1) ? READ_DONE : READ_ADDR_PHASE;
            end

            READ_DONE: read_done <= 1;
        endcase
    end
end

// ------------------
// WRITE FSM
// ------------------
always @(posedge clk) begin
    if (reset) begin
        write_state <= WRITE_IDLE;
        current_write_addr <= 0;
        write_count <= 0;
        fifo_rd_en <= 0;
        AWADDR <= 0;
        AWVALID <= 0;
        WVALID <= 0;
        WDATA <= 0;
        BREADY <= 0;
        write_done <= 0;
        done <= 0;
        fifo_wr_en <= 0;
           wr_data_buf <= 0 ;
    end else begin
        fifo_rd_en <= 0;
        AWVALID <= 0;
        WVALID <= 0;
        BREADY <= 0;

        case (write_state)
            WRITE_IDLE: begin
                if (!fifo_empty ) begin
                    write_count <= 0;
                    write_done <= 0;
                    wr_data_buf <= 0 ;
                    current_write_addr <= destination_address;
                    write_state <= WRITE_RD_FIFO;
                end
            end

            WRITE_RD_FIFO: begin
                if (!fifo_empty) begin
                    fifo_rd_en <= 1;
                    fifo_data_valid <= 1;
                    write_state <= WRITE_BUFFER_WAIT;
                end
            end

            WRITE_BUFFER_WAIT: write_state <= WRITE_ADDR_PHASE;

            WRITE_ADDR_PHASE: begin
                if (fifo_data_valid) begin
                    wr_data_buf <= fifo_dout;
                    fifo_data_valid <= 0;
                end
                AWADDR <= current_write_addr;
                AWVALID <= 1;
                if (AWREADY && AWVALID) begin
                    AWVALID <= 0;
                    write_state <= WRITE_DATA_PHASE;
                end
            end

//WRITE_ADDR_PHASE: begin
//                    if (fifo_data_valid) begin
//                    wr_data_buf <= fifo_dout;
//                    fifo_data_valid <= 0;
//                end

//    if (!AWVALID) begin
//        AWADDR  <= current_write_addr;
//        AWVALID <= 1;
//    end else if (AWREADY) begin
//        AWVALID <= 0;
//        write_state <= WRITE_DATA_PHASE;
//    end
//end


            WRITE_DATA_PHASE: begin
                WDATA <= wr_data_buf;
                WVALID <= 1;
                if (WREADY) begin
                    WVALID <= 0;
                    write_state <= WAIT_WRITE_RESP;
                end
            end

            WAIT_WRITE_RESP: begin
                BREADY <= 1;
                if (BVALID && BREADY) begin
                    write_count <= write_count + 1;
                    current_write_addr <= current_write_addr + 4;
                    if ((write_count + 1) == (length >> 2))
                        write_state <= WRITE_DONE;
                    else
                        write_state <= WRITE_RD_FIFO;
                end
            end

            WRITE_DONE: begin
                if (write_count == (length >> 2)) begin
                    write_done <= 1;
                end
                if (read_done && write_done) begin
                    done <= 1;
                end
            end
        endcase
    end
end

endmodule