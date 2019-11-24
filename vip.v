`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/20 10:16:08
// Design Name: 
// Module Name: vip
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


module vip(
    input           cam_pclk            ,  // 时钟信号
    //图像处理后的数据接口
    output          post_frame_vsync,  // 场同步信号
    output          post_frame_hsync,  // 行同步信号
    output          post_frame_de   ,  // 数据输入使能
    output   [15:0] post_rgb       /*synthesis keep*/ ,  // RGB565颜色数据
	 
    output  [23:0]  digit  ,            // 识别到的数字
	 
    input                 cam_vsync       ,  //cmos 场同步信号
    input                 cam_href        ,  //cmos 行同步信号
    input        [7:0]    cam_data      /*synthesis keep*/ ,  //cmos 数据
	 input           rst_n          
);

//parameter define
parameter NUM_ROW = 1  ;               // 需识别的图像的行数
parameter NUM_COL = 4  ;               // 需识别的图像的列数
parameter H_PIXEL = 480;               // 图像的水平像素
parameter V_PIXEL = 272;               // 图像的垂直像素
parameter DEPBIT  = 10 ;               // 数据位宽

//wire define
//wire [15:0] pre_rgb;
wire   [ 7:0]         img_y;
wire                  monoc;
wire                  monoc_fall;
wire   [DEPBIT-1:0]   row_border_addr;
wire   [DEPBIT-1:0]   row_border_data;
wire   [DEPBIT-1:0]   col_border_addr;
wire   [DEPBIT-1:0]   col_border_data;
wire   [3:0]          num_col;
wire   [3:0]          num_row;
wire                  hs_t0;
wire                  vs_t0;
wire                  de_t0;
wire   [ 1:0]         frame_cnt;
wire                  project_done_flag;

//*****************************************************
//**                    main code
//*****************************************************

parameter  WAIT_FRAME = 4'd10  ;             //寄存器数据稳定等待的帧个数

//reg define
reg             cam_vsync_d0   ;
reg             cam_vsync_d1   ;
reg             cam_href_d0    ;
reg             cam_href_d1    ;
reg    [3:0]    cmos_fps_cnt    ;             //等待帧数稳定计数器
reg             frame_val_flag ;             //帧有效的标志

reg    [7:0]    cam_data_d0    ;
reg    [15:0]   cmos_data_t    ;             //用于8位转16位的临时寄存器
reg             byte_flag      ;
reg             byte_flag_d0   ;
wire	[15:0]	 cmos_frame_data;
reg 	[10:0]				  cnt_h/*synthesis keep*/;
reg 	[10:0]				  cnt_v/*synthesis keep*/;
//wire define
wire            pos_vsync      ;
wire data_de/*synthesis keep*/;
//assign data_de=(cnt_h+1'b1) ? 1'b1: 1'b0 ;
assign data_de=cmos_frame_href_0;
//采输入场同步信号的上升沿
assign pos_vsync = (~cam_vsync_d1) & cam_vsync_d0;

//输出帧有效信号
assign  cmos_frame_vsync = frame_val_flag  ?  cam_vsync_d1  :  1'b0;
//输出行有效信号
assign  cmos_frame_href  = frame_val_flag  ?  cam_href_d1   :  1'b0;
//输出数据使能有效信号
assign  cmos_frame_clken = frame_val_flag  ?  byte_flag_d0  :  1'b0;
//输出数据
assign  cmos_frame_data  = frame_val_flag  ?  cmos_data_t   :  1'b0;

always@(posedge cam_pclk)begin
	if(cnt_h==11'd480)
		cnt_h<=11'b0;
	else	if(cmos_frame_href)
		cnt_h<=cnt_h+1'b1;
	else 
		cnt_h<=11'b0;
end
always@(posedge cam_pclk)begin
	 if(cnt_v==10'd272)
		cnt_v<=11'b0;
	else	if(cnt_h==11'd480)
		cnt_v<=cnt_v+1'b1;
	else 
		cnt_v<=cnt_v;
end
//图像分割
reg [10:0]x_pos;
reg [10:0]y_pos;
reg [15:0]cmos_frame_data_0;
reg cmos_frame_vsync_0;
reg cmos_frame_href_0;
always@(posedge cam_pclk)begin
	if(((cnt_h<=400)&&(cnt_h>=80))&&((cnt_v<=272)&&(cnt_v>=80)))begin
		x_pos<=cnt_v;
		y_pos<=cnt_h;
		cmos_frame_data_0<=cmos_frame_data;
	end
	else begin
		x_pos<=cnt_v;
		y_pos<=cnt_h;
		cmos_frame_data_0<=16'hffff;
	end
end 
always@(posedge cam_pclk)begin
	cmos_frame_vsync_0<=cmos_frame_vsync;
	cmos_frame_href_0<=cmos_frame_href;
end 
//采输入场同步信号的上升沿
always @(posedge cam_pclk or negedge rst_n) begin
    if(!rst_n) begin
        cam_vsync_d0 <= 1'b0;
        cam_vsync_d1 <= 1'b0;
        cam_href_d0 <= 1'b0;
        cam_href_d1 <= 1'b0;
    end
    else begin
        cam_vsync_d0 <= cam_vsync;
        cam_vsync_d1 <= cam_vsync_d0;
        cam_href_d0 <= cam_href;
        cam_href_d1 <= cam_href_d0;
    end
end

//对帧数进行计数
always @(posedge cam_pclk or negedge rst_n) begin
    if(!rst_n)
        cmos_fps_cnt <= 4'd0;
    else if(pos_vsync && (cmos_fps_cnt < WAIT_FRAME))
        cmos_fps_cnt <= cmos_fps_cnt + 4'd1;
end
//帧有效标志
always @(posedge cam_pclk or negedge rst_n) begin
    if(!rst_n)
        frame_val_flag <= 1'b0;
    else if((cmos_fps_cnt == WAIT_FRAME) && pos_vsync)
        frame_val_flag <= 1'b1;
    else;
end

//8位数据转16位RGB565数据
always @(posedge cam_pclk or negedge rst_n) begin
    if(!rst_n) begin
        cmos_data_t <= 16'd0;
        cam_data_d0 <= 8'd0;
        byte_flag <= 1'b0;
    end
    else if(cam_href) begin
        byte_flag <= ~byte_flag;
        cam_data_d0 <= cam_data;
        if(byte_flag)
            cmos_data_t <= {cam_data_d0,cam_data};
        else;
    end
    else begin
        byte_flag <= 1'b0;
        cam_data_d0 <= 8'b0;
    end
end

//产生输出数据有效信号(cmos_frame_clken)
always @(posedge cam_pclk or negedge rst_n) begin
    if(!rst_n)
        byte_flag_d0 <= 1'b0;
    else
        byte_flag_d0 <= byte_flag;
end

rgb2ycbcr u_rgb2ycbcr(
    //module clock
    .clk             (cam_pclk    ),            // 时钟信号
    .rst_n           (rst_n  ),            // 复位信号（低有效）
    //图像处理前的数据接口
    .pre_frame_vsync (cmos_frame_vsync_0),    // vsync信号
    .pre_frame_hsync (cmos_frame_href_0),    // href信号
    .pre_frame_de    (data_de   ),    // data enable信号
    .img_red         (cmos_frame_data_0[15:11] ),
    .img_green       (cmos_frame_data_0[10:5 ] ),
    .img_blue        (cmos_frame_data_0[ 4:0 ] ),
    //图像处理后的数据接口
    .post_frame_vsync(vs_t0),               // vsync信号
    .post_frame_hsync(hs_t0),               // href信号
    .post_frame_de   (de_t0),               // data enable信号
    .img_y           (img_y),
    .img_cb          (),
    .img_cr          ()
);

//二值化模块
binarization u_binarization(
    //module clock
    .clk                (cam_pclk    ),          // 时钟信号
    .rst_n              (rst_n  ),          // 复位信号（低有效）
    //图像处理前的数据接口
    .pre_frame_vsync    (vs_t0),            // vsync信号
    .pre_frame_hsync    (hs_t0),            // href信号
    .pre_frame_de       (de_t0),            // data enable信号
    .color              (img_y),
    //图像处理后的数据接口
    .post_frame_vsync   (post_frame_vsync), // vsync信号
    .post_frame_hsync   (post_frame_hsync), // href信号
    .post_frame_de      (post_frame_de   ), // data enable信号
    .monoc              (monoc           ), // 单色图像像素数据
    .monoc_fall         (monoc_fall      )
    //user interface
);

//投影模块
projection #(
    .NUM_ROW(NUM_ROW),
    .NUM_COL(NUM_COL),
    .H_PIXEL(H_PIXEL),
    .V_PIXEL(V_PIXEL),
    .DEPBIT (DEPBIT)
) u_projection(
    //module clock
    .clk                (cam_pclk),          // 时钟信号
    .rst_n              (rst_n  ),          // 复位信号（低有效）
    //Image data interface
    .frame_vsync        (post_frame_vsync), // vsync信号
    .frame_hsync        (post_frame_hsync), // href信号
    .frame_de           (post_frame_de   ), // data enable信号
    .monoc              (monoc           ), // 单色图像像素数据
    .ypos               (cnt_h),
    .xpos               (cnt_v),
    //project border ram interface
    .row_border_addr_rd (row_border_addr),
    .row_border_data_rd (row_border_data),
    .col_border_addr_rd (col_border_addr),
    .col_border_data_rd (col_border_data),
    //user interface
    .num_col            (num_col),
    .num_row            (num_row),
    .frame_cnt          (frame_cnt),
    .project_done_flag  (project_done_flag)
);

//数字特征识别模块
digital_recognition #(
    .NUM_ROW(NUM_ROW),
    .NUM_COL(NUM_COL),
    .H_PIXEL(H_PIXEL),
    .V_PIXEL(V_PIXEL),
    .NUM_WIDTH((NUM_ROW*NUM_COL<<2)-1)
)u_digital_recognition(
    //module clock
    .clk                (cam_pclk       ),        // 时钟信号
    .rst_n              (rst_n     ),        // 复位信号（低有效）
    //image data interface
    .monoc              (monoc     ),
    .monoc_fall         (monoc_fall),
    .color_rgb          (post_rgb  ),
    .xpos               (cnt_v      ),
    .ypos               (cnt_h      ),
    //project border ram interface
    .row_border_addr    (row_border_addr),
    .row_border_data    (row_border_data),
    .col_border_addr    (col_border_addr),
    .col_border_data    (col_border_data),
    .num_col            (num_col),
    .num_row            (num_row),
    //user interface
    .frame_cnt          (frame_cnt),
    .project_done_flag  (project_done_flag),
    .digit              (digit)
);

endmodule
