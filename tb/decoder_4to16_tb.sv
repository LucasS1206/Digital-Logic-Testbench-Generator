`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Self-checking testbench for decoder_4to16 (active-low outputs, active-high enable)
//
// Phase 1: for-loop over all 16 select values with enable = 1
//          -> exactly one output bit (index == sel) must be 0, all others 1
// Phase 2: for-loop over all 16 select values with enable = 0
//          -> y must be 16'hFFFF regardless of sel
// Phase 3: toggle enable 1 -> 0 -> 1 on every select value
//          -> verifies clean disable and clean re-enable
// -----------------------------------------------------------------------------
module decoder_4to16_tb;

    logic [3:0]  sel;
    logic        enable;
    logic [15:0] y;

    decoder_4to16 dut (
        .sel    (sel),
        .enable (enable),
        .y      (y)
    );

    int errors = 0;
    int checks = 0;

    // Reference model built bit-by-bit (deliberately NOT the DUT's shift expression)
    function automatic logic [15:0] expected_y(input logic en, input logic [3:0] s);
        logic [15:0] e;
        e = '1;                 // idle state: all outputs high
        if (en) e[s] = 1'b0;    // only selected line is driven low
        return e;
    endfunction

    task automatic check_y(input string phase);
        logic [15:0] exp_y;
        exp_y = expected_y(enable, sel);
        #1;
        checks++;
        if (y === exp_y) begin
            $display("[PASS] %-22s en=%b sel=%2d (4'b%b) -> y=%b", phase, enable, sel, sel, y);
        end else begin
            errors++;
            $display("[FAIL] %-22s en=%b sel=%2d (4'b%b)", phase, enable, sel, sel);
            $display("       expected y=%b", exp_y);
            $display("       got      y=%b", y);
        end
    endtask

    initial begin
        sel    = 4'd0;
        enable = 1'b0;
        #5;

        // ---------------- Phase 1: exhaustive select, enable high ----------------
        $display("==================================================");
        $display(" decoder_4to16_tb : Phase 1 - all 16 selects, enable=1");
        $display("==================================================");
        enable = 1'b1;
        for (int i = 0; i < 16; i++) begin
            sel = 4'(i);
            check_y("EN=1 sweep");
        end

        // ---------------- Phase 2: exhaustive select, enable low ----------------
        $display("");
        $display("==================================================");
        $display(" decoder_4to16_tb : Phase 2 - all 16 selects, enable=0");
        $display("==================================================");
        enable = 1'b0;
        for (int i = 0; i < 16; i++) begin
            sel = 4'(i);
            check_y("EN=0 sweep");
        end

        // ---------------- Phase 3: enable toggling at each select ----------------
        $display("");
        $display("==================================================");
        $display(" decoder_4to16_tb : Phase 3 - enable toggle per select");
        $display("==================================================");
        for (int i = 0; i < 16; i++) begin
            sel    = 4'(i);
            enable = 1'b1;  check_y("toggle: enable");
            enable = 1'b0;  check_y("toggle: disable");
            enable = 1'b1;  check_y("toggle: re-enable");
        end

        $display("");
        $display("==================================================");
        if (errors == 0)
            $display(" DECODER TESTBENCH RESULT: PASS  (%0d checks)", checks);
        else
            $display(" DECODER TESTBENCH RESULT: FAIL  (%0d of %0d checks failed)", errors, checks);
        $display("==================================================");
        $finish;
    end

endmodule
