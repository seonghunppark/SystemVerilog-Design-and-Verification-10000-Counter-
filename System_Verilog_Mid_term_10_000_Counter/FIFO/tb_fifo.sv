`timescale 1ns / 1ps

interface fifo_interface;
    logic       clk;
    logic       rst;
    logic       wr;
    logic       rd;
    logic [7:0] wdata;
    logic [7:0] rdata;
    logic       full;
    logic       empty;
endinterface  //fifo_interface

class transaction;

    // random stimulus
    rand logic       wr;
    rand logic       rd;
    rand logic [7:0] wdata;
    // for scoreboard
    logic      [7:0] rdata;
    logic            full;
    logic            empty;

    constraint push_pop_dist{
        wr dist{
            1:/ 80,
            0:/ 20
        };
        rd dist{
            1:/ 80,
            0:/ 20
        };
    }

    task display(string name_s);
        $display(
            "%t, [%s] wr = %d, rd = %d, wdata = %d, rdata = %d, full = %d, empty = %d",
            $time, name_s, wr, rd, wdata, rdata, full, empty);
    endtask  //
endclass  //transaction

class generator;
    transaction trans;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_event;

    int total_count = 0;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_event);
        this.gen2drv_mbox   = gen2drv_mbox;
        this.gen_next_event = gen_next_event;
    endfunction  //new()

    task run(int run_count);
        repeat (run_count) begin
            total_count++;
            trans = new();
            assert (trans.randomize())
            else $error("[GEN] randomize() error!!");

            gen2drv_mbox.put(trans);
            trans.display("GEN");
            @gen_next_event;
        end
    endtask  //

endclass  //generator

class driver;

    transaction trans;
    mailbox #(transaction) gen2drv_mbox;
    virtual fifo_interface fifo_if;
    event mon_next_event;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual fifo_interface fifo_if, event mon_next_event);
        this.gen2drv_mbox = gen2drv_mbox;
        this.fifo_if = fifo_if;
        this.mon_next_event = mon_next_event;
    endfunction  //new()

    task reset();
        fifo_if.clk = 0;
        fifo_if.rst = 1;
        fifo_if.wr = 0;
        fifo_if.rd = 0;
        fifo_if.wdata = 0;
        repeat (2) @(posedge fifo_if.clk);
        fifo_if.rst = 0;
        repeat (2) @(posedge fifo_if.clk);
        $display("[DRV] reset done!");
    endtask  //

    task run();
        forever begin
            #1;
            gen2drv_mbox.get(trans);
            fifo_if.wr    = trans.wr;
            fifo_if.rd    = trans.rd;
            fifo_if.wdata = trans.wdata;
            trans.display("DRV");
            @(posedge fifo_if.clk);
            ->mon_next_event;
            @(posedge fifo_if.clk);
            // event to mon
        end
    endtask  //


endclass  //driver

class monitor;

    transaction trans;
    mailbox #(transaction) mon2scb_mbox;
    virtual fifo_interface fifo_if;
    event mon_next_event;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual fifo_interface fifo_if, event mon_next_event);
        this.mon2scb_mbox   = mon2scb_mbox;
        this.fifo_if        = fifo_if;
        this.mon_next_event = mon_next_event;
    endfunction  //new()

    task run();
        forever begin
            @(mon_next_event);
            trans       = new();
            trans.wr    = fifo_if.wr;
            trans.rd    = fifo_if.rd;
            trans.wdata = fifo_if.wdata;
            trans.rdata = fifo_if.rdata;
            trans.full  = fifo_if.full;
            trans.empty = fifo_if.empty;
            trans.display("MON");
            mon2scb_mbox.put(trans);
            @(posedge fifo_if.clk);
        end
    endtask  //
endclass  //monitor

class scoreboard;
    transaction trans;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_event;

    logic [7:0] fifo_queue[$:15]; // only $, it's infinite
    logic [7:0] expected_data;

    // rdata count
    int pass_count = 0, fail_count = 0;
    
    
    
    
    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_event);
        this.mon2scb_mbox   = mon2scb_mbox;
        this.gen_next_event = gen_next_event;

    endfunction  //new()




    task run();
        forever begin
            mon2scb_mbox.get(trans);
            //scoreboard
            // queue, decision
            trans.display("SCB");

            //trans.wr == 1 : push
            if (trans.wr) begin
                if (!trans.full) begin
                    fifo_queue.push_back(trans.wdata);
                    $display("[SCB] : Data store in Queue: data:%d, size:%d", trans.wdata, fifo_queue.size());
                end else begin
                    $display("[SCB] : Queue is full : %d", fifo_queue.size());
                end 
            end
            // trans.rd == 1 : pop
            if (trans.rd) begin
                if (!trans.empty) begin
                    expected_data = fifo_queue.pop_front(); // expected data <- pop data
                    if (trans.rdata == expected_data) begin
                        pass_count++;
                        $display("[SCB] : Data matched : %d", trans.rdata);
                    end else begin
                        fail_count++;
                        $display("[SCB] : Data mismatched : %d, %d", trans.rdata, expected_data);
                    end
                end else begin
                    $display("[SCB] FIFO is Empty");
                end
            end
            $display("====================================");
            $display("=========== Data in FIFO ===========");
            $display("================ %p ===============",fifo_queue);
            $display("====================================");
            ->gen_next_event;
        end

    endtask  //

endclass  //scoreboard

class environment;

    mailbox #(transaction) mon2scb_mbox;
    mailbox #(transaction) gen2drv_mbox;


    event                  gen_next_event;
    event                  mon_next_event;

    generator              gen;
    driver                 drv;
    monitor                mon;
    scoreboard             scb;

    function new(virtual fifo_interface fifo_if);
        gen2drv_mbox = new();
        mon2scb_mbox = new();
        gen = new(gen2drv_mbox, gen_next_event);
        drv = new(gen2drv_mbox, fifo_if, mon_next_event);
        mon = new(mon2scb_mbox, fifo_if, mon_next_event);
        scb = new(mon2scb_mbox, gen_next_event);
    endfunction  //new()

    task report();
        $display("==========================================");
        $display("============== Final Report ==============");
        $display("============= Total Count:%d =============", gen.total_count);
        $display("==========================================");
        $display("============== pass count:%d  ============", scb.pass_count);
        $display("==========================================");
        $display("============== fail count:%d  ============", scb.fail_count);
        $display("==========================================");

        
    endtask //



    task reset();
        drv.reset();
    endtask  //

    task run();
        fork
            gen.run(100000);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #10;
        report();
        $display("finished");
        $stop;


    endtask  //
endclass  //environment



module tb_fifo ();
    environment env;

    fifo_interface fifo_if_tb ();

    fifo dut (
        .clk  (fifo_if_tb.clk),
        .rst  (fifo_if_tb.rst),
        .wr   (fifo_if_tb.wr),
        .rd   (fifo_if_tb.rd),
        .wdata(fifo_if_tb.wdata),
        .rdata(fifo_if_tb.rdata),
        .full (fifo_if_tb.full),
        .empty(fifo_if_tb.empty)
    );

    //gen clk
    always #5 fifo_if_tb.clk = ~fifo_if_tb.clk;

    initial begin
        env = new(fifo_if_tb);
        env.reset();
        env.run();
    end

endmodule
