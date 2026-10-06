`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Self-checking testbench for alu_4bit
//
// Flag conventions verified (derived from the DUT's 5-bit extended arithmetic):
//   ADD : carry = carry-out of a+b
//   SUB : carry = borrow (1 when a < b, unsigned)
//   AND/OR/XOR/invalid opcodes : carry = 0, overflow = 0
//   zero = (result == 0), negative = result[3]
//
// Phase 1: Directed corner cases with hard-coded expected values
// Phase 2: Exhaustive sweep (8 opcodes x 16 x 16) against an independent
//          signed-integer reference model
// -----------------------------------------------------------------------------
module alu_4bit_tb;

    logic [3:0] a, b;
    logic [2:0] opcode;
    logic [3:0] result;
    logic       zero, carry, negative, overflow;

    alu_4bit dut (
        .a        (a),
        .b        (b),
        .opcode   (opcode), 
        .result   (result),
        .zero     (zero),
        .carry    (carry),
        .negative (negative),
        .overflow (overflow)
    );

    localparam logic [2:0] OP_ADD = 3'b000;
    localparam logic [2:0] OP_SUB = 3'b001;
    localparam logic [2:0] OP_AND = 3'b010;
    localparam logic [2:0] OP_OR  = 3'b011;
    localparam logic [2:0] OP_XOR = 3'b100;

    int errors       = 0;
    int checks       = 0;
    int sweep_checks = 0;
    int sweep_errors = 0;

    // ------------------------------------------------------------------
    // Directed check: apply stimulus, compare every output exactly
    // ------------------------------------------------------------------
    task automatic check_alu(
        input string      name,
        input logic [3:0] ia,
        input logic [3:0] ib,
        input logic [2:0] op,
        input logic [3:0] e_res,
        input logic       e_z,
        input logic       e_c,
        input logic       e_n,
        input logic       e_v
    );
        a = ia; b = ib; opcode = op;
        #1;
        checks++;
        if ({result, zero, carry, negative, overflow} === {e_res, e_z, e_c, e_n, e_v}) begin
            $display("[PASS] %-30s a=%b b=%b op=%b | res=%b Z=%b C=%b N=%b V=%b",
                     name, ia, ib, op, result, zero, carry, negative, overflow);
        end else begin
            errors++;
            $display("[FAIL] %-30s a=%b b=%b op=%b", name, ia, ib, op);
            $display("       expected: res=%b Z=%b C=%b N=%b V=%b", e_res, e_z, e_c, e_n, e_v);
            $display("       got     : res=%b Z=%b C=%b N=%b V=%b", result, zero, carry, negative, overflow);
        end
    endtask

    // ------------------------------------------------------------------
    // Independent reference model (signed-integer based).
    // Returns {result[3:0], zero, carry, negative, overflow}
    // ------------------------------------------------------------------
    function automatic logic [7:0] ref_model(
        input logic [3:0] ia,
        input logic [3:0] ib,
        input logic [2:0] op
    );
        logic [4:0] full;
        logic       c, v;
        int         sa, sb, sx;

        sa = $signed(ia);
        sb = $signed(ib);
        sx = 0;
        c  = 1'b0;
        v  = 1'b0;
        full = 5'b0;

        case (op)
            OP_ADD: begin
                full = {1'b0, ia} + {1'b0, ib};
                c    = full[4];
                sx   = sa + sb;
                v    = (sx > 7) || (sx < -8);
            end
            OP_SUB: begin
                full = {1'b0, ia} - {1'b0, ib};
                c    = full[4];                 // borrow
                sx   = sa - sb;
                v    = (sx > 7) || (sx < -8);
            end
            OP_AND:  full = {1'b0, ia & ib};
            OP_OR:   full = {1'b0, ia | ib};
            OP_XOR:  full = {1'b0, ia ^ ib};
            default: full = 5'b0;
        endcase

        return {full[3:0], (full[3:0] == 4'b0), c, full[3], v};
    endfunction

    logic [7:0] exp_vec, got_vec;

    initial begin
        a = '0; b = '0; opcode = '0;
        #5;

        $display("==================================================");
        $display(" alu_4bit_tb : Phase 1 - Directed corner cases");
        $display("==================================================");

        // ---------------- ADD : overflow / carry / zero-crossing ----------------
        //          name                          a      b      op      res    Z  C  N  V
        check_alu("ADD  0+0 (zero)",             4'h0,  4'h0,  OP_ADD, 4'h0,  1, 0, 0, 0);
        check_alu("ADD  3+4 (no flags)",         4'h3,  4'h4,  OP_ADD, 4'h7,  0, 0, 0, 0);
        check_alu("ADD  7+1 (max pos ovf)",      4'h7,  4'h1,  OP_ADD, 4'h8,  0, 0, 1, 1);
        check_alu("ADD  7+7 (max pos ovf)",      4'h7,  4'h7,  OP_ADD, 4'hE,  0, 0, 1, 1);
        check_alu("ADD  -8+-1 (neg ovf+carry)",  4'h8,  4'hF,  OP_ADD, 4'h7,  0, 1, 0, 1);
        check_alu("ADD  -8+-8 (neg ovf,zero)",   4'h8,  4'h8,  OP_ADD, 4'h0,  1, 1, 0, 1);
        check_alu("ADD  -1+1 (zero-cross,carry)",4'hF,  4'h1,  OP_ADD, 4'h0,  1, 1, 0, 0);
        check_alu("ADD  5+(-5) (zero-cross)",    4'h5,  4'hB,  OP_ADD, 4'h0,  1, 1, 0, 0);
        check_alu("ADD  -1+-1 (carry, no ovf)",  4'hF,  4'hF,  OP_ADD, 4'hE,  0, 1, 1, 0);
        check_alu("ADD  -8+7 (extremes)",        4'h8,  4'h7,  OP_ADD, 4'hF,  0, 0, 1, 0);
        check_alu("ADD  15+15 (unsigned carry)", 4'hF,  4'hF,  OP_ADD, 4'hE,  0, 1, 1, 0);

        // ---------------- SUB : borrow / overflow / zero ----------------
        check_alu("SUB  0-0",                    4'h0,  4'h0,  OP_SUB, 4'h0,  1, 0, 0, 0);
        check_alu("SUB  5-5 (zero)",             4'h5,  4'h5,  OP_SUB, 4'h0,  1, 0, 0, 0);
        check_alu("SUB  -1--1 (zero)",           4'hF,  4'hF,  OP_SUB, 4'h0,  1, 0, 0, 0);
        check_alu("SUB  4-3 (no flags)",         4'h4,  4'h3,  OP_SUB, 4'h1,  0, 0, 0, 0);
        check_alu("SUB  3-4 (borrow)",           4'h3,  4'h4,  OP_SUB, 4'hF,  0, 1, 1, 0);
        check_alu("SUB  0-1 (zero-cross)",       4'h0,  4'h1,  OP_SUB, 4'hF,  0, 1, 1, 0);
        check_alu("SUB  -8-1 (neg ovf)",         4'h8,  4'h1,  OP_SUB, 4'h7,  0, 0, 0, 1);
        check_alu("SUB  7-(-1) (pos ovf)",       4'h7,  4'hF,  OP_SUB, 4'h8,  0, 1, 1, 1);
        check_alu("SUB  0-(-8) (pos ovf)",       4'h0,  4'h8,  OP_SUB, 4'h8,  0, 1, 1, 1);
        check_alu("SUB  7-(-8) (pos ovf)",       4'h7,  4'h8,  OP_SUB, 4'hF,  0, 1, 1, 1);
        check_alu("SUB  -8-(-8) (zero)",         4'h8,  4'h8,  OP_SUB, 4'h0,  1, 0, 0, 0);

        // ---------------- Logic ops : C and V must stay 0 ----------------
        check_alu("AND  F&5",                    4'hF,  4'h5,  OP_AND, 4'h5,  0, 0, 0, 0);
        check_alu("AND  A&5 (zero)",             4'hA,  4'h5,  OP_AND, 4'h0,  1, 0, 0, 0);
        check_alu("AND  8&8 (neg, no C/V)",      4'h8,  4'h8,  OP_AND, 4'h8,  0, 0, 1, 0);
        check_alu("OR   0|0 (zero)",             4'h0,  4'h0,  OP_OR,  4'h0,  1, 0, 0, 0);
        check_alu("OR   A|5",                    4'hA,  4'h5,  OP_OR,  4'hF,  0, 0, 1, 0);
        check_alu("OR   1|2",                    4'h1,  4'h2,  OP_OR,  4'h3,  0, 0, 0, 0);
        check_alu("XOR  F^F (zero)",             4'hF,  4'hF,  OP_XOR, 4'h0,  1, 0, 0, 0);
        check_alu("XOR  A^5",                    4'hA,  4'h5,  OP_XOR, 4'hF,  0, 0, 1, 0);
        check_alu("XOR  F^0",                    4'hF,  4'h0,  OP_XOR, 4'hF,  0, 0, 1, 0);

        // ---------------- Undefined opcodes : default branch -> all zero ----------------
        check_alu("Invalid opcode 101",          4'hF,  4'hF,  3'b101, 4'h0,  1, 0, 0, 0);
        check_alu("Invalid opcode 110",          4'h7,  4'h1,  3'b110, 4'h0,  1, 0, 0, 0);
        check_alu("Invalid opcode 111",          4'h8,  4'h8,  3'b111, 4'h0,  1, 0, 0, 0);

        $display("");
        $display("==================================================");
        $display(" alu_4bit_tb : Phase 2 - Exhaustive sweep vs model");
        $display("==================================================");

        for (int op = 0; op < 8; op++) begin
            for (int i = 0; i < 16; i++) begin
                for (int j = 0; j < 16; j++) begin
                    a      = 4'(i);
                    b      = 4'(j);
                    opcode = 3'(op);
                    #1;
                    exp_vec = ref_model(a, b, opcode);
                    got_vec = {result, zero, carry, negative, overflow};
                    sweep_checks++;
                    if (got_vec !== exp_vec) begin
                        sweep_errors++;
                        if (sweep_errors <= 20) begin
                            $display("[FAIL] sweep a=%b b=%b op=%b | exp res=%b Z=%b C=%b N=%b V=%b | got res=%b Z=%b C=%b N=%b V=%b",
                                     a, b, opcode,
                                     exp_vec[7:4], exp_vec[3], exp_vec[2], exp_vec[1], exp_vec[0],
                                     result, zero, carry, negative, overflow);
                        end
                    end
                end
            end
        end

        if (sweep_errors == 0)
            $display("[PASS] Exhaustive sweep: %0d/%0d vectors matched", sweep_checks, sweep_checks);
        else
            $display("[FAIL] Exhaustive sweep: %0d of %0d vectors mismatched", sweep_errors, sweep_checks);

        errors += sweep_errors;

        $display("");
        $display("==================================================");
        if (errors == 0)
            $display(" ALU TESTBENCH RESULT: PASS  (%0d directed + %0d sweep checks)", checks, sweep_checks);
        else
            $display(" ALU TESTBENCH RESULT: FAIL  (%0d error(s))", errors);
        $display("==================================================");
        $finish;
    end

endmodule
