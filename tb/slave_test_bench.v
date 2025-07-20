`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.07.2025 22:52:15
// Design Name: 
// Module Name: TB
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


module test;

    // Clock and control signals
    reg clk, reset, trigger;

    // DMA configuration inputs
    reg [4:0]  length;
    reg [31:0] source_address;
    reg [31:0] destination_address;
    wire done;

    // AXI Read Address Channel
    wire [31:0] ARADDR;
    wire        ARVALID;
    reg         ARREADY;

    // AXI Read Data Channel
    reg  [31:0] RDATA;
    reg         RVALID;
    wire        RREADY;

    // AXI Write Address Channel
    wire [31:0] AWADDR;
    wire        AWVALID;
    reg         AWREADY;

    // AXI Write Data Channel
    wire [31:0] WDATA;
    wire        WVALID;
    reg         WREADY;

    // AXI Write Response Channel
    reg         BVALID;
    wire        BREADY;

    // FIFO signals
    wire        fifo_wr_en, fifo_rd_en;
    wire [31:0] fifo_din, fifo_dout;
    wire        fifo_full, fifo_empty;

    // Debug signals
    wire [31:0] wr_data_buf;
    wire [4:0]  read_count, write_count;
    wire        read_done, write_done;

    // Simple test memory model
    reg [31:0] memory [0:4095];

    // Instantiate the DMA module
    master_dma DMA (
        .clk(clk),
        .reset(reset),
        .trigger(trigger),
        .length(length),
        .source_address(source_address),
        .destination_address(destination_address),
        .done(done),

        .ARADDR(ARADDR),
        .ARVALID(ARVALID),
        .ARREADY(ARREADY),

        .RDATA(RDATA),
        .RVALID(RVALID),
        .RREADY(RREADY),

        .AWADDR(AWADDR),
        .AWVALID(AWVALID),
        .AWREADY(AWREADY),

        .WDATA(WDATA),
        .WVALID(WVALID),
        .WREADY(WREADY),

        .BVALID(BVALID),
        .BREADY(BREADY),

        .fifo_wr_en(fifo_wr_en),
        .fifo_rd_en(fifo_rd_en),
        .fifo_din(fifo_din),
        .fifo_dout(fifo_dout),
        .fifo_full(fifo_full),
        .fifo_empty(fifo_empty),

        .wr_data_buf(wr_data_buf),
        .read_count(read_count),
        .write_count(write_count),
        .read_done(read_done),
        .write_done(write_done)
    );

    // Instantiate FIFO buffer
    fifo fifo_inst (
        .clk(clk),
        .reset(reset),
        .wr_en(fifo_wr_en),
        .rd_en(fifo_rd_en),
        .wr_data(fifo_din),
        .rd_data(fifo_dout),
        .empty(fifo_empty),
        .full(fifo_full)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Initial simulation setup
    initial begin
        clk = 0;
        reset = 1;
        trigger = 0;
        ARREADY = 0;
        RVALID = 0;
        AWREADY = 0;
        WREADY = 0;
        BVALID = 0;
        RDATA = 0;

        // Initialize memory with source data
        memory[32'h1000 >> 2] = 32'hAABBCCDD;
        memory[32'h1004 >> 2] = 32'h11223344;
        memory[32'h1008 >> 2] = 32'h55667788;
        memory[32'h100C >> 2] = 32'h99AABBCC;

        #20 reset = 0;

        // Set DMA transfer parameters
        source_address      = 32'h1000;
        destination_address = 32'h2000;
        length              = 5'd16;

        #10 trigger = 1;
        #10 trigger = 0;
    end

    // Read response simulation logic (AXI Read FSM behavior)
    reg [1:0] read_state;
    localparam READ_IDLE  = 2'b00,
               READ_RESP  = 2'b01;

    always @(posedge clk) begin
        if (reset) begin
            ARREADY    <= 0;
            RVALID     <= 0;
            RDATA      <= 32'b0;
            read_state <= READ_IDLE;
        end else begin
            case (read_state)
                READ_IDLE: begin
                    if (!read_done) begin
                        ARREADY <= 1;
                        if (ARVALID) begin
                            RDATA <= memory[ARADDR >> 2];
                            ARREADY <= 0;
                            read_state <= READ_RESP;
                        end
                    end else begin
                        ARREADY <= 0;
                    end
                end

                READ_RESP: begin
                    RVALID <= 1;
                    if (RREADY) begin
                        RVALID <= 0;
                        read_state <= READ_IDLE;
                    end
                end
            endcase
        end
    end

    // Write response simulation logic (AXI Write FSM behavior)
    reg aw_received = 0;
    reg w_received  = 0;
    reg [31:0] stored_awaddr;
    reg [31:0] stored_wdata;

    always @(posedge clk) begin
        if (reset) begin
            AWREADY        <= 0;
            WREADY         <= 0;
            BVALID         <= 0;
            aw_received    <= 0;
            w_received     <= 0;
            stored_awaddr  <= 0;
            stored_wdata   <= 0;
        end else begin
            AWREADY <= 0;
            WREADY  <= 0;

            if (!aw_received && AWVALID) AWREADY <= 1;
            if (!w_received  && WVALID)  WREADY  <= 1;

            if (AWVALID && AWREADY) begin
                stored_awaddr <= AWADDR;
                aw_received <= 1;
            end

            if (WVALID && WREADY) begin
                stored_wdata <= WDATA;
                w_received <= 1;
            end

            if (aw_received && w_received && !BVALID) begin
                memory[stored_awaddr >> 2] <= stored_wdata;
                BVALID <= 1;
                aw_received <= 0;
                w_received  <= 0;
            end

            if (BVALID && BREADY) BVALID <= 0;
        end
    end

    // Debugging FIFO activity
    always @(posedge clk) begin
        if (fifo_wr_en)
            $display("Time %0t: FIFO WRITE = %h", $time, fifo_din);
        if (fifo_rd_en)
            $display("Time %0t: FIFO READ  = %h", $time, fifo_dout);
    end

    // Updated signal monitor
    initial begin
        $monitor("T=%0t | clk=%b reset=%b trigger=%b done=%b | len=%d src=0x%h dst=0x%h\nAR: ARVALID=%b ARREADY=%b ARADDR=0x%h | R: RVALID=%b RREADY=%b RDATA=0x%h\nAW: AWVALID=%b AWREADY=%b AWADDR=0x%h | W: WVALID=%b WREADY=%b WDATA=0x%h\nB: BVALID=%b BREADY=%b",
            $time, clk, reset, trigger, done, length, source_address, destination_address,
            ARVALID, ARREADY, ARADDR, RVALID, RREADY, RDATA,
            AWVALID, AWREADY, AWADDR, WVALID, WREADY, WDATA,
            BVALID, BREADY);

        #600;
        $display("\n--- Final Destination Memory (0x2000 - 0x200C) ---");
        $display("0x2000: %h", memory[32'h2000 >> 2]);
        $display("0x2004: %h", memory[32'h2004 >> 2]);
        $display("0x2008: %h", memory[32'h2008 >> 2]);
        $display("0x200C: %h", memory[32'h200C >> 2]);
        $finish;
    end

endmodule