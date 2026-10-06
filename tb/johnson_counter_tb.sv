`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Self-checking testbench for johnson_counter (4-bit, async active-low reset)
//
// Expected state sequence after reset release (8-state cycle):
//   0000 -> 0001 -> 0011 -> 0111 -> 1111 -> 1110 -> 1100 -> 1000 -> 0000 -> ...
//
// Phase 1: Assert rst_n asynchronously (off-clock) and confirm q clears with
//          NO clock edge; hold reset across clock edges and confirm q stays 0.
// Phase 2: Release reset, run 16 clock cycles (two full periods) and compare q
//          against the expected sequence after every rising edge.
// Phase 3: Mid-run asynchronous reset (while q is non-zero), verify immediate
//          clear, hold, release, and clean restart of the sequence.
//
// Background glitch monitor (active after Phase 1):
//   * q may only change on a rising clk edge (or while reset is asserted)
//   * every normal state transition must flip exactly ONE bit
// -----------------------------------------------------------------------------
module johnson_counter_tb;

    logic       clk   = 1'b0;
    logic       rst_n = 1'b1;
    logic [3:0] q;

    johnson_counter dut (
        .clk   (clk),
        .rst_n (rst_n),
        .q     (q)
    );

    // 10 ns clock period (5 ns high / 5 ns low)
    always #5 clk = ~clk;

    int errors       = 0;
    int checks       = 0;
    int glitch_errors = 0;

    // ------------------------------------------------------------------
    // Expected value of q after n clock edges following reset release
    // (explicit table - independent of the DUT's shift expression)
    // ------------------------------------------------------------------
    function automatic logic [3:0] exp_seq(input int n);
        case (n % 8)
            0:       return 4'b0000;
            1:       return 4'b0001;
            2:       return 4'b0011;
            3:       return 4'b0111;
            4:       return 4'b1111;
            5:       return 4'b1110;
            6:       return 4'b1100;
            default: return 4'b1000;   // 7
        endcase
    endfunction

    function automatic int popcount4(input logic [3:0] v);
        int n;
        n = 0;
        for (int i = 0; i < 4; i++) n += int'(v[i]);
        return n;
    endfunction

    task automatic check_q(input string name, input logic [3:0] expected);
        checks++;
        if (q === expected) begin
            $display("[PASS] %-36s t=%0t q=%b", name, $time, q);
        end else begin
            errors++;
            $display("[FAIL] %-36s t=%0t expected q=%b, got q=%b", name, $time, expected, q);
        end
    endtask

    // ------------------------------------------------------------------
    // Glitch / protocol monitor
    // ------------------------------------------------------------------
    time        last_posedge_t = 0;
    logic [3:0] prev_q         = 4'bxxxx;
    bit         monitor_en     = 1'b0;

    // NBA updates of q land in the same time step as the clock edge, after this
    // blocking assignment has already executed.
    always @(posedge clk) last_posedge_t = $time;

    always @(q) begin
        if (monitor_en && (rst_n === 1'b1)) begin
            if ($time != last_posedge_t) begin
                glitch_errors++;
                $display("[FAIL] GLITCH: q changed off-clock at t=%0t (%b -> %b)", $time, prev_q, q);
            end
            if (popcount4(q ^ prev_q) != 1) begin
                glitch_errors++;
                $display("[FAIL] BAD TRANSITION at t=%0t: %b -> %b (not a single-bit change)",
                         $time, prev_q, q);
            end
        end
        prev_q = q;
    end

    // Watchdog
    initial begin
        #2000;
        $display("[FAIL] Simulation timeout");
        $display(" JOHNSON COUNTER TESTBENCH RESULT: FAIL");
        $finish;
    end

    initial begin
        // t=0: clk=0, rst_n=1, q=X

        // ---------------- Phase 1: asynchronous reset ----------------
        $display("==================================================");
        $display(" johnson_counter_tb : Phase 1 - asynchronous reset");
        $display("==================================================");

        #2 rst_n = 1'b0;      // t=2ns: assert reset mid low-phase, first posedge is at 5ns
        #1;                   // t=3ns: still no clock edge has occurred
        check_q("Async reset clears q (no clk edge)", 4'b0000);

        repeat (2) @(posedge clk);   // hold reset through two rising edges
        #1;
        check_q("q held at 0 during reset + clocks", 4'b0000);

        // ---------------- Phase 2: 16 cycles ----------------
        $display("");
        $display("==================================================");
        $display(" johnson_counter_tb : Phase 2 - 16 clock cycles");
        $display("==================================================");

        @(negedge clk);       // release reset away from the active clock edge
        rst_n      = 1'b1;
        monitor_en = 1'b1;

        for (int n = 1; n <= 16; n++) begin
            @(posedge clk);
            #1;
            check_q($sformatf("Cycle %2d", n), exp_seq(n));
        end

        // ---------------- Phase 3: mid-run async reset ----------------
        $display("");
        $display("==================================================");
        $display(" johnson_counter_tb : Phase 3 - mid-run async reset");
        $display("==================================================");

        for (int n = 17; n <= 19; n++) begin   // advance to a non-zero state (0111)
            @(posedge clk);
            #1;
            check_q($sformatf("Cycle %2d", n), exp_seq(n));
        end

        #2 rst_n = 1'b0;      // assert while clk is high, no edge pending for 2 ns
        #1;
        check_q("Mid-run async reset clears q", 4'b0000);

        @(posedge clk);       // clock edge while in reset must not advance state
        #1;
        check_q("q held at 0 (reset + clk edge)", 4'b0000);

        @(negedge clk);
        rst_n = 1'b1;

        @(posedge clk);
        #1;
        check_q("Restart after reset: first step", 4'b0001);
        @(posedge clk);
        #1;
        check_q("Restart after reset: second step", 4'b0011);

        // ---------------- Summary ----------------
        if (glitch_errors == 0)
            $display("[PASS] Glitch monitor: no off-clock changes, all transitions single-bit");
        else
            $display("[FAIL] Glitch monitor: %0d violation(s)", glitch_errors);

        errors += glitch_errors;

        $display("");
        $display("==================================================");
        if (errors == 0)
            $display(" JOHNSON COUNTER TESTBENCH RESULT: PASS  (%0d checks)", checks);
        else
            $display(" JOHNSON COUNTER TESTBENCH RESULT: FAIL  (%0d error(s))", errors);
        $display("==================================================");
        $finish;
    end

endmodule
