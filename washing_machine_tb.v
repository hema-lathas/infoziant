`timescale 1ns/1ps

module washing_machine_tb;

    reg clk;
    reg reset;
    reg start;
    reg water_full;
    reg wash_done;
    reg drain_done;
    reg rinse_done;
    reg spin_done;

    wire water_valve;
    wire wash_motor;
    wire drain_pump;
    wire spin_motor;
    wire cycle_done;

    // Device under test
    washing_machine uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .water_full(water_full),
        .wash_done(wash_done),
        .drain_done(drain_done),
        .rinse_done(rinse_done),
        .spin_done(spin_done),
        .water_valve(water_valve),
        .wash_motor(wash_motor),
        .drain_pump(drain_pump),
        .spin_motor(spin_motor),
        .cycle_done(cycle_done)
    );

    // 10 ns clock period
    always #5 clk = ~clk;

    initial begin
        // Initialize inputs
        clk = 1'b0;
        reset = 1'b1;
        start = 1'b0;
        water_full = 1'b0;
        wash_done = 1'b0;
        drain_done = 1'b0;
        rinse_done = 1'b0;
        spin_done = 1'b0;

        // Reset
        #12;
        reset = 1'b0;

        // Start cycle
        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        // Fill
        repeat (2) @(negedge clk);
        water_full = 1'b1;
        @(negedge clk);
        water_full = 1'b0;

        // Wash
        repeat (2) @(negedge clk);
        wash_done = 1'b1;
        @(negedge clk);
        wash_done = 1'b0;

        // Drain
        repeat (2) @(negedge clk);
        drain_done = 1'b1;
        @(negedge clk);
        drain_done = 1'b0;

        // Rinse
        repeat (2) @(negedge clk);
        rinse_done = 1'b1;
        @(negedge clk);
        rinse_done = 1'b0;

        // Spin
        repeat (2) @(negedge clk);
        spin_done = 1'b1;
        @(negedge clk);
        spin_done = 1'b0;

        // Check completion after state update
        @(negedge clk);
        if (cycle_done === 1'b1)
            $display("TEST PASSED: Washing cycle completed!");
        else
            $display("TEST FAILED: cycle_done was not asserted.");

        #10;
        $finish;
    end

    // Display state and outputs
    initial begin
        $monitor(
            "Time=%0t | State=%b | Valve=%b | Wash=%b | Drain=%b | Spin=%b | Done=%b",
            $time, uut.state, water_valve, wash_motor,
            drain_pump, spin_motor, cycle_done
        );
    end

endmodule
