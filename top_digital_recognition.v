`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/20 10:13:23
// Design Name: 
// Module Name: top_digital_recognition
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


module top_digital_recognition(
    input                 sys_clk     ,  //系统时钟
    input                 sys_rst_n   ,  //系统复位，低电平有效
    //摄像头接口
    input                 cam_pclk    ,  //cmos 数据像素时钟
    input                 cam_vsync   ,  //cmos 场同步信号
    input                 cam_href    ,  //cmos 行同步信号
    input        [7:0]    cam_data    ,  //cmos 数据
    output                cam_rst_n   ,  //cmos 复位信号，低电平有效
    output                cam_pwdn    ,  //cmos 电源休眠模式选择信号
    output                cam_scl     ,  //cmos SCCB_SCL线
    inout                 cam_sda     ,  //cmos SCCB_SDA线
	 //lcd接口
    //output                lcd_hs      ,  //LCD 行同步信号
    //output                lcd_vs      ,  //LCD 场同步信号
    //output                lcd_de      ,  //LCD 数据输入使能
   // inout        [15:0]   lcd_rgb     ,  //LCD RGB565颜色数据
   // output                lcd_bl      ,  //LCD 背光控制信号
   // output                lcd_rst     ,  //LCD 复位信号
    //output                lcd_pclk    ,  //LCD 采样时钟
    //seg led
    output   [5:0]  sel               ,  //数码管位选
    output   [7:0]  seg_led           ,              //数码管段选
    output   [3:0]  signal
    );

//parameter define
parameter  SLAVE_ADDR = 7'h3c         ;  //OV5640的器件地址7'h3c
parameter  BIT_CTRL   = 1'b1          ;  //OV5640的字节地址为16位  0:8位 1:16位
parameter  CLK_FREQ   = 27'd100_000_000; //i2c_dri模块的驱动时钟频率
parameter  I2C_FREQ   = 18'd250_000   ;  //I2C的SCL时钟频率,不超过400KHz
parameter  NUM_ROW    = 1'd1          ;  //需识别的图像的行数
parameter  NUM_COL    = 3'd4          ;  //需识别的图像的列数
parameter  H_PIXEL    = 9'd480        ;  //图像的水平像素
parameter  V_PIXEL    = 9'd272        ;  //图像的垂直像素
parameter  DEPBIT     = 4'd10         ;  //数据位宽

//wire define
wire                  clk_100m        ;  //100mhz时钟,SDRAM操作时钟
wire                  clk_100m_lcd    ;  //100mhz时钟
wire                  clk_lcd         ;  //提供给IIC驱动时钟和lcd驱动时钟
wire                  locked          ;
wire                  rst_n           ;

wire                  i2c_exec        ;  //I2C触发执行信号
wire   [23:0]         i2c_data        ;  //I2C要配置的地址与数据(高8位地址,低8位数据)
wire                  cam_init_done   ;  //摄像头初始化完成
wire                  i2c_done        ;  //I2C寄存器配置完成信号
wire                  i2c_dri_clk     ;  //I2C操作时钟
wire   [ 7:0]         i2c_data_r      ;  //I2C读出的数据
wire                  i2c_rh_wl       ;  //I2C读写控制信号

wire                  wr_en           ;  //sdram_ctrl模块写使能
wire   [15:0]         wr_data         ;  //sdram_ctrl模块写数据
wire                  rd_en           ;  //sdram_ctrl模块读使能
wire   [15:0]         rd_data         ;  //sdram_ctrl模块读数据

wire                  sys_init_done   ;  //系统初始化完成(sdram初始化+摄像头初始化)
wire   [15:0]         rgb             ;
//wire   [15:0]         ID_lcd          ;  //LCD的ID
wire   [12:0]         cmos_h_pixel    ;  //CMOS水平方向像素个数
wire   [12:0]         cmos_v_pixel    ;  //CMOS垂直方向像素个数
wire   [12:0]         total_h_pixel   ;  //水平总像素大小
wire   [12:0]         total_v_pixel   ;  //垂直总像素大小
wire   [23:0]         sdram_max_addr  ;  //sdram读写的最大地址

wire   [23:0]         digit           ;  //识别到的数字
//wire   [15:0]         color_rgb       ;
wire   [10:0]         xpos            ;  //像素点横坐标
wire   [10:0]         ypos            ;  //像素点纵坐标
/*wire                  hs_t            ;
wire                  vs_t            ;
wire                  de_t            ;*/

//*****************************************************
//**                    main code
//*****************************************************
//assign lcd_rst=rst_n;
//assign lcd_pclk=cam_pclk;
//assign  lcd_bl = 1'b1;
assign  rst_n = sys_rst_n & locked;
//系统初始化完成：SDRAM和摄像头都初始化完成
//避免了在SDRAM初始化过程中向里面写入数据
assign  sys_init_done = cam_init_done;
assign  cam_rst_n = 1'b1;
//电源休眠模式选择 0：正常模式 1：电源休眠模式
assign  cam_pwdn = 1'b0;
//assign  lcd_de = 1'b1;

//锁相环
pll u_pll(
    .reset       (~sys_rst_n),
    .inclk0       (sys_clk),
    .c0           (clk_100m),
    .c2           (clk_100m_lcd),
    .locked       (locked)
);
//I2C配置模块
i2c_ov5640_rgb565_cfg u_i2c_cfg(
    .clk                  (i2c_dri_clk),
    .rst_n                (rst_n),
    .i2c_done             (i2c_done),
    .i2c_exec             (i2c_exec),
    .i2c_data             (i2c_data),
    .i2c_rh_wl            (i2c_rh_wl),              //I2C读写控制信号
    .i2c_data_r           (i2c_data_r),
    .init_done            (cam_init_done),
    .cmos_h_pixel         (13'd480),           //CMOS水平方向像素个数
    .cmos_v_pixel         (13'd272),          //CMOS垂直方向像素个数
    .total_h_pixel        (13'd1800),          //水平总像素大小
    .total_v_pixel        (13'd1000)           //垂直总像素大小
);
//I2C驱动模块
i2c_dri
   #(
    .SLAVE_ADDR           (SLAVE_ADDR),             //参数传递
    .CLK_FREQ             (CLK_FREQ  ),
    .I2C_FREQ             (I2C_FREQ  )
    )
   u_i2c_dri(
    .clk                  (clk_100m_lcd),
    .rst_n                (rst_n     ),
    //i2c interface
    .i2c_exec             (i2c_exec  ),
    .bit_ctrl             (BIT_CTRL  ),
    .i2c_rh_wl            (i2c_rh_wl ),               //固定为0，只用到了IIC驱动的写操作
    .i2c_addr             (i2c_data[23:8]),
    .i2c_data_w           (i2c_data[7:0]),
    .i2c_data_r           (i2c_data_r),
    .i2c_done             (i2c_done  ),
    .scl                  (cam_scl   ),
    .sda                  (cam_sda   ),
    //user interface
    .dri_clk              (i2c_dri_clk)              //I2C操作时钟
);
//CMOS图像数据采集模块
/*cmos_capture_data u_cmos_capture_data(
    .rst_n                (rst_n & sys_init_done), //系统初始化完成之后再开始采集数据
    .cam_pclk             (cam_pclk),
    .cam_vsync            (cam_vsync),
    .cam_href             (cam_href),
    .cam_data             (cam_data),
    .cmos_frame_vsync     (cmos_frame_vsync),
    .cmos_frame_href      (cmos_frame_href),
    .cmos_frame_clken     (wr_en),
	 .frame_val_flag		  (frame_val_flag) ,//数据有效使能信号
	 .cnt_h				(cnt_h),			//x坐标
	 .cnt_v				(cnt_v),		//y坐标
    .cmos_data_t      		(cmos_data_t)           //有效数据
);*/
vip #(
    .NUM_ROW(NUM_ROW),
    .NUM_COL(NUM_COL),
    .H_PIXEL(H_PIXEL),
    .V_PIXEL(V_PIXEL)
)u_vip(
    //module clock
    .cam_pclk              (cam_pclk),  // 时钟信号
    .rst_n            (rst_n  ),  // 复位信号（低有效）
    //图像处理前的数据接口
    /*.pre_frame_vsync  (cmos_frame_vsync   ),
    .pre_frame_hsync  (cmos_frame_href   ),
	 .pre_frame_de     (1'b1  ),*/
    //.cmos_frame_data  (cmos_data_t),
    //.xpos             (cnt_h   ),
    //.ypos             (cnt_v   ),
	 //.frame_val_flag		(frame_val_flag),
    //图像处理后的数据接口
	 .cam_vsync            (cam_vsync),
    .cam_href             (cam_href),
    .cam_data             (cam_data),
    .post_frame_vsync (),  // 场同步信号
    .post_frame_hsync (),  // 行同步信号
    .post_frame_de    (),  // 数据输入使能
    .post_rgb         (),  // RGB565颜色数据
    //user interface
    .digit            (digit  )   // 识别到的数字
);

//例化数码管驱动模块
seg_bcd_dri u_seg_bcd_dri(
   //input
   .clk          (cam_pclk),       // 时钟信号
   .rst_n        (rst_n  ),       // 复位信号
   .num          (digit  ),       // 6个数码管要显示的数值
   .point        (6'b0   ),       // 小数点具体显示的位置,从高到低,高有效
   //output
   .sel          (sel    ),       // 数码管位选
   .seg_led      (seg_led),        // 数码管段选
   .signal      (signal)
);
endmodule
