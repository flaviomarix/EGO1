`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/20 10:18:53
// Design Name: 
// Module Name: binarization
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


module binarization(
    //module clock
    input               clk             ,   // ʱ���ź�
    input               rst_n           ,   // ��λ�źţ�����Ч��

    //ͼ����ǰ�����ݽӿ�
    input               pre_frame_vsync ,   // vsync�ź�
    input               pre_frame_hsync ,   // hsync�ź�
    input               pre_frame_de    ,   // data enable�ź�
    input   [7:0]       color           ,

    //ͼ���������ݽӿ�
    output              post_frame_vsync,   // vsync�ź�
    output              post_frame_hsync,   // hsync�ź�
    output              post_frame_de   ,   // data enable�ź�
    output   reg       /*synthesis keep*/ monoc          ,   // monochrome��1=�ף�0=�ڣ�
    output              monoc_fall

    //user interface
);

//reg define
reg    monoc_d0;
reg    pre_frame_vsync_d;
reg    pre_frame_hsync_d;
reg    pre_frame_de_d   ;

//*****************************************************
//**                    main code
//*****************************************************

assign  monoc_fall       = (!monoc) & monoc_d0;
assign  post_frame_vsync = pre_frame_vsync_d  ;
assign  post_frame_hsync = pre_frame_hsync_d  ;
assign  post_frame_de    = pre_frame_de_d     ;

//�Ĵ������½���
always @(posedge clk) begin
    monoc_d0 <= monoc;
end

//��ֵ��
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        monoc <= 1'b0;
    else if(color > 8'd30)  //��ֵ
        monoc <= 1'b1;
    else
        monoc <= 1'b0;
end

//��ʱ2����ͬ��ʱ���ź�
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        pre_frame_vsync_d <= 1'd0;
        pre_frame_hsync_d <= 1'd0;
        pre_frame_de_d    <= 1'd0;
    end
    else begin
        pre_frame_vsync_d <= pre_frame_vsync;
        pre_frame_hsync_d <= pre_frame_hsync;
        pre_frame_de_d    <= pre_frame_de   ;
    end
end

endmodule
