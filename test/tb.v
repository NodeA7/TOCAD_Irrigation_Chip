`timescale 1us/1ns

module testbench;

    reg  [7:0] ui_in;
    wire [7:0] uo_out;
    reg  [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    reg        ena;
    reg        clk;
    reg        rst_n;

    tt_um_tocad_irrigation dut (
        .ui_in  (ui_in),
        .uo_out (uo_out),
        .uio_in (uio_in),
        .uio_out(uio_out),
        .uio_oe (uio_oe),
        .ena    (ena),
        .clk    (clk),
        .rst_n  (rst_n)
    );

    initial clk = 0;
    always #50 clk = ~clk; // 10kHz

    task wait_seconds(input integer n);
        integer i;
        begin
            for (i = 0; i < n * 10000; i = i + 1) @(posedge clk);
        end
    endtask

    task wait_cycles(input integer n);
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) @(posedge clk);
        end
    endtask

    task press_dft;
        begin
            wait_cycles(5);
            uio_in[0] = 1'b1;
            wait_cycles(20);
            uio_in[0] = 1'b0;
            wait_cycles(5);
        end
    endtask

    initial begin
        $dumpfile("tocad.vcd");
        $dumpvars(0, testbench);
        
        ui_in = 8'b0; uio_in = 8'b0; ena = 1'b1; rst_n = 1'b0;
        $display("TOCAD Irrigation Chip -- Simulation Start");
        wait_cycles(10); rst_n = 1'b1; wait_cycles(5);

        // TEST 1: DFT Trigger
        $display("[TEST 1] DFT Trigger Zone 0");
        ui_in[0] = 1'b1; uio_in[3:1] = 3'b000; uio_in[6:4] = 3'b000;
        press_dft;
        wait_cycles(100);
        if (uo_out[0]) $display("  PASS -- Valve opened");
        wait_seconds(6);
        if (!uo_out[0]) $display("  PASS -- Valve closed");

        // TEST 2: Rain Lockout
        $display("[TEST 2] Rain Lockout");
        ui_in[7] = 1'b1; ui_in[0] = 1'b1;
        press_dft;
        wait_cycles(500);
        if (!uo_out[0]) $display("  PASS -- Rain blocked watering");
        ui_in[7] = 1'b0;

        // TEST 3: Max-4 Limit
        $display("[TEST 3] Max-4 Limit");
        ui_in[6:0] = 7'b1111111;
        press_dft;
        wait_seconds(1);
        begin
            integer active;
            active = uo_out[0]+uo_out[1]+uo_out[2]+uo_out[3]+uo_out[4]+uo_out[5]+uo_out[6];
            if (active <= 4) $display("  PASS -- Max-4 enforced (%0d open)", active);
        end

        // TEST 4: Auto Retry
        $display("[TEST 4] Auto Retry");
        wait_seconds(7); // Wait for first batch to close
        wait_seconds(2); // Wait for retry pulse
        if (uo_out[6:0] > 0) $display("  PASS -- Retry opened waiting zones");

        // TEST 5: Fault Detection
        $display("[TEST 5] Fault Detection (3 Dry Ticks)");
        rst_n = 1'b0; wait_cycles(10); rst_n = 1'b1;
        ui_in[0] = 1'b1; // Zone 0 Dry
        repeat(3) begin
            wait_seconds(6);
            $display("  Tick processed...");
        end
        if (dut.any_fault) $display("  PASS -- Fault detected after 3 ticks");

        $display("Simulation Complete.");
        $finish;
    end
endmodule
