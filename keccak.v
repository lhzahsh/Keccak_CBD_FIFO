`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/16 13:54:50
// Design Name: 
// Module Name: keccak
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module keccak (
    input           clk,
    input           rstn,
    input           init,
    input           go,
    input           squeeze,
    input           absorb,
    input           extend,
    input    [31:0] din_0, din_1,
    input     [1:0] rand_data,
    output          done,
    output   [31:0] result_0, result_1
);
 
    wire        rstn_rf;
    wire        enable_rf;       // 由 keccak_top.dout_vld_o 驱动，置换完成后锁存结果
    wire        keccak_start;    // FSM 通知 keccak_top 开始置换（拉低再拉高 rst_n）
 
    wire [1599:0] reorder_out_0, reorder_out_1; // registerfdre 输出（当前状态）
    wire [1599:0] keccak_out_0,  keccak_out_1;  // keccak_top 置换结果
 
    assign result_0 = reorder_out_0[31:0];
    assign result_1 = reorder_out_1[31:0];
 
    registerfdre reg_0 (
        .clk    (clk),
        .rstn   (rstn_rf),
        .init   (init),
        .enable (enable_rf),
        .squeeze(squeeze),
        .absorb (absorb),
        .extend (extend),
        .din    (din_0),
        .d      (keccak_out_0),   // 置换结果写入
        .q      (reorder_out_0)
    );
 
    registerfdre reg_1 (
        .clk    (clk),
        .rstn   (rstn_rf),
        .init   (init),
        .enable (enable_rf),
        .squeeze(squeeze),
        .absorb (absorb),
        .extend (extend),
        .din    (din_1),
        .d      (keccak_out_1),
        .q      (reorder_out_1)
    );
 
    // -------------------------------------------------------------------------

    // -------------------------------------------------------------------------
    keccak_top keccak_inst (
        .clk          (clk),
        .rst_n        (keccak_start),
        .random_i     (rand_data),             // 2bit外部新鲜随机数
        .din_share0_i (reorder_out_0),
        .din_share1_i (reorder_out_1),
        .dout_share0_o(keccak_out_0),
        .dout_share1_o(keccak_out_1),
        .dout_vld_o   (enable_rf)
    );
 

    statemachine fsm (
        .clk          (clk),
        .rstn         (rstn),
        .init         (init),
        .go           (go),
        .keccak_done  (enable_rf),
        .done         (done),
        .rstn_rf      (rstn_rf),
        .keccak_start (keccak_start)
    );
 
endmodule
 
// =============================================================================
// registerfdre：串行吸收/挤压移位寄存器
// =============================================================================
module registerfdre (
    input           clk,
    input           rstn,
    input           init,
    input           enable,
    input           squeeze,
    input           absorb,
    input           extend,
    input   [31:0]  din,
    input   [1599:0] d,
    output  [1599:0] q
);
 
    wire    [31:0]  din_mux;
    reg     [1599:0] q_buf;
 
    assign q = q_buf;
    assign din_mux = extend ? q_buf[31:0] : (absorb ? q_buf[31:0] ^ din : din);
 
    always @(posedge clk) begin
        if (~rstn)           q_buf <= 0;
        else if (init)       q_buf <= 0;
        else if (squeeze | extend) q_buf <= {din_mux, q_buf[1599:32]};
        else if (enable)     q_buf <= d;
    end
 
endmodule
 

module statemachine (
    input           clk,
    input           rstn,
    input           init,
    input           go,
    input           keccak_done,   // 来自 keccak_top.dout_vld_o
    output  reg     done,
    output  reg     rstn_rf,
    output  reg     keccak_start   // 驱动 keccak_top.rst_n（低有效）
);
 
    localparam S_RESET  = 3'h0;
    localparam S_INIT   = 3'h1;
    localparam S_LAUNCH = 3'h2;   // 拉低 keccak_start，触发 keccak_top 复位/启动
    localparam S_RUN    = 3'h3;   // 等待 keccak_top 完成
    localparam S_DONE   = 3'h4;
 
    reg [2:0] state, next_state;
 
    // ---- 状态寄存器 ----
    always @(posedge clk or negedge rstn) begin
        if (~rstn) state <= S_RESET;
        else       state <= next_state;
    end
 
    // ---- 次态逻辑 + 输出逻辑（Moore + Mealy 混合） ----
    always @(*) begin
        // 默认输出
        rstn_rf       = 1'b1;
        keccak_start  = 1'b1;   // 默认高电平，keccak_top 正常运行
        done          = 1'b0;
        next_state    = state;
 
        case (state)
            S_RESET : begin
                rstn_rf      = 1'b0;   // 复位 registerfdre
                keccak_start = 1'b0;   // 复位 keccak_top
                if (init) next_state = S_INIT;
            end
 
            S_INIT : begin
                // 此阶段外部可执行 absorb 串行写入
                // keccak_top 保持复位（上一次 S_DONE 已将其置为复位态，
                // 此处 keccak_start 保持高，keccak_top 内部 FSM 停在 StFinish）
                if (go) next_state = S_LAUNCH;
            end
 
            S_LAUNCH : begin
                // 拉低 rst_n 一个周期：keccak_top 内部 FSM 复位至 StStart
                keccak_start = 1'b0;
                next_state   = S_RUN;
            end
 
            S_RUN : begin
                // keccak_top 自主运行24轮，等待完成
                keccak_start = 1'b1;
                if (keccak_done) next_state = S_DONE;
            end
 
            S_DONE : begin
                done = 1'b1;
                // keccak_top 结果已通过 dout_vld_o 锁存至 registerfdre
                next_state = S_INIT;
            end
 
            default: next_state = S_RESET;
        endcase
    end
 
endmodule
module keccak_top (
  input             clk,
  input             rst_n,
  input  [   2-1:0] random_i, // fresh randomness input
  input  [1600-1:0] din_share0_i,
  input  [1600-1:0] din_share1_i,

  output wire [1600-1:0] dout_share0_o,
  output wire [1600-1:0] dout_share1_o,
  output wire            dout_vld_o // high-level active
);

  // Control
  wire [7-1:0] iota_round_constant;
  wire         round_in_select;

  keccak_control control_inst(
    .clk                  (clk),
    .rst_n                (rst_n),
    .iota_round_constant_o(iota_round_constant),
    .round_in_select_o    (round_in_select),
    .dout_vld_o           (dout_vld_o)
  );

  // Data input & output
  wire [2*1600-1:0] state_round_in, state_round_out;

  assign state_round_in = round_in_select ? {din_share1_i, din_share0_i} : state_round_out;
  assign dout_share0_o = state_round_out[1*1600-1:0*1600];
  assign dout_share1_o = state_round_out[2*1600-1:1*1600];

  // Theta & rho & pi
  wire [2*1600-1:0] state_pi2chi;
  wire [ 2*320-1:0] state_pseudorandom;

  keccak_theta_rho_pi theta_rho_pi_share0 (
    .state_round_in_i(state_round_in[1600-1:0]),
    .state_pi2chi_o(state_pi2chi[1600-1:0])
  );

  keccak_theta_rho_pi theta_rho_pi_share1 (
    .state_round_in_i(state_round_in[2*1600-1:1600]),
    .state_pi2chi_o(state_pi2chi[2*1600-1:1600])
  );

  // Bypass theta
  keccak_rho_pi rho_pi_share0 (
    .state_round_in_y0_i(state_round_in[320-1:0]), // x=0...4, y=0, z=0...63
    .state_pseudorandom_o(state_pseudorandom[320-1:0])
  );

  keccak_rho_pi rho_pi_share1 (
    .state_round_in_y0_i(state_round_in[1600+320-1:1600]), // x=0...4, y=0, z=0...63
    .state_pseudorandom_o(state_pseudorandom[2*320-1:320])
  );

  // Chi pre-reg
  wire [4*1600-1:0] state_d;

  keccak_chi_pr chi_pr_inst (
    .random_i            (random_i),
    .state_pi2chi_i      (state_pi2chi),
    .state_pseudorandom_i(state_pseudorandom),
    .state_do            (state_d)
  );

  // State registers
  wire [4*1600-1:0] state_q;

  keccak_state state_inst (
    .clk     (clk),
    .state_di(state_d),
    .state_qo(state_q)
  );

  // Compression & iota
  keccak_comp_iota comp_iota_inst(
    .state_qi             (state_q),
    .iota_round_constant_i(iota_round_constant),
    .state_round_out_o    (state_round_out)
  );

endmodule

module keccak_control (
  input               clk,
  input               rst_n,
  output wire [7-1:0] iota_round_constant_o,  // 压缩后的7位轮常数（原64位）
  output reg          round_in_select_o,
  output wire         dout_vld_o
);

  // begin: FSM
  localparam StStart  = 3'h1,
             StRun    = 3'h2,
             StFinish = 3'h4;

  reg [2:0] control_state_d, control_state_q;
  wire      last_round;

  always @(*) begin
    case (control_state_q)
      StStart:  control_state_d = StRun;
      StRun:    control_state_d = last_round ? StFinish : StRun;
      StFinish: control_state_d = StFinish;
      default:  control_state_d = StFinish;
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      control_state_q <= StStart;
    end else begin
      control_state_q <= control_state_d;
    end
  end
  // end: FSM

  // begin: round counter
  reg [4:0] round_counter_d, round_counter_q;

  always @(*) begin
    case (control_state_q)
      StStart:  round_counter_d = 5'd0;
      StRun:    round_counter_d = round_counter_q + 5'd1;
      StFinish: round_counter_d = round_counter_q;
      default:  round_counter_d = round_counter_q;
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      round_counter_q <= 5'd0;
    end else begin
      round_counter_q <= round_counter_d;
    end
  end
  // end: round counter

  // begin: control signals
  assign last_round = rst_n && (round_counter_q == 5'd22);
  assign dout_vld_o = (control_state_q == StFinish);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      round_in_select_o <= 1'b1;
    end else begin
      round_in_select_o <= 1'b0;
    end
  end
  // end: control signals

  // begin: iota round constants（压缩版，输出7位）
  keccak_roundconstant rc_gen (
    .round_number_i  (round_counter_q),
    .round_constant_o(iota_round_constant_o)
  );
  // end: iota round constants

endmodule

module keccak_rho_pi (
  // state_round_in_y0_i
  // [0*64 : 1*64-1]     [1*64 : 2*64-1]   ...  [4*64 : 5*64-1]
  // x=0, y=0, z=0...63  x=1,y=0,z=0...63  ...  x=4,y=0,z=0...63
  input      [320-1:0] state_round_in_y0_i,
  // state_pseudorandom_o
  // [0*64 : 1*64-1]     [1*64 : 2*64-1]   ...  [4*64 : 5*64-1]
  // x=0, y=0, z=0...63  x=0,y=1,z=0...63  ...  x=0,y=4,z=0...63
  output reg [320-1:0] state_pseudorandom_o
);

  localparam W = 64;

  // begin: rho
  localparam [25*6-1:0] ROTATION_OFFSETS = {
    6'd14, 6'd56, 6'd61, 6'd2,  6'd18,
    6'd8,  6'd21, 6'd15, 6'd45, 6'd41,
    6'd39, 6'd25, 6'd43, 6'd10, 6'd3,
    6'd20, 6'd55, 6'd6,  6'd44, 6'd36,
    6'd27, 6'd28, 6'd62, 6'd1,  6'd0
  };


  reg [320-1:0] state_rho2pi;
  /* verilator lint_off UNUSED */
  reg [2*W-1:0] shifted_value;
  /* verilator lint_on UNUSED */

  always @(*) begin : rho
    integer x;
    for (x = 0; x < 5; x = x + 1) begin
      shifted_value = {2{state_round_in_y0_i[x * W +: W]}} >>
          (W - ROTATION_OFFSETS[x * 6 +: 6]);
      state_rho2pi[x * W +: W] = shifted_value[W-1:0];
    end
  end
  // end: rho

  // begin: pi
  always @(*) begin : pi
    integer x;
    for (x = 0; x < 5; x = x + 1) begin
      state_pseudorandom_o[((2 * x) % 5) * W +: W] = state_rho2pi[x * W +: W];
    end
  end
  // end:pi

endmodule

module keccak_state (
  input                   clk,
  input      [4*1600-1:0] state_di,
  output reg [4*1600-1:0] state_qo
);

  always @(posedge clk) state_qo <= state_di;

endmodule

module keccak_theta_rho_pi (
  input      [1600-1:0] state_round_in_i,
  output reg [1600-1:0] state_pi2chi_o
);

  localparam W = 64;

  function integer idx (input integer x, input integer y);
    idx = (x + 5 * y) * W;
  endfunction

  // begin: theta
  reg [ 5*W-1:0] theta_column_sum, theta_column_sum_z_rot, theta_two_columns;
  reg [25*W-1:0] state_theta2rho;

  always @(*) begin : theta
    integer x, y;

    for (x = 0; x < 5; x = x + 1) begin
      theta_column_sum[x*W +: W] = state_round_in_i[idx(x, 0) +: W] ^
          state_round_in_i[idx(x, 1) +: W] ^ state_round_in_i[idx(x, 2) +: W] ^
          state_round_in_i[idx(x, 3) +: W] ^ state_round_in_i[idx(x, 4) +: W];
      theta_column_sum_z_rot[x*W +: W] = {theta_column_sum[x*W +: W-1], theta_column_sum[x*W+W-1]};
    end

    for (x = 0; x < 5; x = x + 1) begin
      theta_two_columns[idx(x, 0) +: W] = theta_column_sum[idx((x + 4) % 5, 0) +: W] ^
            theta_column_sum_z_rot[idx((x + 1) % 5, 0) +: W];
    end

    for (y = 0; y < 5; y = y + 1) begin
      state_theta2rho[idx(0, y) +: 5*W] = state_round_in_i[idx(0, y) +: 5*W] ^ theta_two_columns;
    end
  end
  // end: theta

  // begin: rho
  localparam [25*6-1:0] ROTATION_OFFSETS = {
    6'd14, 6'd56, 6'd61, 6'd2,  6'd18,
    6'd8,  6'd21, 6'd15, 6'd45, 6'd41,
    6'd39, 6'd25, 6'd43, 6'd10, 6'd3,
    6'd20, 6'd55, 6'd6,  6'd44, 6'd36,
    6'd27, 6'd28, 6'd62, 6'd1,  6'd0
  };

  reg [25*W-1:0] state_rho2pi;
  /* verilator lint_off UNUSED */
  reg [2*W-1:0] shifted_value;
  /* verilator lint_on UNUSED */
  
  always @(*) begin : rho
    integer x, y;
    for (x = 0; x < 5; x = x + 1) begin
      for (y = 0; y < 5; y = y + 1) begin
        shifted_value = {2{state_theta2rho[idx(x, y) +: W]}} >> 
            (W - ROTATION_OFFSETS[(x + 5 * y) * 6 +: 6]);
        state_rho2pi[idx(x, y) +: W] = shifted_value[W-1 : 0];
      end
    end
  end
  // end: rho

  // begin: pi
  always @(*) begin : pi
    integer x, y;
    for (x = 0; x < 5; x = x + 1) begin
      for (y = 0; y < 5; y = y + 1) begin
        state_pi2chi_o[idx(y, (2 * x + 3 * y) % 5) +: W] = state_rho2pi[idx(x, y) +: W];
      end
    end
  end
  // end: pi

endmodule

// -----------------------------------------------------------------------------
// keccak_roundconstant（压缩版）
//
// 原始64位轮常数中，仅有7个比特位置可能非零：
//   bit 0, 1, 3, 7, 15, 31, 63
// 压缩常数 round_constant_o[j] 对应原始常数中第 2^j - 1 位（j=0..5）及第63位（j=6）:
//   j=0 -> bit  0  (2^0 - 1 = 0? 实为 2^0 = 1, 位置0)
//   j=1 -> bit  1
//   j=2 -> bit  3
//   j=3 -> bit  7
//   j=4 -> bit 15
//   j=5 -> bit 31
//   j=6 -> bit 63
// 压缩后每轮仅需7位存储，24轮共168位（原1536位），节省约89%。
// -----------------------------------------------------------------------------
module keccak_roundconstant (
  input      [ 4:0] round_number_i,
  output reg [ 6:0] round_constant_o  // 压缩后7位轮常数
);

  always @(*) begin
    case (round_number_i)
      5'd00:   round_constant_o = 7'h01; // 原: 0x0000000000000001
      5'd01:   round_constant_o = 7'h1A; // 原: 0x0000000000008082
      5'd02:   round_constant_o = 7'h5E; // 原: 0x800000000000808A
      5'd03:   round_constant_o = 7'h70; // 原: 0x8000000080008000
      5'd04:   round_constant_o = 7'h1F; // 原: 0x000000000000808B
      5'd05:   round_constant_o = 7'h21; // 原: 0x0000000080000001
      5'd06:   round_constant_o = 7'h79; // 原: 0x8000000080008081
      5'd07:   round_constant_o = 7'h55; // 原: 0x8000000000008009
      5'd08:   round_constant_o = 7'h0E; // 原: 0x000000000000008A
      5'd09:   round_constant_o = 7'h0C; // 原: 0x0000000000000088
      5'd10:   round_constant_o = 7'h35; // 原: 0x0000000080008009
      5'd11:   round_constant_o = 7'h26; // 原: 0x000000008000000A
      5'd12:   round_constant_o = 7'h3F; // 原: 0x000000008000808B
      5'd13:   round_constant_o = 7'h4F; // 原: 0x800000000000008B
      5'd14:   round_constant_o = 7'h5D; // 原: 0x8000000000008089
      5'd15:   round_constant_o = 7'h53; // 原: 0x8000000000008003
      5'd16:   round_constant_o = 7'h52; // 原: 0x8000000000008002
      5'd17:   round_constant_o = 7'h48; // 原: 0x8000000000000080
      5'd18:   round_constant_o = 7'h16; // 原: 0x000000000000800A
      5'd19:   round_constant_o = 7'h66; // 原: 0x800000008000000A
      5'd20:   round_constant_o = 7'h79; // 原: 0x8000000080008081
      5'd21:   round_constant_o = 7'h58; // 原: 0x8000000000008080
      5'd22:   round_constant_o = 7'h21; // 原: 0x0000000080000001
      5'd23:   round_constant_o = 7'h74; // 原: 0x8000000080008008
      default: round_constant_o = 7'h00;
    endcase
  end

endmodule

// -----------------------------------------------------------------------------
// keccak_comp_iota（压缩版）
//
// 接收7位压缩轮常数，在执行iota步骤时仅对状态中7个固定比特位执行异或，
// 其余57位直接透传，无需对应的异或逻辑。
//
// 压缩位 j 与原始状态比特位的对应关系：
//   comp[0] -> state bit  0
//   comp[1] -> state bit  1
//   comp[2] -> state bit  3
//   comp[3] -> state bit  7
//   comp[4] -> state bit 15
//   comp[5] -> state bit 31
//   comp[6] -> state bit 63
// -----------------------------------------------------------------------------
module keccak_comp_iota (
  input       [4*1600-1:0] state_qi,
  input       [    7-1:0]  iota_round_constant_i,  // 压缩后7位轮常数
  output wire [2*1600-1:0] state_round_out_o
);
  wire [2*1600-1:0] state_chi2iota;

  assign state_chi2iota[1*1600-1:0*1600] = state_qi[1*1600-1:0*1600] ^ state_qi[2*1600-1:1*1600];
  assign state_chi2iota[2*1600-1:1*1600] = state_qi[3*1600-1:2*1600] ^ state_qi[4*1600-1:3*1600];

  // 先将share0的低64位与7个有效比特位进行异或（iota步骤），其余位直接透传
  // 7个有效位置：bit0, bit1, bit3, bit7, bit15, bit31, bit63
  wire [63:0] iota_xor_mask;
  assign iota_xor_mask = {
    iota_round_constant_i[6],          // bit 63
    32'b0,                              // bit 62..32（全零）
    iota_round_constant_i[5],          // bit 31
    15'b0,                              // bit 30..16（全零）
    iota_round_constant_i[4],          // bit 15
    7'b0,                               // bit 14..8（全零）
    iota_round_constant_i[3],          // bit 7
    3'b0,                               // bit 6..4（全零）
    iota_round_constant_i[2],          // bit 3
    1'b0,                               // bit 2（全零）
    iota_round_constant_i[1],          // bit 1
    iota_round_constant_i[0]           // bit 0
  };

  // iota仅作用于share0的第一个lane（x=0,y=0，对应bit[63:0]）
  assign state_round_out_o[    64-1: 0] = state_chi2iota[64-1:0] ^ iota_xor_mask;
  assign state_round_out_o[2*1600-1:64] = state_chi2iota[2*1600-1:64];

endmodule

module keccak_chi_pr (
  input      [     2-1:0] random_i,
  input      [2*1600-1:0] state_pi2chi_i,
  input      [ 2*320-1:0] state_pseudorandom_i,
  output reg [4*1600-1:0] state_do
);

  localparam W = 64;
  localparam log2W = 6;

  function integer idx (input integer x, input integer y, input integer sh);
    idx = (x + 5 * y) * W + sh * 25 * W;
  endfunction

  function integer yz2j (input integer y, input integer z);
    yz2j = y * W + z;
  endfunction

  function integer j2y (input integer j);
    j2y = ((j + 5 * W) >> log2W) % 5;
  endfunction

  function integer j2z (input integer j);
    j2z = (j + 5 * W) % W;
  endfunction


  reg [2*25*W-1:0] operand, operand_n;
  reg [4*25*W-1:0] product;
  reg [   5*W-1:0] guard_x0, guard_x1;

  always @(*) begin : chi_pr
    integer x, y, z, j;

    operand = state_pi2chi_i;
    operand_n = ~operand;

    // begin: guards
    for (y = 0; y < 5; y = y + 1) begin
      for (z = 0; z < 64; z = z + 1) begin
        j = yz2j(y, z);
        if (j == 0) begin
          guard_x0[j] = random_i[0];
          guard_x1[j] = random_i[1];
        end else begin
          guard_x0[j] = operand[idx(0, j2y(j - 11), 0) + j2z(j - 11)];
          guard_x1[j] = operand[idx(1, j2y(j - 11), 0) + j2z(j - 11)];
        end
      end
    end
    // end: guards
    
    // begin: chi_pr
    for (x = 0; x < 5; x = x + 1) begin
      for (y = 0; y < 5; y = y + 1) begin
        product[idx(x, y, 0) +: W] = operand_n[idx((x+1)%5, y, 0) +: W] &
                                       operand[idx((x+2)%5, y, 0) +: W];
        product[idx(x, y, 1) +: W] =   operand[idx((x+1)%5, y, 0) +: W] &
                                       operand[idx((x+2)%5, y, 1) +: W];
        product[idx(x, y, 2) +: W] =   operand[idx((x+1)%5, y, 1) +: W] &
                                       operand[idx((x+2)%5, y, 0) +: W];
        product[idx(x, y, 3) +: W] = operand_n[idx((x+1)%5, y, 1) +: W] &
                                       operand[idx((x+2)%5, y, 1) +: W];

        if (x == 0) begin
          state_do[idx(x, y, 0) +: W] = product[idx(x, y, 0) +: W] ^ guard_x0[y * W +: W] ^
                                        state_pseudorandom_i[y * W +: W];
          state_do[idx(x, y, 1) +: W] = product[idx(x, y, 1) +: W] ^ operand[idx(x, y, 0) +: W] ^
                                        state_pseudorandom_i[y * W +: W];
          state_do[idx(x, y, 2) +: W] = product[idx(x, y, 2) +: W] ^ operand[idx(x, y, 1) +: W] ^
                                        state_pseudorandom_i[320 + y * W +: W];
          state_do[idx(x, y, 3) +: W] = product[idx(x, y, 3) +: W] ^ guard_x0[y * W +: W] ^
                                        state_pseudorandom_i[320 + y * W +: W];
        end else if (x == 1) begin
          state_do[idx(x, y, 0) +: W] = product[idx(x, y, 0) +: W] ^ guard_x1[y * W +: W];
          state_do[idx(x, y, 1) +: W] = product[idx(x, y, 1) +: W] ^ operand[idx(x, y, 0) +: W];
          state_do[idx(x, y, 2) +: W] = product[idx(x, y, 2) +: W] ^ operand[idx(x, y, 1) +: W];
          state_do[idx(x, y, 3) +: W] = product[idx(x, y, 3) +: W] ^ guard_x1[y * W +: W];
        end else begin
          state_do[idx(x, y, 0) +: W] = product[idx(x, y, 0) +: W];
          state_do[idx(x, y, 1) +: W] = product[idx(x, y, 1) +: W] ^ operand[idx(x, y, 0) +: W];
          state_do[idx(x, y, 2) +: W] = product[idx(x, y, 2) +: W] ^ operand[idx(x, y, 1) +: W];
          state_do[idx(x, y, 3) +: W] = product[idx(x, y, 3) +: W];
        end
      end
    end
    // end: chi_pr
  end

endmodule
