`timescale 1ns / 1ps

// ------------- interface ----------------------

interface uart_top_interface;
    logic       clk;
    logic       rst;
    logic       rx;
    logic [7:0] rx_data;
    logic       start_trigger;
    logic       tx;


endinterface  //uart_top_interface

// --------------- transaction ------------------

class transaction;
    // random stimulus
    rand logic [7:0] send_data; 
    logic rx;
    

    // monitored data
    logic [7:0] received_data;
    logic [7:0] tx_data;
    bit is_received;
    bit is_transmitted;


    task display(string name_s);
        $display("%t, [%s] send_data = %h, received_data = %h, tx_data =%h",
                 $time, name_s, send_data, received_data, tx_data);
    endtask  //



endclass  //transaction

//-------------- generator ----------------
class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;  // mailbox with driver
    mailbox #(transaction) gen2scb_mbox; // mailbox with scoreboard (compare gen data with expected data)
    event gen_next_event;

    int total_count = 0;

    // 외부와의 연결
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
            else $error("[GEN] randomize() error!!");


            gen2drv_mbox.put(tr);
            gen2scb_mbox.put(tr);
            tr.display("GEN done");
            @gen_next_event;
        end

    endtask  //
endclass  //generator

//-------------- driver -----------------------
class driver;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual uart_top_interface uart_if;
    event gen_next_event;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_event,
                 virtual uart_top_interface uart_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_event = gen_next_event;
        this.uart_if = uart_if;
    endfunction  //new()


    task reset();
        uart_if.clk = 0;
        uart_if.rst = 1;
        uart_if.rx  = 1;
        repeat (2) @(posedge uart_if.clk);
        uart_if.rst = 0;
        repeat (2) @(posedge uart_if.clk);
        $display("-------------[DRV] reset done!---------------");
    endtask  //

    task send_uart();
        integer i;
        begin
            uart_if.rx = 0;
            #(104166);

            for (i = 0; i < 8; i = i + 1) begin
                uart_if.rx = tr.send_data[i];
                #(104166);
            end

            uart_if.rx = 1;
            #(104166);
            $display("%t [DRV] send UART data: %h", $time, tr.send_data);
        end
    endtask


    task run();
        forever begin
            gen2drv_mbox.get(tr);
            tr.display("DRV");
            send_uart();
            ->gen_next_event;
            @(posedge uart_if.clk);
        end

    endtask  //

endclass  //driver

class monitor;
    transaction tr_rx;
    transaction tr_tx;
    mailbox #(transaction) mon2scb_rx_mbox;
    mailbox #(transaction) mon2scb_tx_mbox;
    virtual uart_top_interface uart_if;
    


    function new(mailbox#(transaction) mon2scb_rx_mbox,
                 mailbox#(transaction) mon2scb_tx_mbox,
                 virtual uart_top_interface uart_if);
        this.mon2scb_rx_mbox = mon2scb_rx_mbox;
        this.mon2scb_tx_mbox = mon2scb_tx_mbox;
        this.uart_if = uart_if;
    endfunction  //new()

    // Monitor Rx data from DUT
    task monitor_rx_data();
        forever begin
            
            @(posedge uart_if.start_trigger);  //wait for data to be available
            tr_rx = new();
            tr_rx.received_data = uart_if.rx_data;  // DUT rx_data
            tr_rx.is_received = 1;
            $display("%t [MON] RX DATA captured: %h", $time,
                     tr_rx.received_data);
            mon2scb_rx_mbox.put(tr_rx);
        end
    endtask  //

    // Monitor Tx data from DUT
    task monitor_tx_data();
        integer i;
        logic [7:0] tx_byte;

        forever begin
            // wait for start bit

            @(negedge uart_if.tx);
            #(104166 / 2);

            if (uart_if.tx == 0) begin
                #(104166);

                for (i = 0; i < 8; i = i + 1) begin
                    tx_byte[i] = uart_if.tx;
                    #(104166);
                end

                // check stop bit
                if (uart_if.tx == 1) begin
                    tr_tx = new();
                    tr_tx.tx_data = tx_byte;
                    tr_tx.is_transmitted = 1;
                    $display("%t [MON] TX Data captured: %h", $time,
                             tr_tx.tx_data);
                    mon2scb_tx_mbox.put(tr_tx);
                end

            end
        end
    endtask  //

    task run();
        $display("%t [MON] Monitor started", $time);
        fork
            monitor_rx_data();
            monitor_tx_data();
        join_any
        

    endtask  //
endclass  //monitor

class scoreboard;
    transaction tr_gen;
    transaction tr_rx;
    transaction tr_tx;

    mailbox #(transaction) gen2scb_mbox;
    mailbox #(transaction) mon2scb_rx_mbox;
    mailbox #(transaction) mon2scb_tx_mbox;


    int total_tests = 0;
    int pass_count = 0;
    int fail_count = 0;


    function new(mailbox#(transaction) gen2scb_mbox,
                 mailbox#(transaction) mon2scb_rx_mbox,
                 mailbox#(transaction) mon2scb_tx_mbox);

        this.gen2scb_mbox = gen2scb_mbox;
        this.mon2scb_rx_mbox = mon2scb_rx_mbox;
        this.mon2scb_tx_mbox = mon2scb_tx_mbox;

    endfunction  //new()

    task run();

        forever begin
            // Get generated data (expected data)
            gen2scb_mbox.get(tr_gen);
            total_tests++;

            // Wait for RX data from monitor (received data : rx_data)
            mon2scb_rx_mbox.get(tr_rx);

            // Compare send_data with rx_data
            if (tr_gen.send_data == tr_rx.received_data) begin
                $display("%t [SCB] PASS: RX Check - Expected: %h, Got: %h",
                         $time, tr_gen.send_data, tr_rx.received_data);
                pass_count++;
            end else begin
                $display("%t [SCB] FAIL: RX Check - Expected: %h, Got: %h",
                         $time, tr_gen.send_data, tr_rx.received_data);
                fail_count++;
            end

            // Wait for Tx data from monitor
            mon2scb_tx_mbox.get(tr_tx);

            // Compare send_data with tx_data
            if (tr_gen.send_data == tr_tx.tx_data) begin
                $display("%t [SCB] PASS: TX Check - Expected: %h, Got: %h",
                         $time, tr_gen.send_data, tr_tx.tx_data);
                pass_count++;
            end else begin
                $display("%t [SCB] FAIL: TX Check - Expected: %h, Got: %h",
                         $time, tr_gen.send_data, tr_tx.tx_data);
                fail_count++;
            end

            $display("================================");

        end

    endtask  //

    




endclass  //scoreboard




class environment;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) gen2scb_mbox;
    mailbox #(transaction) mon2scb_rx_mbox;
    mailbox #(transaction) mon2scb_tx_mbox;

    event                  gen_next_event;

    generator              gen;
    driver                 drv;
    monitor                mon;
    scoreboard             scb;


    function new(virtual uart_top_interface uart_if);
        gen2drv_mbox = new();
        gen2scb_mbox = new();
        mon2scb_rx_mbox = new();
        mon2scb_tx_mbox = new();
        
        gen = new(gen2drv_mbox, gen2scb_mbox, gen_next_event);
        drv = new(gen2drv_mbox, gen_next_event, uart_if);
        mon = new(mon2scb_rx_mbox, mon2scb_tx_mbox, uart_if);
        scb = new(gen2scb_mbox, mon2scb_rx_mbox, mon2scb_tx_mbox);


    endfunction  //new()

task report();
        $display("===============================================");
        $display("================ Final Report==================");
        $display("===============================================");
        $display("=====Total Tests : %d ==========================",
                 scb.total_tests);
        $display("=====Total checks : %d ========================",
                 scb.total_tests * 2);
        $display("=====passed checks : %d =======================", scb.pass_count);
        $display("=====Failed checks : %d =======================", scb.fail_count);
        $display("===============================================");
        $display("===============================================");
        $display("===============================================");
        $display("===============================================");
        $display("===============================================");
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
        #(104166*20);

        report();
        $display("finished");
        $stop;

    endtask  //


endclass  //environment


module tb_uart_top ();
    environment env;
    uart_top_interface uart_if_tb ();

    uart_top dut (
        .clk          (uart_if_tb.clk),
        .rst          (uart_if_tb.rst),
        .rx           (uart_if_tb.rx),
        .rx_data      (uart_if_tb.rx_data),
        .start_trigger(uart_if_tb.start_trigger),
        .tx           (uart_if_tb.tx)


    );

    always #5 uart_if_tb.clk = ~uart_if_tb.clk;

    initial begin
        env = new(uart_if_tb);
        env.reset();
        env.run();
    end

endmodule
