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

module CBD_top(
    input clk, rstn, en, wen, eta,
    input hash_out_busyn,
    input [23:0] din_0, din_1,
    input [35:0] r0,r1,
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
    
    //wire [23:0] test_cbd_out;
    //assign test_cbd_out = dout_0 + dout_1;
    
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
                din_req <= hash_out_busyn;
                dout_cnt <= 2'd0;
            end 
            3'd3, 3'd4 : begin
                din_req <= 1'b0;
                dout_cnt <= dout_cnt_plus;
            end 
            default : begin
                din_req <= 1'b0;
                dout_cnt <= 2'd0;
            end 
        endcase

        
        if (rstn == 1'b0) dout_total <= 0;
        else if (en) dout_total <= 0;
        else dout_total <= dout_total + u1_val;
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
            3'd3 : cbd_start_r <= (dout_cnt==2'd0) && dout_valid;
            3'd4 : cbd_start_r <= (~dout_cnt[1]) && dout_valid && (~dout_total[7]);
            default : cbd_start_r <= 1'b0;
        endcase
    end 
    
    always @(posedge clk) begin
        if (rstn == 1'b0) begin
            dout_0[23:12] <= 0;
            dout_1[23:12] <= 0;
        end else if (u1_val) begin
            dout_0[23:12] <= u2_A1;
            dout_1[23:12] <= u2_A2;            
        end else begin
            dout_0[23:12] <= 0;
            dout_1[23:12] <= 0;
        end 
        
        if (rstn == 1'b0) begin
            dout_0[11:0] <= 0;
            dout_1[11:0] <= 0;
        end else if (u2_val) begin
            dout_0[11:0] <= u1_A1;
            dout_1[11:0] <= u1_A2;            
        end else begin
            dout_0[11:0] <= 0;
            dout_1[11:0] <= 0;
        end 
        
        case (state)
            3'd0 : dout_valid <= 1'b0;
            3'd3, 3'd4 : dout_valid <= u1_val;
            default : dout_valid <= 1'b0;
        endcase
        
    end 
    
    CBD u1(.clk(clk), .rstn(rstn),.random(r0),.en(cbd_start), .eta(eta), .in_seq(u1_din_s0), .in_xor_seq(u1_din_s1), .A1(u1_A1), .A2(u1_A2), .valid(u1_val)); // 36bit  randmdata
    CBD u2(.clk(clk), .rstn(rstn),.random(r1),.en(cbd_start), .eta(eta), .in_seq(u2_din_s0), .in_xor_seq(u2_din_s1), .A1(u2_A1), .A2(u2_A2), .valid(u2_val)); // 36bit  randmdata

endmodule

module CBD(
    input clk, rstn, en, eta,
    input [5:0] in_seq, in_xor_seq,
    input [35:0] random,
    output [11:0] A1, A2,
    output reg valid 
);        
    wire [11:0] B_0,B_1,C_0,C_1;
    reg [11:0] B0, B1, C0, C1;
    reg b2a_start, lfsr_en, b2a_valid_r;
    reg b2a_x_0,b2a_x_1,b2a_y_0,b2a_y_1;
    reg [2:0] state, state_r;
    reg [2:0] next_state;
    wire b2a_valid_1,b2a_valid_2;
    wire [71:0] rand72;
    reg [5:0] in_seq_reg, in_xor_seq_reg;

    always @(posedge clk) case (state)
        3'd0 : begin 
            in_seq_reg <= en ? in_seq : 6'd0;
            in_xor_seq_reg <= en ? in_xor_seq : 6'd0;
        end 
        default : begin 
            in_seq_reg <= in_seq_reg;
            in_xor_seq_reg <= in_xor_seq_reg;
        end 
    endcase
    
    wire [2:0] x_0, x_1, y_0, y_1;
    assign x_0 = in_seq_reg[2:0];
    assign x_1 = in_xor_seq_reg[2:0];
    assign y_0 = in_seq_reg[5:3];
    assign y_1 = in_xor_seq_reg[5:3];
    
    always @(posedge clk) begin
        if(rstn == 1'b0) state <= 3'd0;
        else state <= next_state;
    end
       
    always @(posedge clk) state_r <= state;
    always @(posedge clk) b2a_valid_r <= b2a_valid_1;
    
    wire [2:0] state_plus;
    assign state_plus = state + 1'h1;
    always @(*) case(state)
             3'd0 : next_state = en ? (eta ? 1 : 4) : 0;
             3'd1 : next_state = (b2a_valid_1 == 1'b1 && b2a_valid_2 == 1'b1) ? state_plus : state;
             3'd2 : next_state = (b2a_valid_1 == 1'b1 && b2a_valid_2 == 1'b1) ? state_plus : state;
             3'd3 : next_state = (b2a_valid_1 == 1'b1 && b2a_valid_2 == 1'b1) ? 7 : state;
             3'd4 : next_state = (b2a_valid_1 == 1'b1 && b2a_valid_2 == 1'b1) ? state_plus : state;
             3'd5 : next_state = (b2a_valid_1 == 1'b1 && b2a_valid_2 == 1'b1) ? state_plus : state;
             3'd6 : next_state = 3'd0;
             3'd7 : next_state = 3'd0;
        default :  next_state = 0 ;
    endcase
      
    always @(posedge clk) case(state)
        3'd1, 3'd4 : begin 
            b2a_x_0 <= x_0[0];
            b2a_x_1 <= x_1[0];
        end
        3'd2, 3'd5 : begin 
            b2a_x_0 <= x_0[1];
            b2a_x_1 <= x_1[1];
        end
        3'd3 : begin 
            b2a_x_0 <= x_0[2];
            b2a_x_1 <= x_1[2];
        end
        default :
        begin 
            b2a_x_0 <= 1'b0;
            b2a_x_1 <= 1'b0;
        end
    endcase   

    always @(posedge clk) case(state)
        3'd1,3'd2,3'd3,3'd4,3'd5 : begin
            if (state_r != state) lfsr_en <= 1'b1;
            else lfsr_en <= 1'b0;    
        end 
        default : begin 
            lfsr_en <= 1'b0;
        end 
    endcase 
    
    always @(posedge clk) b2a_start <= lfsr_en;

    always @(posedge clk) case(state)
        3'd1, 3'd4 : begin
            b2a_y_0 <= y_0[0];
            b2a_y_1 <= y_1[0];
        end
        3'd2, 3'd5 : begin  
            b2a_y_0 <= y_0[1];
            b2a_y_1 <= y_1[1];
        end
        3'd3 : begin  
            b2a_y_0 <= y_0[2];
            b2a_y_1 <= y_1[2];
        end
        default :
        begin  
            b2a_y_0 <= 1'b0;
            b2a_y_1 <= 1'b0;
        end
    endcase   
    
    always @(posedge clk) begin
        if (rstn == 1'b0) begin B0 <= 0; B1 <= 0; end 
        else if (b2a_valid_1) begin B0 <= B_0; B1 <= B_1; end 
        if (rstn == 1'b0) begin C0 <= 0; C1 <= 0; end 
        else if (b2a_valid_2) begin C0 <= C_0; C1 <= C_1; end 
    end 
    

    wire [11:0] tmp_B0_C0, tmp_B1_C1;
    wire signed [12:0] R_B0_C0, Rq_B0_C0, R_B1_C1, Rq_B1_C1;
    assign R_B0_C0 = B0 - C0;
    assign Rq_B0_C0 = R_B0_C0 + 13'd3329;
    assign tmp_B0_C0 = R_B0_C0[12] ? Rq_B0_C0[11:0] : R_B0_C0;
    assign R_B1_C1 = B1 - C1;
    assign Rq_B1_C1 = R_B1_C1 + 13'd3329;
    assign tmp_B1_C1 = R_B1_C1[12] ? Rq_B1_C1[11:0] : R_B1_C1;
    
    reg [11:0] res_s0, res_s1;
    wire signed [13:0] R_res0_tmp_B0_C0, Rq_res0_tmp_B0_C0;
    wire signed [13:0] R_res1_tmp_B1_C1, Rq_res1_tmp_B1_C1;
    assign R_res0_tmp_B0_C0 = res_s0 + tmp_B0_C0;
    assign Rq_res0_tmp_B0_C0 = R_res0_tmp_B0_C0 - 14'd3329;
    assign R_res1_tmp_B1_C1 = res_s1 + tmp_B1_C1;
    assign Rq_res1_tmp_B1_C1 = R_res1_tmp_B1_C1 - 14'd3329;
    
    always @(posedge clk) begin
        if ((rstn == 1'b0) | en) begin
            res_s0 <= 0;
            res_s1 <= 0;
        end else if (b2a_valid_r) begin
            res_s0 <= Rq_res0_tmp_B0_C0[13] ? R_res0_tmp_B0_C0[11:0] : Rq_res0_tmp_B0_C0[11:0];
            res_s1 <= Rq_res1_tmp_B1_C1[13] ? R_res1_tmp_B1_C1[11:0] : Rq_res1_tmp_B1_C1[11:0];
        end

        case (state)
            3'd6, 3'd7 : valid <= 1;
            default : valid <= 0;
        endcase
        /*
        if (rstn == 1'b0) valid <= 0;
        else if (state == 3'd6 || state == 3'd7) valid <= 1;
        else valid <= 0; */
    end
    assign A1 = res_s0;
    assign A2 = res_s1;
    
    cbd_B2A_1bit BA1(
        .clk(clk),
        .rstn(rstn),
        .b2a_start(b2a_start),
        .B0(b2a_x_0),   
        .B1(b2a_x_1),  
        .I_r0(rand72[11:0]),
        .I_r1(rand72[23:12]),
        .I_r2(rand72[35:24]),
        .b2a_valid(b2a_valid_1),   
        .out_A0(B_0),
        .out_A1(B_1)
    );
    cbd_B2A_1bit BA2(
        .clk(clk),
        .rstn(rstn),
        .b2a_start(b2a_start),
        .B0(b2a_y_0),   
        .B1(b2a_y_1),
        .I_r0(rand72[47:36]),
        .I_r1(rand72[59:48]),
        .I_r2(rand72[71:60]),
        .b2a_valid(b2a_valid_2),  
        .out_A0(C_0),
        .out_A1(C_1)
    );
    cbd_LFSR random(
        .clk(clk),
        .rstn(rstn),
        .en(lfsr_en),
        .dout(rand72)
    );
    
endmodule


module cbd_B2A_1bit (
    input  clk, rstn, wen,
    input  A1, A2,
    input  [12:0] random,
    output reg [11:0] B1, B2,
    output reg valid
);
    localparam [25:0] K = 26'd33556320; // 10080 × 3329

    reg  gb_wen, mred_wen;
    reg  [11:0] u1, u2;
    wire [24:0] gb_a1, gb_a2;
    wire gb_valid, mred1_valid;

    // DSP: gb_a * K，取高 27 位送 MODRED
    (* use_dsp = "yes" *) reg [50:0] tmp1_dsp, tmp2_dsp;
    reg [26:0] tmp1_r, tmp2_r;

    always @(*) begin
        tmp1_dsp = gb_a1 * K;
        tmp2_dsp = gb_a2 * K;
    end

    always @(posedge clk) begin
        if (!rstn) begin
            gb_wen <= 0; u1 <= 0; u2 <= 0;
            tmp1_r <= 0; tmp2_r <= 0;
        end else begin
            gb_wen <= wen;
            if (wen) begin u1 <= {10'd0, A1}; u2 <= {10'd0, A2}; end
            if (gb_valid) begin tmp1_r <= tmp1_dsp[50:24]; tmp2_r <= tmp2_dsp[50:24]; end
        end
    end

    // 输出拼接与修正
    wire [12:0] y1, y2;
    wire [12:0] x1 = y1 + 1;
    wire [12:0] b2a_y1, b2a_y2;
    wire b2a_valid;
    wire [12:0] z1_s1, z2_s1, z1_s2, z2_s2;
    wire [12:0] carry = {11'd0, z1_s1[0]};

    always @(posedge clk) begin
        if (!rstn) begin B1 <= 0; B2 <= 0; valid <= 0; end
        else begin
            B1    <= z1_s2[12:1];
            B2    <= z2_s2[12:1];
            valid <= b2a_valid;
        end
        mred_wen <= gb_valid;
    end

    Goubin_12bit goubin (
        .clk(clk), .rstn(rstn), .wen(gb_wen),
        .u1(u1), .u2(u2), .random(random),
        .A1(gb_a1), .A2(gb_a2), .valid(gb_valid));

    MODRED_6658 mred1 (
        .clk(clk), .rstn(rstn), .wen(mred_wen),
        .A(tmp1_r), .B(y1), .valid(mred1_valid));

    MODRED_6658 mred2 (
        .clk(clk), .rstn(rstn), .wen(mred_wen),
        .A(tmp2_r), .B(y2));  // valid 不需要再引出

    B2A_1bit_6658 b2a (
        .clk(clk), .rstn(rstn), .wen(mred1_valid),
        .u1(~y1[0]), .u2(y2[0]), .random(random[12:0]),
        .d1(b2a_y1), .d2(b2a_y2), .valid(b2a_valid));

    MODSUB_6658 sub1 (x1,      b2a_y1, z1_s1);
    MODSUB_6658 sub2 (y2,      b2a_y2, z2_s1);
    MODSUM_6658 sum1 (z2_s1,   carry,  z2_s2);
    MODSUB_6658 sub3 (z1_s1,   carry,  z1_s2);

endmodule

// c0+c1 = a0 ^ a1;
module MODSUM_6658 (input [12:0] A, B, output [12:0] C);
    wire [13:0] R = A + B;
    wire signed [14:0] Rq = R - 14'd6658;
    assign C = Rq[14] ? R[12:0] : Rq[12:0];
endmodule

module MODSUB_6658 (input [12:0] A, B, output [12:0] C);
    wire signed [13:0] R = A - B;
    assign C = R[13] ? (R + 14'd6658) : R[12:0];
endmodule

// ───────── Refresh_6658 ──────────────────────────────────────────────────

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
    assign a1 = a1_r; assign a2 = a2_r;
endmodule

// ───────── MODRED_6658 ───────────────────────────────────────────────────

module MODRED_6658 (
    input clk, rstn, wen,
    input  [26:0] A,
    output reg [12:0] B,
    output reg valid
);
    localparam [13:0] INV = 14'd10080;  // ceil(2^26 / 6658)
    (* use_dsp = "yes" *) reg [40:0] t_dsp;
    reg [14:0] t_r;
    (* use_dsp = "yes" *) reg [27:0] a_dsp;
    wire signed [28:0] diff  = A - a_dsp;
    wire signed [28:0] diffq = diff + 13'd6658;
    reg wen_r;

    always @(*) begin
        t_dsp = A * INV;
        a_dsp = t_r * 13'd6658;
    end
    always @(posedge clk) begin
        if (!rstn) begin t_r <= 0; B <= 0; end
        else begin
            if (wen) t_r <= t_dsp[40:26];
            B <= diff[28] ? diffq[12:0] : diff[12:0];
        end
        wen_r <= wen; valid <= wen_r;
    end
endmodule

// ───────── B2A_1bit_6658 ─────────────────────────────────────────────────

module B2A_1bit_6658 (
    input clk, rstn, wen,
    input  u1, u2,
    input  [12:0] random,
    output [12:0] d1, d2,
    output valid
);
    wire [12:0] rq1_a1, rq1_a2;
    wire rq1_valid, rq2_valid;
    reg  [12:0] c1_r, c2_r;
    reg  rq2_wen;

    wire [12:0] b1 = u1 ? (13'd6658 - rq1_a1) : rq1_a1;
    wire [12:0] b2 = u1 ? (13'd6658 - rq1_a2) : rq1_a2;

    always @(posedge clk) begin
        if (!rstn) begin c1_r <= 0; c2_r <= 0; rq2_wen <= 0; end
        else begin
            if (rq1_valid) begin c1_r <= b1 + u1; c2_r <= b2; end
            rq2_wen <= rq1_valid;
        end
    end

    Refresh_6658 rq1 (.clk(clk), .rstn(rstn), .wen(wen),
        .v1({12'd0, u2}), .v2(13'd0), .random(random),
        .a1(rq1_a1), .a2(rq1_a2), .valid(rq1_valid));

    Refresh_6658 rq2 (.clk(clk), .rstn(rstn), .wen(rq2_wen),
        .v1(c1_r), .v2(c2_r), .random(random),
        .a1(d1), .a2(d2), .valid(rq2_valid));

    assign valid = rq2_valid;
endmodule

// ───────── Goubin_12bit ──────────────────────────────────────────────────

module Goubin_12bit (
    input clk, rstn, wen,
    input  [11:0] u1, u2,
    input  [24:0] random,
    output [24:0] A1, A2,
    output reg valid
);
    reg wen_r;
    reg [24:0] b1_r, b2_r, d_r;

    wire [24:0] b1 = {13'd0, u1} ^ random;
    wire [24:0] b2 = {13'd0, u2} ^ random;
    wire [24:0] c1 = b2_r ^ random;
    wire [24:0] c2 = random;
    wire [24:0] tmp = b1_r ^ Psi(b1_r, c1) ^ Psi(b1_r, c2);

    always @(posedge clk) begin
        wen_r <= wen; valid <= wen_r;
        if (!rstn) begin b1_r <= 0; b2_r <= 0; d_r <= 0; end
        else begin
            b1_r <= wen   ? b1  : 0;
            b2_r <= wen   ? b2  : (wen_r ? b2_r : 0);
            d_r  <= wen_r ? tmp : 0;
        end
    end
    assign A1 = d_r; assign A2 = b2_r;

    function [24:0] Psi;
        input [24:0] x, r;
        reg signed [25:0] t;
        begin
            t = (x ^ r) - r;
            Psi = t[25] ? t + 33554432 : t[24:0];
        end
    endfunction
endmodule


