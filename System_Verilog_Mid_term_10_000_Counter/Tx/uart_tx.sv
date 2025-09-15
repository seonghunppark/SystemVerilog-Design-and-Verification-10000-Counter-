`timescale 1ns / 1ps

module uart_tx_top (
    input  logic       clk,
    input  logic       rst,
    input  logic [7:0] tx_data,
    input  logic       start_trigger,
    output logic       tx,
    output logic       tx_busy

);

    logic w_b_tick;

    Baud_tick_gen_9600 U_B_TICK_GEN (
        .clk   (clk),
        .rst   (rst),
        .b_tick(w_b_tick)
    );

    uart_tx U_UART_TX (
        .clk          (clk),
        .rst          (rst),
        .start_trigger(start_trigger),
        .tx_data      (tx_data),
        .b_tick       (w_b_tick),
        .tx           (tx),
        .tx_busy      (tx_busy)
    );



endmodule



module uart_tx (
    input  logic       clk,
    input  logic       rst,
    input  logic       start_trigger,
    input  logic [7:0] tx_data,
    input  logic       b_tick,
    output logic       tx,
    output logic       tx_busy
);

    // fsm state
    localparam [2:0] IDLE = 3'h0, WAIT = 3'h1, START = 3'h2, DATA = 3'h3, STOP = 3'h4;


    // state 
    logic [2:0] state, next;
    // bit control reg
    logic [2:0] bit_cnt_reg, bit_cnt_next;
    // tx internal buffer 
    logic [7:0] data_reg, data_next;
    // b_tick count
    logic [3:0] b_tick_cnt_reg, b_tick_cnt_next;


    logic tx_busy_reg, tx_busy_next;
    assign tx_busy = tx_busy_reg;
    // output
    logic tx_reg, tx_next;
    // output tx
    assign tx = tx_reg;

    // state register
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            state          <= IDLE;
            tx_reg         <= 1'b1;  // idle output is high 
            b_tick_cnt_reg <= 0;
            bit_cnt_reg    <= 0;
            data_reg       <= 0;
            tx_busy_reg    <= 0;
        end else begin
            state          <= next;
            tx_reg         <= tx_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            data_reg       <= data_next;
            tx_busy_reg    <= tx_busy_next;
        end
    end

    // next combinational logic
    always_comb begin
        // to remove latch
        next            = state;
        tx_next         = tx_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;
        data_next       = data_reg;
        tx_busy_next    = tx_busy_reg;
        case (state)
            IDLE: begin
                //output tx
                tx_next      = 1'b1;
                data_next    = tx_data;
                tx_busy_next = 1'b0;
                if (start_trigger == 1'b1) begin
                    tx_busy_next = 1'b1;
                    next = WAIT;
                end
            end

            WAIT: begin
                if (b_tick) begin
                    b_tick_cnt_next = 0;
                    next = START;
                end
            end

            START: begin
                //output tx
                tx_next = 1'b0;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        bit_cnt_next    = 0;
                        next            = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end

                end
            end

            DATA: begin
                // output tx <= tx_data[0]
                tx_next = data_reg[0];
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        if (bit_cnt_reg == 7) begin
                            next = STOP;
                        end else begin

                            bit_cnt_next = bit_cnt_reg + 1;
                            // next = DATA; whatever it's okay 
                            data_next = data_reg >> 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end

            STOP: begin
                tx_next = 1'b1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        tx_busy_next = 1'b0;
                        next = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end

                end
            end


        endcase

    end

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
