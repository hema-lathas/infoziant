module atm_controller (
    input clk,
    input rst,
    input card,
    input pin_valid,
    input withdraw,
    input balance_ok,
    output reg pin_check,
    output reg cash_dispense,
    output reg transaction_done
);

parameter IDLE = 3'b000,
          PIN_CHECK = 3'b001,
          AMOUNT = 3'b010,
          DISPENSE = 3'b011,
          DONE = 3'b100;

reg [2:0] state, next_state;

// State register
always @(posedge clk or posedge rst) begin
    if (rst)
        state <= IDLE;
    else
        state <= next_state;
end

// Next-state logic
always @(*) begin
    next_state = state;

    case (state)
        IDLE:
            if (card)
                next_state = PIN_CHECK;

        PIN_CHECK:
            if (pin_valid)
                next_state = AMOUNT;
            else
                next_state = IDLE;

        AMOUNT:
            if (withdraw && balance_ok)
                next_state = DISPENSE;
            else
                next_state = IDLE;

        DISPENSE:
            next_state = DONE;

        DONE:
            next_state = IDLE;

        default:
            next_state = IDLE;
    endcase
end

// Moore output logic
always @(*) begin
    pin_check = 0;
    cash_dispense = 0;
    transaction_done = 0;

    case (state)
        PIN_CHECK:
            pin_check = 1;

        DISPENSE:
            cash_dispense = 1;

        DONE:
            transaction_done = 1;
    endcase
end

endmodule
