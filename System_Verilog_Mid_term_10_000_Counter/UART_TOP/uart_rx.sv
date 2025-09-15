`timescale 1ns / 1ps


module uart_rx (
    input  logic       clk,
    input  logic       rst,
    input  logic       b_tick,
    input  logic       rx,
    output logic [7:0] rx_data,
    output logic       rx_done
);

    localparam [1:0] IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;

    //state
    logic [1:0] state_reg, state_next;

    // baud tick count
    logic [4:0] b_tick_cnt_reg, b_tick_cnt_next;

    // bit count
    logic [3:0] bit_cnt_reg, bit_cnt_next;

    // rx done signal
    logic rx_done_reg, rx_done_next;

    // rx data buffer
    logic [7:0] rx_buff_reg, rx_buff_next;

    // output 
    assign rx_data = rx_buff_reg;
    assign rx_done = rx_done_reg;

    // Sequencial Logic : Reset and Update
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            state_reg <= IDLE;
            b_tick_cnt_reg <= 0;
            bit_cnt_reg <= 0;
            rx_done_reg <= 0;
            rx_buff_reg <= 0;
        end else begin
            state_reg <= state_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg <= bit_cnt_next;
            rx_done_reg <= rx_done_next;
            rx_buff_reg <= rx_buff_next;
        end
    end

    always_comb begin
        state_next = state_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next = bit_cnt_reg;
        rx_done_next = rx_done_reg;
        rx_buff_next = rx_buff_reg;
        case (state_reg)
            IDLE: begin
                rx_done_next = 0;
                if (b_tick) begin
                    if (!rx) begin
                        b_tick_cnt_next = 0;
                        state_next = START;
                    end
                end

            end
            START: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 23) begin
                        bit_cnt_next = 0;
                        b_tick_cnt_next = 0;
                        state_next = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 0) begin
                        rx_buff_next[7] = rx;
                    end
                    if (b_tick_cnt_reg == 15) begin
                        if (bit_cnt_reg == 7) begin
                            state_next = STOP;
                        end else begin
                            b_tick_cnt_next = 0;
                            bit_cnt_next = bit_cnt_reg + 1;
                            rx_buff_next = rx_buff_reg >> 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end


                end

            end
            STOP: begin
                if (b_tick) begin
                    rx_done_next = 1'b1;
                    state_next   = IDLE;
                end

            end
        endcase






    end




endmodule
