`timescale 1ns / 1ps

module uart_top (
    input  logic       clk,
    input  logic       rst,
    input  logic       rx,
    output logic [7:0] rx_data,
    output logic       start_trigger,
    output logic       tx


);


    logic w_b_tick;
    logic [7:0] w_rx_data, w_rx_rdata, w_tx_data;
    logic w_rx_done, w_empty, w_tx_rx_full;
    logic w_busy, w_tx_empty;



    assign start_trigger = ~w_empty;
    assign rx_data = w_rx_rdata;

    uart_tx U_UART_TX (
        .clk(clk),
        .rst(rst),
        .start_trigger(~w_tx_empty),
        .tx_data(w_tx_data),
        .b_tick(w_b_tick),
        .tx(tx),
        .tx_busy(w_busy)
    );

    fifo U_TX_FIFO (
        .clk(clk),
        .rst(rst),
        .wr(~w_empty),
        .rd(~w_busy),
        .wdata(w_rx_rdata),
        .rdata(w_tx_data),
        .full(w_tx_rx_full),
        .empty(w_tx_empty)
    );




    fifo U_RX_FIFO (
        .clk(clk),
        .rst(rst),
        .wr(w_rx_done),
        .rd(~w_tx_rx_full),
        .wdata(w_rx_data),
        .rdata(w_rx_rdata),
        .full(w_full),
        .empty(w_empty)
    );
    // 
    uart_rx U_UART_RX (
        .clk(clk),
        .rst(rst),
        .b_tick(w_b_tick),
        .rx(rx),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );

    Baud_tick_gen_9600 U_BAUD_TICK (
        .clk(clk),
        .rst(rst),
        .b_tick(w_b_tick)
    );



endmodule


module Baud_tick_gen_9600 (
    input  clk,
    input  rst,
    output b_tick
);

    localparam BAUDRATE = 9600 * 16;
    localparam BAUD_count = 100_000_000 / BAUDRATE;
    logic [$clog2(BAUD_count)-1:0] count_reg, count_next;
    logic tick_reg, tick_next;
    assign b_tick = tick_reg;


    // Sequencial Logic : Reset and Update
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            count_reg <= 0;
            tick_reg  <= 0;
        end else begin
            count_reg <= count_next;
            tick_reg  <= tick_next;
        end
    end

    always_comb begin
        count_next = count_reg;
        tick_next  = tick_reg;
        if (count_reg == BAUD_count) begin
            count_next = 0;
            tick_next  = 1'b1;
        end else begin
            count_next = count_reg + 1;
            tick_next  = 1'b0;
        end
    end




endmodule
