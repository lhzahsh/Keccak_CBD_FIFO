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
    
    CBD u1(.clk(clk), .rstn(rstn), .en(cbd_start), .eta(eta), .in_seq(u1_din_s0), .in_xor_seq(u1_din_s1), .A1(u1_A1), .A2(u1_A2), .valid(u1_val)); // 48bit  randmdata?
    CBD u2(.clk(clk), .rstn(rstn), .en(cbd_start), .eta(eta), .in_seq(u2_din_s0), .in_xor_seq(u2_din_s1), .A1(u2_A1), .A2(u2_A2), .valid(u2_val)); // 48bit  randmdata?

endmodule

module CBD(
    input clk, rstn, en, eta,
    input [5:0] in_seq, in_xor_seq,
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

// c0+c1 = a0 ^ a1;
module cbd_B2A_1bit(
    input clk, rstn, b2a_start,
    input B0, B1,                   //input value 
    input [11:0] I_r0, I_r1, I_r2,    //random value 
   
    output reg b2a_valid,
    output [11:0] out_A0,   
    output [11:0] out_A1  
);
    reg [11:0] t_s0_reg, t_s1_reg;
    wire [11:0] inv_r0, inv_r1;
    wire [11:0] t0_s0, t0_s1, t1_s0, t1_s1, t_s0, t_s1;
    assign inv_r0 = 12'd3329 - I_r0;
    assign inv_r1 = 12'd3330 - I_r1;
    assign {t0_s0, t0_s1} = B0 ? {I_r1, inv_r1} : {I_r0, inv_r0};
    assign {t1_s0, t1_s1} = B0 ? {I_r0, inv_r0} : {I_r1, inv_r1};
    assign {t_s0, t_s1} = B1 ? {t1_s0, t1_s1} : {t0_s0, t0_s1};
    
    wire [12:0] R_t_s0_plus_r2;
    wire [13:0] Rq_t_s0_plus_r2;
    wire signed [12:0]  R_t_s1_sub_r2, Rq_t_s1_sub_r2;
    assign R_t_s0_plus_r2 = t_s0_reg + I_r2;
    assign Rq_t_s0_plus_r2 = R_t_s0_plus_r2 - 13'd3329;
    assign R_t_s1_sub_r2 = t_s1_reg - I_r2;
    assign Rq_t_s1_sub_r2 = R_t_s1_sub_r2 + 12'd3329;
    assign out_A0 = Rq_t_s0_plus_r2[13] ? R_t_s0_plus_r2[11:0] : Rq_t_s0_plus_r2[11:0];
    assign out_A1 = R_t_s1_sub_r2[12] ? Rq_t_s1_sub_r2[11:0] : R_t_s1_sub_r2[11:0];
    
    always @(posedge clk) begin
        if (rstn == 1'b0) begin
            t_s0_reg <= 0;
            t_s1_reg <= 0;
        end else if (b2a_start) begin
            t_s0_reg <= t_s0;
            t_s1_reg <= t_s1;
        end 
        b2a_valid <= b2a_start;
    end 
endmodule 

module cbd_LFSR(
    input clk, rstn, en,
    output reg [71:0] dout
);
    reg [35:0] lfsr0, lfsr1;
    always @(posedge clk) begin
        if (rstn == 1'b0) begin
            lfsr0 <= 36'ha7b80018f;
            lfsr1 <= 36'hef801161c;
        end else begin
            lfsr0 <= {lfsr0[33:0], lfsr0[35]^lfsr0[10], lfsr0[34]^lfsr0[20]};
            lfsr1 <= {lfsr1[33:0], lfsr1[34]^lfsr1[15], lfsr1[35]^lfsr1[25]};
        end 
        if (rstn == 1'b0) dout <= 0;
        else if (en) dout <= {lfsr0&36'h7ff7ff7ff, lfsr1&36'h7ff7ff7ff}; // 12bit in [0,3329)
    end 
endmodule