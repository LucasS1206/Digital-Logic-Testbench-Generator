`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Self-checking testbench for encoder_8to3 (d[7] = highest priority)
//
// Phase 1: all-zero input     -> valid must be 0 (and y parked at 0)
// Phase 2: one-hot inputs     -> y == index, valid == 1
// Phase 3: input collisions   -> highest asserted bit wins (hard-coded expectations)
// Phase 4: valid-flag edges   -> d=8'h01 (y=0, valid=1) vs d=8'h00 (y=0, valid=0),
//                                and valid dropping after an active input is removed
// Phase 5: exhaustive 0..255  -> compared against an independent reference model
// -----------------------------------------------------------------------------
module encoder_8to3_tb;

    logic [7:0] d;
    logic [2:0] y;
    logic       valid;

    encoder_8to3 dut (
        .d     (d),
        .y     (y),
        .valid (valid)
    );

    int errors       = 0;
    int checks       = 0;
    int sweep_errors = 0;

    task automatic check_enc(
        input string      name,
        input logic [7:0] din,
        input logic [2:0] exp_y,
        input logic       exp_valid
    );
        d = din;
        #1;
        checks++;
        if ({valid, y} === {exp_valid, exp_y}) begin
            $display("[PASS] %-28s d=%b -> y=%0d valid=%b", name, din, y, valid);
        end else begin
            errors++;
            $display("[FAIL] %-28s d=%b", name, din);
            $display("       expected: y=%0d valid=%b", exp_y, exp_valid);
            $display("       got     : y=%0d valid=%b", y, valid);
        end
    endtask

    // Independent reference: scan low->high so the highest set bit overwrites.
    // Returns {valid, y[2:0]}
    function automatic logic [3:0] ref_model(input logic [7:0] din);
        logic [2:0] idx;
        logic       v;
        idx = 3'd0;
        v   = 1'b0;
        for (int i = 0; i < 8; i++) begin
            if (din[i]) begin
                idx = 3'(i);
                v   = 1'b1;
            end
        end
        return {v, idx};
    endfunction

    logic [3:0] exp_vec;

    initial begin
        d = 8'h00;
        #5;

        // ---------------- Phase 1: no inputs ----------------
        $display("==================================================");
        $display(" encoder_8to3_tb : Phase 1 - no active inputs");
        $display("==================================================");
        check_enc("All zeros -> valid drops", 8'b0000_0000, 3'd0, 1'b0);

        // ---------------- Phase 2: one-hot ----------------
        $display("");
        $display("==================================================");
        $display(" encoder_8to3_tb : Phase 2 - one-hot inputs");
        $display("==================================================");
        for (int i = 0; i < 8; i++) begin
            check_enc($sformatf("One-hot bit %0d", i), 8'(1 << i), 3'(i), 1'b1);
        end

        // ---------------- Phase 3: collisions ----------------
        $display("");
        $display("==================================================");
        $display(" encoder_8to3_tb : Phase 3 - simultaneous inputs (priority)");
        $display("==================================================");
        //          name                           d              y     valid
        check_enc("Collision: all bits high",   8'b1111_1111, 3'd7, 1'b1);
        check_enc("Collision: 7 masked off",    8'b0111_1111, 3'd6, 1'b1);
        check_enc("Collision: 7,6 masked off",  8'b0011_1111, 3'd5, 1'b1);
        check_enc("Collision: 7..5 masked off", 8'b0001_1111, 3'd4, 1'b1);
        check_enc("Collision: 7..4 masked off", 8'b0000_1111, 3'd3, 1'b1);
        check_enc("Collision: 7..3 masked off", 8'b0000_0111, 3'd2, 1'b1);
        check_enc("Collision: 7..2 masked off", 8'b0000_0011, 3'd1, 1'b1);
        check_enc("Collision: MSB vs LSB",      8'b1000_0001, 3'd7, 1'b1);
        check_enc("Collision: alternating 0x55",8'b0101_0101, 3'd6, 1'b1);
        check_enc("Collision: alternating 0xAA",8'b1010_1010, 3'd7, 1'b1);
        check_enc("Collision: 0x2A",            8'b0010_1010, 3'd5, 1'b1);
        check_enc("Collision: 4 vs 0",          8'b0001_0001, 3'd4, 1'b1);
        check_enc("Collision: 3 vs 0",          8'b0000_1001, 3'd3, 1'b1);
        check_enc("Collision: 2 vs 1",          8'b0000_0110, 3'd2, 1'b1);
        check_enc("Collision: 2 vs 0",          8'b0000_0101, 3'd2, 1'b1);
        check_enc("Collision: 7 vs 6",          8'b1100_0000, 3'd7, 1'b1);
        check_enc("Collision: 6 vs 5",          8'b0110_0000, 3'd6, 1'b1);
        check_enc("Collision: 4 vs 3",          8'b0001_1000, 3'd4, 1'b1);

        // ---------------- Phase 4: valid-flag behaviour ----------------
        $display("");
        $display("==================================================");
        $display(" encoder_8to3_tb : Phase 4 - valid flag behaviour");
        $display("==================================================");
        check_enc("d[0] only (y=0, valid=1)",   8'b0000_0001, 3'd0, 1'b1);
        check_enc("Back to zero (valid=0)",     8'b0000_0000, 3'd0, 1'b0);
        check_enc("d[7] only",                  8'b1000_0000, 3'd7, 1'b1);
        check_enc("Drop to zero from 7",        8'b0000_0000, 3'd0, 1'b0);
        check_enc("Collision then release",     8'b1111_1111, 3'd7, 1'b1);
        check_enc("Release all inputs",         8'b0000_0000, 3'd0, 1'b0);

        // ---------------- Phase 5: exhaustive ----------------
        $display("");
        $display("==================================================");
        $display(" encoder_8to3_tb : Phase 5 - exhaustive 256-vector sweep");
        $display("==================================================");
        for (int i = 0; i < 256; i++) begin
            d = 8'(i);
            #1;
            exp_vec = ref_model(d);
            if ({valid, y} !== exp_vec) begin
                sweep_errors++;
                $display("[FAIL] sweep d=%b | expected y=%0d valid=%b | got y=%0d valid=%b",
                         d, exp_vec[2:0], exp_vec[3], y, valid);
            end
            // Independent invariant: valid must equal the OR-reduction of d
            if (valid !== (|d)) begin
                sweep_errors++;
                $display("[FAIL] sweep d=%b | valid=%b but |d=%b", d, valid, |d);
            end
        end
        if (sweep_errors == 0)
            $display("[PASS] Exhaustive sweep: all 256 vectors matched");
        else
            $display("[FAIL] Exhaustive sweep: %0d mismatch(es)", sweep_errors);
        errors += sweep_errors;

        $display("");
        $display("==================================================");
        if (errors == 0)
            $display(" ENCODER TESTBENCH RESULT: PASS  (%0d directed checks + 256-vector sweep)", checks);
        else
            $display(" ENCODER TESTBENCH RESULT: FAIL  (%0d error(s))", errors);
        $display("==================================================");
        $finish;
    end

endmodule
