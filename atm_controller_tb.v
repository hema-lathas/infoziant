`timescale 1ns/1ps

module atm_controller_tb;

reg clk, rst;
reg card, pin_valid, withdraw, balance_ok;
wire pin_check, cash_dispense, transaction_done;

atm_controller uut (
    .clk(clk),
    .rst(rst),
    .card(card),
    .pin_valid(pin_valid),
    .withdraw(withdraw),
    .balance_ok(balance_ok),
    .pin_check(pin_check),
    .cash_dispense(cash_dispense),
    .transaction_done(transaction_done)
);

// Clock generation
always #5 clk = ~clk;

initial begin
    clk = 0;
    rst = 1;
    card = 0;
    pin_valid = 0;
    withdraw = 0;
    balance_ok = 0;

    #10 rst = 0;

    #10 card = 1;          // Insert card
    #10 card = 0;
        pin_valid = 1;     // Correct PIN
    #10 pin_valid = 0;
        withdraw = 1;
        balance_ok = 1;    // Sufficient balance
    #10 withdraw = 0;
        balance_ok = 0;

    #40 $finish;
end

initial begin
    $monitor("time=%0t card=%b pin_check=%b cash_dispense=%b done=%b",
             $time, card, pin_check, cash_dispense, transaction_done);
end

endmodule
