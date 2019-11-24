`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/20 10:20:21
// Design Name: 
// Module Name: seg_bcd_dri
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


module seg_bcd_dri(
   //input
   input                  clk    ,        // ʱ���ź�
   input                  rst_n  ,        // ��λ�ź�
   input        [23:0]    num    ,        // 6�������Ҫ��ʾ����ֵ
   input        [5:0]     point  ,        // С���������ʾ��λ��,�Ӹߵ���,����Ч

   //output
   output  reg  [5:0]     sel    ,        // �����λѡ
   output  reg  [7:0]     seg_led ,        // ����ܶ�ѡ
   output  reg  [3:0]     signal
);

//parameter define
parameter  WIDTH0 = 10_000;

//reg define
reg    [15:0]             cnt0;           // 1ms����
reg    [2:0]              cnt;            // �л���ʾ�������
reg    [3:0]              num1;           // �͸�Ҫ��ʾ������ܣ�Ҫ���ĵ�
reg                       point1;         // Ҫ��ʾ��С����

//*****************************************************
//**                    main code
//*****************************************************

//����1ms
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0)
        cnt0 <= 15'b0;
    else if(cnt0 < WIDTH0)
        cnt0 <= cnt0 + 1'b1;
    else
        cnt0 <= 15'b0;
end

//����������������6��״̬����Ϊ��6���ƣ�
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0)
        cnt <= 3'b0;
    else if(cnt < 3'd6) begin
        if(cnt0 == WIDTH0)
            cnt <= cnt + 1'b1;
        else
            cnt <= cnt;
    end
    else
        cnt <= 3'b0;
end

//6�������������ʾ�����ˢ�£����ҵ���
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        sel  <= ~6'b000001;
        num1 <= 4'b0;
    end
    else begin
        case (cnt)
            3'd0:begin
                 sel    <=~6'b111110;
                 num1   <= num[3:0] ;
                 point1 <= ~point[0] ;
            end
            3'd1:begin
                 sel    <=~6'b111101;
                 num1   <= num[7:4] ;
                 point1 <= ~point[1] ;
            end
            3'd2:begin
                 sel    <=~6'b111011;
                 num1   <= num[11:8];
                 point1 <= ~point[2] ;
            end
            3'd3:begin
                 sel    <=~6'b110111 ;
                 num1   <= num[15:12];
                 point1 <= ~point[3]  ;
            end
            3'd4:begin
                 sel    <= ~6'b101111 ;
                 num1   <= num[19:16];
                 point1 <= ~point[4]  ;
            end
            3'd5:begin
                 sel    <= ~6'b011111 ;
                 num1   <= num[23:20];
                 point1 <= ~point[5]  ;
            end
            default: begin
                 sel    <= ~6'b000000;
                 num1   <= 4'b0;
                 point1 <= 1'b0;
            end
        endcase
    end
end

//�������ʾ����
always @ (posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0)
        seg_led <= ~7'b0;
    else begin
        case(num1)
            4'd0: seg_led <= {point1,~7'b1000000};
            4'd1: seg_led <= {point1,~7'b1111001};
            4'd2: seg_led <= {point1,~7'b0100100};
            4'd3: seg_led <= {point1,~7'b0110000};
            4'd4: seg_led <= {point1,~7'b0011001};
            4'd5: seg_led <= {point1,~7'b0010010};
            4'd6: seg_led <= {point1,~7'b0000010};
            4'd7: seg_led <= {point1,~7'b1111000};
            4'd8: seg_led <= {point1,~7'b0000000};
            4'd9: seg_led <= {point1,~7'b0010000};
            default: seg_led <= {~point1,~7'b1000000};
        endcase
    end
end


always @ (posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0)
        signal <= ~7'b0;
    else begin
        case(num[3:0])
            4'd0: signal <= 4'b0000;
            4'd1: signal <= 4'b0001;
            4'd2: signal <= 4'b0010;
            4'd3: signal <= 4'b0011;
            4'd4: signal <= 4'b0100;
            4'd5: signal <= 4'b0101;
            4'd6: signal <= 4'b0110;
            4'd7: signal <= 4'b0111;
            4'd8: signal <= 4'b1000;
            4'd9: signal <= 4'b1001;
            default: signal <= 4'b0000;
        endcase
    end
end

endmodule
