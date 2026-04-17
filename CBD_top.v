`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/01/06 17:23:02
// Design Name: 
// Module Name: CBD_top
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

`timescale 1ns / 1ps

module CBD_top(
    input clk, rstn, en, wen, eta,
    input hash_out_busyn,
    input [23:0] din_0, din_1,
    input [77:0] r0, r1,
    output reg din_req,
    output reg [23:0] dout_0, dout_1,
    output reg dout_valid
);
    reg [23:0] buffer_0, buffer_1;
    reg cbd_start, cbd_start_r;
    wire [11:0] u1_A1, u1_A2, u2_A1, u2_A2;
    wire u1_val, u2_val;
    reg [1:0] dout_cnt;
    reg [7:0] dout_total;
 
    reg [2:0] state, next_state;
 
    always @(posedge clk) begin
        if (rstn == 1'b0) state <= 0;
        else state <= next_state;
    end
 
    always @(*) begin
        if (rstn == 1'b0) next_state = 0;
        else begin
            case (state)
                0 : next_state = en ? 1 : 0;
                1 : next_state = hash_out_busyn ? 2 : 1;
                2 : next_state = wen ? (eta ? 3 : 4) : 2;
                3 : next_state = dout_cnt == 2 ? 5 : 3;
                4 : next_state = (dout_cnt == 3 || dout_total[7]) ? 5 : 4;
                5 : next_state = dout_total[7] ? 0 : 1;
                default : next_state = 0;
            endcase
        end
    end
 
    wire [1:0] dout_cnt_plus;
    assign dout_cnt_plus = dout_cnt + dout_valid;
 
    always @(posedge clk) begin
        case (state)
            3'd1 : begin
                din_req  <= hash_out_busyn;
                dout_cnt <= 2'd0;
            end
            3'd3, 3'd4 : begin
                din_req  <= 1'b0;
                dout_cnt <= dout_cnt_plus;
            end
            default : begin
                din_req  <= 1'b0;
                dout_cnt <= 2'd0;
            end
        endcase
 
        if (rstn == 1'b0)   dout_total <= 0;
        else if (en)         dout_total <= 0;
        else                 dout_total <= dout_total + u1_val;
    end
 
    reg [5:0] u1_din_s0, u1_din_s1, u2_din_s0, u2_din_s1;
    always @(posedge clk) begin
        case (state)
            3'd0 : begin
                buffer_0 <= 24'h0;
                buffer_1 <= 24'h0;
            end
            3'd2 : begin
                buffer_0 <= din_0;
                buffer_1 <= din_1;
            end
            3'd3 : begin
                buffer_0 <= dout_valid ? {12'h0, buffer_0[23:12]} : buffer_0;
                buffer_1 <= dout_valid ? {12'h0, buffer_1[23:12]} : buffer_1;
            end
            3'd4 : begin
                buffer_0 <= dout_valid ? {8'h0, buffer_0[23:8]} : buffer_0;
                buffer_1 <= dout_valid ? {8'h0, buffer_1[23:8]} : buffer_1;
            end
            default : begin
                buffer_0 <= buffer_0;
                buffer_1 <= buffer_1;
            end
        endcase
 
        case (state)
            3'd3 : begin
                u1_din_s0 <= buffer_0[5:0];
                u1_din_s1 <= buffer_1[5:0];
                u2_din_s0 <= buffer_0[11:6];
                u2_din_s1 <= buffer_1[11:6];
            end
            3'd4 : begin
                u1_din_s0 <= {1'b0, buffer_0[3:2], 1'b0, buffer_0[1:0]};
                u1_din_s1 <= {1'b0, buffer_1[3:2], 1'b0, buffer_1[1:0]};
                u2_din_s0 <= {1'b0, buffer_0[7:6], 1'b0, buffer_0[5:4]};
                u2_din_s1 <= {1'b0, buffer_1[7:6], 1'b0, buffer_1[5:4]};
            end
            default : begin
                u1_din_s0 <= 0;
                u1_din_s1 <= 0;
                u2_din_s0 <= 0;
                u2_din_s1 <= 0;
            end
        endcase
    end
 
    always @(posedge clk) cbd_start <= cbd_start_r;
    always @(posedge clk) begin
        case (state)
            3'd0 : cbd_start_r <= 0;
            3'd2 : cbd_start_r <= wen;
            3'd3 : cbd_start_r <= (dout_cnt == 2'd0) && dout_valid;
            3'd4 : cbd_start_r <= (~dout_cnt[1]) && dout_valid && (~dout_total[7]);
            default : cbd_start_r <= 1'b0;
        endcase
    end
 
    // 优化：合并 u1_val/u2_val 控制，减少分段使能 LUT
    // u1_val 和 u2_val 同拍有效时合并输出
    always @(posedge clk) begin
        if (rstn == 1'b0) begin
            dout_0 <= 0;
            dout_1 <= 0;
        end else if (u1_val) begin
            dout_0 <= {u2_A1, u1_A1};
            dout_1 <= {u2_A2, u1_A2};
        end else begin
            dout_0 <= 0;
            dout_1 <= 0;
        end
 
        case (state)
            3'd0       : dout_valid <= 1'b0;
            3'd3, 3'd4 : dout_valid <= u1_val;
            default    : dout_valid <= 1'b0;
        endcase
    end
 
    CBD u1(.clk(clk), .rstn(rstn), .random(r0), .en(cbd_start), .eta(eta),
           .in_seq(u1_din_s0), .in_xor_seq(u1_din_s1),
           .A1(u1_A1), .A2(u1_A2), .valid(u1_val));
 
    CBD u2(.clk(clk), .rstn(rstn), .random(r1), .en(cbd_start), .eta(eta),
           .in_seq(u2_din_s0), .in_xor_seq(u2_din_s1),
           .A1(u2_A1), .A2(u2_A2), .valid(u2_val));
 
endmodule
 
 
// ============================================================
// CBD
// ============================================================
module CBD(
    input clk, rstn, en, eta,
    input [5:0] in_seq, in_xor_seq,
    input [77:0] random,
    output [11:0] A1, A2,
    output reg valid
);
    wire [11:0] B_0, B_1, C_0, C_1;
    reg  [11:0] B0, B1, C0, C1;
    reg  b2a_start, lfsr_en, b2a_valid_r;
    reg  b2a_x_0, b2a_x_1, b2a_y_0, b2a_y_1;
    reg  [2:0] state, state_r;
    reg  [2:0] next_state;
    wire b2a_valid_1, b2a_valid_2;
    reg  [5:0] in_seq_reg, in_xor_seq_reg;
 
    // -------------------------------------------------------
    // 优化：r0/r1 改为 wire + 2bit 选择寄存器
    // 省去 26 个 FF，换成小 MUX
    // -------------------------------------------------------
    reg [1:0] rand_sel;
    wire [12:0] r0, r1;
 
    assign r0 = (rand_sel == 2'd1) ? random[25:13] :
                (rand_sel == 2'd2) ? random[12:0]  : random[38:26];
 
    assign r1 = (rand_sel == 2'd1) ? random[64:52] :
                (rand_sel == 2'd2) ? random[51:39] : random[77:65];
 
    always @(posedge clk) case (state)
        3'd0 : begin
            in_seq_reg     <= en ? in_seq     : 6'd0;
            in_xor_seq_reg <= en ? in_xor_seq : 6'd0;
        end
        default : begin
            in_seq_reg     <= in_seq_reg;
            in_xor_seq_reg <= in_xor_seq_reg;
        end
    endcase
 
    wire [2:0] x_0, x_1, y_0, y_1;
    assign x_0 = in_seq_reg[2:0];
    assign x_1 = in_xor_seq_reg[2:0];
    assign y_0 = in_seq_reg[5:3];
    assign y_1 = in_xor_seq_reg[5:3];
 
    always @(posedge clk) begin
        if (rstn == 1'b0) state <= 3'd0;
        else state <= next_state;
    end
 
    always @(posedge clk) state_r <= state;
    always @(posedge clk) b2a_valid_r <= b2a_valid_1;
 
    wire [2:0] state_plus;
    assign state_plus = state + 1'h1;
 
    always @(*) case (state)
        3'd0 : next_state = en ? (eta ? 1 : 4) : 0;
        3'd1 : next_state = (b2a_valid_1 && b2a_valid_2) ? state_plus : state;
        3'd2 : next_state = (b2a_valid_1 && b2a_valid_2) ? state_plus : state;
        3'd3 : next_state = (b2a_valid_1 && b2a_valid_2) ? 7 : state;
        3'd4 : next_state = (b2a_valid_1 && b2a_valid_2) ? state_plus : state;
        3'd5 : next_state = (b2a_valid_1 && b2a_valid_2) ? state_plus : state;
        3'd6 : next_state = 3'd0;
        3'd7 : next_state = 3'd0;
        default : next_state = 0;
    endcase
 
    // 优化：合并原来两个 always 块为一个，消除重复状态译码
    always @(posedge clk) case (state)
        3'd1, 3'd4 : begin
            b2a_x_0  <= x_0[0]; b2a_x_1 <= x_1[0];
            b2a_y_0  <= y_0[0]; b2a_y_1 <= y_1[0];
            rand_sel <= 2'd0;
        end
        3'd2, 3'd5 : begin
            b2a_x_0  <= x_0[1]; b2a_x_1 <= x_1[1];
            b2a_y_0  <= y_0[1]; b2a_y_1 <= y_1[1];
            rand_sel <= 2'd1;
        end
        3'd3 : begin
            b2a_x_0  <= x_0[2]; b2a_x_1 <= x_1[2];
            b2a_y_0  <= y_0[2]; b2a_y_1 <= y_1[2];
            rand_sel <= 2'd2;
        end
        default : begin
            b2a_x_0  <= 1'b0; b2a_x_1 <= 1'b0;
            b2a_y_0  <= 1'b0; b2a_y_1 <= 1'b0;
            rand_sel <= 2'd0;
        end
    endcase
 
    always @(posedge clk) case (state)
        3'd1, 3'd2, 3'd3, 3'd4, 3'd5 : begin
            if (state_r != state) lfsr_en <= 1'b1;
            else                  lfsr_en <= 1'b0;
        end
        default : lfsr_en <= 1'b0;
    endcase
 
    always @(posedge clk) b2a_start <= lfsr_en;
 
    always @(posedge clk) begin
        if (rstn == 1'b0) begin B0 <= 0; B1 <= 0; end
        else if (b2a_valid_1) begin B0 <= B_0; B1 <= B_1; end
        if (rstn == 1'b0) begin C0 <= 0; C1 <= 0; end
        else if (b2a_valid_2) begin C0 <= C_0; C1 <= C_1; end
    end
 
    wire [11:0] tmp_B0_C0, tmp_B1_C1;
    wire signed [12:0] R_B0_C0, Rq_B0_C0, R_B1_C1, Rq_B1_C1;
    assign R_B0_C0   = B0 - C0;
    assign Rq_B0_C0  = R_B0_C0 + 13'd3329;
    assign tmp_B0_C0 = R_B0_C0[12] ? Rq_B0_C0[11:0] : R_B0_C0[11:0];
    assign R_B1_C1   = B1 - C1;
    assign Rq_B1_C1  = R_B1_C1 + 13'd3329;
    assign tmp_B1_C1 = R_B1_C1[12] ? Rq_B1_C1[11:0] : R_B1_C1[11:0];
 
    reg [11:0] res_s0, res_s1;
    wire signed [13:0] R_res0_tmp, Rq_res0_tmp;
    wire signed [13:0] R_res1_tmp, Rq_res1_tmp;
    assign R_res0_tmp  = res_s0 + tmp_B0_C0;
    assign Rq_res0_tmp = R_res0_tmp - 14'd3329;
    assign R_res1_tmp  = res_s1 + tmp_B1_C1;
    assign Rq_res1_tmp = R_res1_tmp - 14'd3329;
 
    always @(posedge clk) begin
        if ((rstn == 1'b0) | en) begin
            res_s0 <= 0;
            res_s1 <= 0;
        end else if (b2a_valid_r) begin
            res_s0 <= Rq_res0_tmp[13] ? R_res0_tmp[11:0] : Rq_res0_tmp[11:0];
            res_s1 <= Rq_res1_tmp[13] ? R_res1_tmp[11:0] : Rq_res1_tmp[11:0];
        end
 
        case (state)
            3'd6, 3'd7 : valid <= 1;
            default    : valid <= 0;
        endcase
    end
 
    assign A1 = res_s0;
    assign A2 = res_s1;
 
    cbd_B2A_1bit BA1(
        .clk   (clk),
        .rstn  (rstn),
        .wen   (b2a_start),
        .A1    (b2a_x_0),
        .A2    (b2a_x_1),
        .random(r0),
        .valid (b2a_valid_1),
        .B1    (B_0),
        .B2    (B_1)
    );
 
    cbd_B2A_1bit BA2(
        .clk   (clk),
        .rstn  (rstn),
        .wen   (b2a_start),
        .A1    (b2a_y_0),
        .A2    (b2a_y_1),
        .random(r1),
        .valid (b2a_valid_2),
        .B1    (C_0),
        .B2    (C_1)
    );
 
endmodule
 
 
// ============================================================
// cbd_B2A_1bit
// ============================================================
module cbd_B2A_1bit(
    input        clk, rstn, wen,
    input        A1, A2,
    input [12:0] random,
    output reg [11:0] B1, B2,
    output reg   valid
);
    wire [12:0] a1_w = {12'd0, A1};
    wire [12:0] a2_w = {12'd0, A2};
    wire [12:0] b1_w = a1_w ^ random;
    wire [12:0] b2_w = a2_w ^ random;
    wire [12:0] c1_w = b2_w ^ random;  // = a2_w
    wire [12:0] c2_w = random;
 
    (* use_dsp = "yes" *) reg signed [13:0] psi1_raw, psi2_raw;
    reg [12:0] psi1_out, psi2_out;
 
    always @(posedge clk) begin
        if (!rstn) begin
            psi1_raw <= 0; psi2_raw <= 0;
            psi1_out <= 0; psi2_out <= 0;
        end else begin
            psi1_raw <= $signed({1'b0, b1_w ^ c1_w}) - $signed({1'b0, c1_w});
            psi2_raw <= $signed({1'b0, b1_w ^ c2_w}) - $signed({1'b0, c2_w});
            psi1_out <= psi1_raw[13] ? psi1_raw[12:0] + 13'd8192 : psi1_raw[12:0];
            psi2_out <= psi2_raw[13] ? psi2_raw[12:0] + 13'd8192 : psi2_raw[12:0];
        end
    end
 
    wire [12:0] gb_a1 = b1_w ^ psi1_out ^ psi2_out;
    wire [12:0] gb_a2 = b2_w;
 
    (* use_dsp = "yes" *) reg signed [13:0] dsp_r1, dsp_r2;
    reg [12:0] y1_r, y2_r;
    reg        y_valid;
 
    always @(posedge clk) begin
        if (!rstn) begin
            dsp_r1 <= 0; dsp_r2 <= 0;
            y1_r   <= 0; y2_r   <= 0; y_valid <= 0;
        end else begin
            dsp_r1  <= $signed({1'b0, gb_a1}) - 14'd6658;
            dsp_r2  <= $signed({1'b0, gb_a2}) - 14'd6658;
            y1_r    <= dsp_r1[13] ? gb_a1 : dsp_r1[12:0];
            y2_r    <= dsp_r2[13] ? gb_a2 : dsp_r2[12:0];
            y_valid <= wen;
        end
    end
 
    wire [12:0] d1, d2;
    wire        b2a_valid;
 
    B2A_1bit_6658 b2a(
        .clk   (clk),
        .rstn  (rstn),
        .wen   (y_valid),
        .u1    (~y1_r[0]),
        .u2    ( y2_r[0]),
        .random(random),
        .d1    (d1),
        .d2    (d2),
        .valid (b2a_valid)
    );
 
    wire [12:0] x1 = y1_r + 1'b1;
    wire [12:0] x2 = y2_r;
 
    (* use_dsp = "yes" *) reg signed [13:0] dsp_z1, dsp_z2;
    reg [12:0] z1_r, z2_r, tmp_r;
 
    always @(posedge clk) begin
        if (!rstn) begin
            dsp_z1 <= 0; dsp_z2 <= 0;
            z1_r   <= 0; z2_r   <= 0; tmp_r <= 0;
        end else begin
            dsp_z1 <= $signed({1'b0, x1}) - $signed({1'b0, d1});
            dsp_z2 <= $signed({1'b0, x2}) - $signed({1'b0, d2});
            z1_r   <= dsp_z1[13] ? dsp_z1[12:0] + 13'd6658 : dsp_z1[12:0];
            z2_r   <= dsp_z2[13] ? dsp_z2[12:0] + 13'd6658 : dsp_z2[12:0];
            tmp_r  <= {11'd0, z1_r[0]};
        end
    end
 
    (* use_dsp = "yes" *) reg signed [13:0] dsp_z1b;
    (* use_dsp = "yes" *) reg        [13:0] dsp_z2b;
    reg [12:0] z1_out, z2_out;
 
    always @(posedge clk) begin
        if (!rstn) begin
            dsp_z1b <= 0; dsp_z2b <= 0;
            z1_out  <= 0; z2_out  <= 0;
        end else begin
            dsp_z1b <= $signed({1'b0, z1_r}) - $signed({1'b0, tmp_r});
            dsp_z2b <= {1'b0, z2_r} + {1'b0, tmp_r};
            z1_out  <= dsp_z1b[13] ? dsp_z1b[12:0] + 13'd6658 : dsp_z1b[12:0];
            z2_out  <= (dsp_z2b >= 14'd6658) ? dsp_z2b[12:0] - 13'd6658 : dsp_z2b[12:0];
        end
    end
 
    always @(posedge clk) begin
        if (!rstn) begin
            B1 <= 0; B2 <= 0; valid <= 0;
        end else begin
            B1    <= z1_out[12:1];
            B2    <= z2_out[12:1];
            valid <= b2a_valid;
        end
    end
 
endmodule
 
 
// ============================================================
// B2A_1bit_6658
// ============================================================
module B2A_1bit_6658(
    input        clk, rstn, wen,
    input        u1, u2,
    input [12:0] random,
    output reg [12:0] d1, d2,
    output reg   valid
);
    (* use_dsp = "yes" *) reg signed [13:0] rq_sub;
    reg [12:0] RAND_Q;
 
    always @(posedge clk) begin
        rq_sub <= $signed({1'b0, random}) - 14'd6658;
        RAND_Q <= rq_sub[13] ? random : rq_sub[12:0];
    end
 
    (* use_dsp = "yes" *) reg signed [13:0] sub1, sub2;
 
    always @(posedge clk) begin
        if (!rstn) begin
            sub1 <= 0; sub2 <= 0;
            d1   <= 0; d2   <= 0; valid <= 0;
        end else begin
            sub1  <= $signed({1'b0, {12'd0, u1} ^ RAND_Q}) - 14'd6658;
            sub2  <= $signed({1'b0, {12'd0, u2} ^ RAND_Q}) - 14'd6658;
            d1    <= sub1[13] ? ({12'd0, u1} ^ RAND_Q) : sub1[12:0];
            d2    <= sub2[13] ? ({12'd0, u2} ^ RAND_Q) : sub2[12:0];
            valid <= wen;
        end
    end
endmodule
 
 
// ============================================================
// MODSUM_6658
// ============================================================
module MODSUM_6658 (input [12:0] A, B, output [12:0] C);
    wire [13:0] R = A + B;
    wire signed [14:0] Rq = R - 14'd6658;
    assign C = Rq[14] ? R[12:0] : Rq[12:0];
endmodule
 
 
// ============================================================
// MODSUB_6658
// ============================================================
module MODSUB_6658 (input [12:0] A, B, output [12:0] C);
    wire signed [13:0] R = A - B;
    assign C = R[13] ? (R + 14'd6658) : R[12:0];
endmodule
 
 
// ============================================================
// Refresh_6658
// ============================================================
module Refresh_6658 (
    input clk, rstn, wen,
    input  [12:0] v1, v2, random,
    output [12:0] a1, a2,
    output reg valid
);
    reg [12:0] a1_r, a2_r;
    wire signed [13:0] R1 = random - 13'd6658;
    wire [12:0] RAND_Q = R1[13] ? random : R1[12:0];
    wire [12:0] t1, t2;
 
    MODSUM_6658 msum (v1, RAND_Q, t1);
    MODSUB_6658 msub (v2, RAND_Q, t2);
 
    always @(posedge clk) begin
        if (!rstn) begin a1_r <= 0; a2_r <= 0; valid <= 0; end
        else begin
            if (wen) begin a1_r <= t1; a2_r <= t2; end
            valid <= wen;
        end
    end
    assign a1 = a1_r;
    assign a2 = a2_r;
endmodule

