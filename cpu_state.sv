
// CPU states
typedef enum logic [2:0] {
    STATE_RESET,
    STATE_FETCH_IR,
    STATE_FETCH_OP,
    STATE_EXECUTE,
    STATE_HALT
} cpu_state_t;
