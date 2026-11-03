module washing_machine (
    input wire clk,
    input wire reset,
    input wire start,
    input wire water_full,
    input wire wash_done,
    input wire drain_done,
    input wire rinse_done,
    input wire spin_done,

    output reg water_valve,
    output reg wash_motor,
    output reg drain_pump,
    output reg spin_motor,
    output reg cycle_done
);

    // Moore FSM state encoding
    parameter IDLE  = 3'b000,
              FILL  = 3'b001,
              WASH  = 3'b010,
              DRAIN = 3'b011,
              RINSE = 3'b100,
              SPIN  = 3'b101,
              DONE  = 3'b110;

    reg [2:0] state, next_state;

    // State register
    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next-state logic
    always @(*) begin
        next_state = state;

        case (state)
            IDLE:
                if (start)
                    next_state = FILL;

            FILL:
                if (water_full)
                    next_state = WASH;

            WASH:
                if (wash_done)
                    next_state = DRAIN;

            DRAIN:
                if (drain_done)
                    next_state = RINSE;

            RINSE:
                if (rinse_done)
                    next_state = SPIN;

            SPIN:
                if (spin_done)
                    next_state = DONE;

            DONE:
                if (start)
                    next_state = FILL;

            default:
                next_state = IDLE;
        endcase
    end

    // Moore output logic
    always @(*) begin
        water_valve = 1'b0;
        wash_motor  = 1'b0;
        drain_pump  = 1'b0;
        spin_motor  = 1'b0;
        cycle_done  = 1'b0;

        case (state)
            FILL:  water_valve = 1'b1;
            WASH:  wash_motor  = 1'b1;
            DRAIN: drain_pump  = 1'b1;
            SPIN:  spin_motor  = 1'b1;
            DONE:  cycle_done  = 1'b1;
            default: ;
        endcase
    end

endmodule
