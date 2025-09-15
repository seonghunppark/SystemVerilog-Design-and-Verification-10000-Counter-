`timescale 1ns / 1ps
// ------------------ interface --------------------------

interface uart_tx_interface;

    logic       clk;
    logic       rst;
    logic [7:0] tx_data;
    logic       start_trigger;
    logic       tx;
    logic       tx_busy;


endinterface  //uart_tx_interface 

class transaction;
    // random value & input trigger
    rand logic [7:0] send_data;
    rand bit start_trigger;

    constraint trigger_c {
        start_trigger dist {
            1'b1 := 70,
            1'b0 := 30
        };
    }

    // monitored data
    logic [7:0] received_data;
    logic [7:0] tx_byte;
    bit         is_transmitted;

    task display(string name_s);
        $display("%t, [%s] send_data = %h", $time, name_s, send_data);

    endtask  //

endclass  //transaction

//--------------- generator -------------------
class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) gen2scb_mbox;
    event gen_next_event;

    int total_count = 0;

    function new(mailbox#(transaction) gen2drv_mbox,
                 mailbox#(transaction) gen2scb_mbox, event gen_next_event);
        this.gen2drv_mbox   = gen2drv_mbox;
        this.gen2scb_mbox   = gen2scb_mbox;
        this.gen_next_event = gen_next_event;
    endfunction  //new()

    task run(int count);
        repeat (count) begin
            total_count++;
            tr = new();
            assert (tr.randomize())
            else
                $error(
                    "=================[GEN] randomize() error!!==================="
                );

            gen2drv_mbox.put(tr);
            gen2scb_mbox.put(tr);
            tr.display("Generate Done");
            @gen_next_event;
        end

    endtask  //


endclass  //generator

// -------------------- driver --------------------------
class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual uart_tx_interface uart_tx_if;
    // event gen_next_event;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual uart_tx_interface uart_tx_if);

        this.gen2drv_mbox = gen2drv_mbox;
        this.uart_tx_if   = uart_tx_if;


    endfunction  //new()

    task reset();
        uart_tx_if.clk = 0;
        uart_tx_if.rst = 1;
        uart_tx_if.start_trigger = 0;
        uart_tx_if.tx_data = 0;
        repeat (2) @(posedge uart_tx_if.clk);
        uart_tx_if.rst = 0;
        repeat (2) @(posedge uart_tx_if.clk);
        $display("==================[Driver] reset done!=====================");
    endtask  //

    task run();
        forever begin
            gen2drv_mbox.get(tr);

            uart_tx_if.tx_data       = tr.send_data;
            uart_tx_if.start_trigger = 1;
            tr.display("Driver run");
            // ->gen_next_event;
            @(posedge uart_tx_if.clk);
            uart_tx_if.start_trigger = 0;
            wait (uart_tx_if.tx_busy == 1);
            wait (uart_tx_if.tx_busy == 0);

        end

    endtask  //


endclass  //driver

class monitor;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual uart_tx_interface uart_tx_if;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual uart_tx_interface uart_tx_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.uart_tx_if   = uart_tx_if;
    endfunction  //new()

    task monitor_tx_data();
        integer i;
        logic [7:0] tx_buffer;

        forever begin
            // wait for start bit 
            @(negedge uart_tx_if.tx);

            if (uart_tx_if.tx == 0) begin
                #(104167 / 2);

                for (i = 0; i < 8; i = i + 1) begin
                    #(104167);
                    tx_buffer[i] = uart_tx_if.tx;
                end
                #(104167);
                if (uart_tx_if.tx == 1) begin
                    tr = new();
                    tr.tx_byte = tx_buffer;
                    tr.is_transmitted = 1;
                    $display("%t [MONITOR] TX Data captured: %h", $time,
                             tr.tx_byte);
                    mon2scb_mbox.put(tr);
                end
            end
        end

    endtask  //

    task run();
        $display("%t [MONITOR] Monitor started", $time);
        monitor_tx_data();

    endtask  //

endclass  //monitor

class scoreboard;
    transaction tr_gen;
    transaction tr_tx;

    mailbox #(transaction) gen2scb_mbox;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_event;

    int total_tests = 0;
    int pass_count = 0;
    int fail_count = 0;

    function new(mailbox#(transaction) gen2scb_mbox,
                 mailbox#(transaction) mon2scb_mbox, event gen_next_event);

        this.gen2scb_mbox   = gen2scb_mbox;
        this.mon2scb_mbox   = mon2scb_mbox;
        this.gen_next_event = gen_next_event;
    endfunction  //new()

    task run();

        forever begin
            // Get generated data (expected data)
            gen2scb_mbox.get(tr_gen);
            total_tests++;

            // Wait for Tx data from monitor
            mon2scb_mbox.get(tr_tx);
            if (tr_gen.send_data == tr_tx.tx_byte) begin
                $display(
                    "%t [Scoreboard] Pass : TX Check - Expected data: %h, Received data: %h",
                    $time, tr_gen.send_data, tr_tx.tx_byte);
                pass_count++;
            end else begin
                $display(
                    "%t [Scoreboard] Fail : TX Check - Expected data: %h, Received data: %h",
                    $time, tr_gen.send_data, tr_tx.tx_byte);
                fail_count++;

            end

            $display("================ Next Generate ==================");
            ->gen_next_event;
        end
    endtask  //


endclass  //scoreboard


//----------------------- environment -----------------------
class environment;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) gen2scb_mbox;
    mailbox #(transaction) mon2scb_mbox;


    event                  gen_next_event;

    generator              gen;
    driver                 drv;
    monitor                mon;
    scoreboard             scb;


    function new(virtual uart_tx_interface uart_tx_if);
        gen2drv_mbox = new();
        gen2scb_mbox = new();
        mon2scb_mbox = new();

        gen = new(gen2drv_mbox, gen2scb_mbox, gen_next_event);
        drv = new(gen2drv_mbox, uart_tx_if);
        mon = new(mon2scb_mbox, uart_tx_if);
        scb = new(gen2scb_mbox, mon2scb_mbox, gen_next_event);


    endfunction  //new()

    task report();
        $display("===============================================");
        $display("================ Final Report =================");
        $display("================ Total gen : %d ===============",
                 gen.total_count);
        $display("================ Total Tests : %d =============",
                 scb.total_tests);
        $display("================ Total checks : %d ============",
                 scb.total_tests * 2);
        $display("================ passed checks : %d ===========",
                 scb.pass_count);
        $display("================ Failed checks : %d ===========",
                 scb.fail_count);
        $display("===============================================");




    endtask  //



    task reset();
        drv.reset();
    endtask  //

    task run();
        fork
            gen.run(100);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #(104167 * 20);

        report();
        $display("finished");
        $stop;

    endtask  //


endclass  //environment


module tb_uart_tx ();
    environment env;
    uart_tx_interface uart_tx_if_tb ();


    uart_tx_top dut (
        .clk(uart_tx_if_tb.clk),
        .rst(uart_tx_if_tb.rst),
        .tx_data(uart_tx_if_tb.tx_data),
        .start_trigger(uart_tx_if_tb.start_trigger),
        .tx(uart_tx_if_tb.tx),
        .tx_busy(uart_tx_if_tb.tx_busy)

    );

    always #5 uart_tx_if_tb.clk = ~uart_tx_if_tb.clk;

    initial begin
        env = new(uart_tx_if_tb);
        env.reset();
        env.run();
    end

endmodule
