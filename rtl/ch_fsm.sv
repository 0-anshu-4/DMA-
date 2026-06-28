module ch_fsm (
    input logic clk,
    input logic rst_n,

    input logic [31:0] src_addr,
    input logic [31:0] dst_addr,
    input logic [31:0] length,

    input logic enable,
    input logic start,

    output logic ch_req,
    input logic ch_grant,

    output logic [31:0] fsm_src_addr,
    output logic [31:0] fsm_dst_addr,
    output logic [31:0] fsm_length,
    output logic        fsm_start,

    input logic fsm_done,

    output logic busy,
    output logic done
);

typedef enum logic [2:0] {
    IDLE,
    WAIT_GRANT,
    START_TRANSFER,
    WAIT_DONE,
    COMPLETE
} state_t;

state_t curr_state, next_state;

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        curr_state <= IDLE;
    else
        curr_state <= next_state;
end

always_comb begin

    next_state = curr_state;

    case(curr_state)

        IDLE:
            if(enable && start)
                next_state = WAIT_GRANT;

        WAIT_GRANT:
            if(ch_grant)
                next_state = START_TRANSFER;

        START_TRANSFER:
            next_state = WAIT_DONE;

        WAIT_DONE:
            if(fsm_done)
                next_state = COMPLETE;

        COMPLETE:
            next_state = IDLE;

        default:
            next_state = IDLE;

    endcase

end

always_comb begin

    ch_req       = 0;
    busy         = 0;
    done         = 0;
    fsm_start    = 0;

    fsm_src_addr = src_addr;
    fsm_dst_addr = dst_addr;
    fsm_length   = length;

    case(curr_state)

        IDLE: begin
        end

        WAIT_GRANT: begin
            ch_req = 1;
            busy   = 1;
        end

        START_TRANSFER: begin
            ch_req    = 1;   // FIX: keep holding the request
            busy      = 1;
            fsm_start = 1;
        end

        WAIT_DONE: begin
            ch_req = 1;      // FIX: hold request until transfer truly completes
            busy   = 1;
        end

        COMPLETE: begin
            done = 1;
        end

    endcase

end

endmodule