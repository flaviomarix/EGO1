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
    input                 sys_clk     ,  //ϵͳʱ��
    input                 sys_rst_n   ,  //ϵͳ��λ���͵�ƽ��Ч
    //����ͷ�ӿ�
    input                 cam_pclk    ,  //cmos ��������ʱ��
    input                 cam_vsync   ,  //cmos ��ͬ���ź�
    input                 cam_href    ,  //cmos ��ͬ���ź�
    input        [7:0]    cam_data    ,  //cmos ����
    output                cam_rst_n   ,  //cmos ��λ�źţ��͵�ƽ��Ч
    output                cam_pwdn    ,  //cmos ��Դ����ģʽѡ���ź�
    output                cam_scl     ,  //cmos SCCB_SCL��
    inout                 cam_sda     ,  //cmos SCCB_SDA��
	 //lcd�ӿ�
    //output                lcd_hs      ,  //LCD ��ͬ���ź�
    //output                lcd_vs      ,  //LCD ��ͬ���ź�
    //output                lcd_de      ,  //LCD ��������ʹ��
   // inout        [15:0]   lcd_rgb     ,  //LCD RGB565��ɫ����
   // output                lcd_bl      ,  //LCD ��������ź�
   // output                lcd_rst     ,  //LCD ��λ�ź�
    //output                lcd_pclk    ,  //LCD ����ʱ��
    //seg led
    output   [5:0]  sel               ,  //�����λѡ
    output   [7:0]  seg_led           ,              //����ܶ�ѡ
    output   [3:0]  signal
    );

//parameter define
parameter  SLAVE_ADDR = 7'h3c         ;  //OV5640��������ַ7'h3c
parameter  BIT_CTRL   = 1'b1          ;  //OV5640���ֽڵ�ַΪ16λ  0:8λ 1:16λ
parameter  CLK_FREQ   = 27'd100_000_000; //i2c_driģ�������ʱ��Ƶ��
parameter  I2C_FREQ   = 18'd250_000   ;  //I2C��SCLʱ��Ƶ��,������400KHz
parameter  NUM_ROW    = 1'd1          ;  //��ʶ���ͼ�������
parameter  NUM_COL    = 3'd4          ;  //��ʶ���ͼ�������
parameter  H_PIXEL    = 9'd480        ;  //ͼ���ˮƽ����
parameter  V_PIXEL    = 9'd272        ;  //ͼ��Ĵ�ֱ����
parameter  DEPBIT     = 4'd10         ;  //����λ��

//wire define
wire                  clk_100m        ;  //100mhzʱ��,SDRAM����ʱ��
wire                  clk_100m_lcd    ;  //100mhzʱ��
wire                  clk_lcd         ;  //�ṩ��IIC����ʱ�Ӻ�lcd����ʱ��
wire                  locked          ;
wire                  rst_n           ;

wire                  i2c_exec        ;  //I2C����ִ���ź�
wire   [23:0]         i2c_data        ;  //I2CҪ���õĵ�ַ������(��8λ��ַ,��8λ����)
wire                  cam_init_done   ;  //����ͷ��ʼ�����
wire                  i2c_done        ;  //I2C�Ĵ�����������ź�
wire                  i2c_dri_clk     ;  //I2C����ʱ��
wire   [ 7:0]         i2c_data_r      ;  //I2C����������
wire                  i2c_rh_wl       ;  //I2C��д�����ź�

wire                  wr_en           ;  //sdram_ctrlģ��дʹ��
wire   [15:0]         wr_data         ;  //sdram_ctrlģ��д����
wire                  rd_en           ;  //sdram_ctrlģ���ʹ��
wire   [15:0]         rd_data         ;  //sdram_ctrlģ�������

wire                  sys_init_done   ;  //ϵͳ��ʼ�����(sdram��ʼ��+����ͷ��ʼ��)
wire   [15:0]         rgb             ;
//wire   [15:0]         ID_lcd          ;  //LCD��ID
wire   [12:0]         cmos_h_pixel    ;  //CMOSˮƽ�������ظ���
wire   [12:0]         cmos_v_pixel    ;  //CMOS��ֱ�������ظ���
wire   [12:0]         total_h_pixel   ;  //ˮƽ�����ش�С
wire   [12:0]         total_v_pixel   ;  //��ֱ�����ش�С
wire   [23:0]         sdram_max_addr  ;  //sdram��д������ַ

wire   [23:0]         digit           ;  //ʶ�𵽵�����
//wire   [15:0]         color_rgb       ;
wire   [10:0]         xpos            ;  //���ص������
wire   [10:0]         ypos            ;  //���ص�������
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
//ϵͳ��ʼ����ɣ�SDRAM������ͷ����ʼ�����
//��������SDRAM��ʼ��������������д������
assign  sys_init_done = cam_init_done;
assign  cam_rst_n = 1'b1;
//��Դ����ģʽѡ�� 0������ģʽ 1����Դ����ģʽ
assign  cam_pwdn = 1'b0;
//assign  lcd_de = 1'b1;

//���໷
pll u_pll(
    .reset       (~sys_rst_n),
    .inclk0       (sys_clk),
    .c0           (clk_100m),
    .c2           (clk_100m_lcd),
    .locked       (locked)
);
//I2C����ģ��
i2c_ov5640_rgb565_cfg u_i2c_cfg(
    .clk                  (i2c_dri_clk),
    .rst_n                (rst_n),
    .i2c_done             (i2c_done),
    .i2c_exec             (i2c_exec),
    .i2c_data             (i2c_data),
    .i2c_rh_wl            (i2c_rh_wl),              //I2C��д�����ź�
    .i2c_data_r           (i2c_data_r),
    .init_done            (cam_init_done),
    .cmos_h_pixel         (13'd480),           //CMOSˮƽ�������ظ���
    .cmos_v_pixel         (13'd272),          //CMOS��ֱ�������ظ���
    .total_h_pixel        (13'd1800),          //ˮƽ�����ش�С
    .total_v_pixel        (13'd1000)           //��ֱ�����ش�С
);
//I2C����ģ��
i2c_dri
   #(
    .SLAVE_ADDR           (SLAVE_ADDR),             //��������
    .CLK_FREQ             (CLK_FREQ  ),
    .I2C_FREQ             (I2C_FREQ  )
    )
   u_i2c_dri(
    .clk                  (clk_100m_lcd),
    .rst_n                (rst_n     ),
    //i2c interface
    .i2c_exec             (i2c_exec  ),
    .bit_ctrl             (BIT_CTRL  ),
    .i2c_rh_wl            (i2c_rh_wl ),               //�̶�Ϊ0��ֻ�õ���IIC������д����
    .i2c_addr             (i2c_data[23:8]),
    .i2c_data_w           (i2c_data[7:0]),
    .i2c_data_r           (i2c_data_r),
    .i2c_done             (i2c_done  ),
    .scl                  (cam_scl   ),
    .sda                  (cam_sda   ),
    //user interface
    .dri_clk              (i2c_dri_clk)              //I2C����ʱ��
);
//CMOSͼ�����ݲɼ�ģ��
/*cmos_capture_data u_cmos_capture_data(
    .rst_n                (rst_n & sys_init_done), //ϵͳ��ʼ�����֮���ٿ�ʼ�ɼ�����
    .cam_pclk             (cam_pclk),
    .cam_vsync            (cam_vsync),
    .cam_href             (cam_href),
    .cam_data             (cam_data),
    .cmos_frame_vsync     (cmos_frame_vsync),
    .cmos_frame_href      (cmos_frame_href),
    .cmos_frame_clken     (wr_en),
	 .frame_val_flag		  (frame_val_flag) ,//������Чʹ���ź�
	 .cnt_h				(cnt_h),			//x����
	 .cnt_v				(cnt_v),		//y����
    .cmos_data_t      		(cmos_data_t)           //��Ч����
);*/
vip #(
    .NUM_ROW(NUM_ROW),
    .NUM_COL(NUM_COL),
    .H_PIXEL(H_PIXEL),
    .V_PIXEL(V_PIXEL)
)u_vip(
    //module clock
    .cam_pclk              (cam_pclk),  // ʱ���ź�
    .rst_n            (rst_n  ),  // ��λ�źţ�����Ч��
    //ͼ����ǰ�����ݽӿ�
    /*.pre_frame_vsync  (cmos_frame_vsync   ),
    .pre_frame_hsync  (cmos_frame_href   ),
	 .pre_frame_de     (1'b1  ),*/
    //.cmos_frame_data  (cmos_data_t),
    //.xpos             (cnt_h   ),
    //.ypos             (cnt_v   ),
	 //.frame_val_flag		(frame_val_flag),
    //ͼ���������ݽӿ�
	 .cam_vsync            (cam_vsync),
    .cam_href             (cam_href),
    .cam_data             (cam_data),
    .post_frame_vsync (),  // ��ͬ���ź�
    .post_frame_hsync (),  // ��ͬ���ź�
    .post_frame_de    (),  // ��������ʹ��
    .post_rgb         (),  // RGB565��ɫ����
    //user interface
    .digit            (digit  )   // ʶ�𵽵�����
);

//�������������ģ��
seg_bcd_dri u_seg_bcd_dri(
   //input
   .clk          (cam_pclk),       // ʱ���ź�
   .rst_n        (rst_n  ),       // ��λ�ź�
   .num          (digit  ),       // 6�������Ҫ��ʾ����ֵ
   .point        (6'b0   ),       // С���������ʾ��λ��,�Ӹߵ���,����Ч
   //output
   .sel          (sel    ),       // �����λѡ
   .seg_led      (seg_led),        // ����ܶ�ѡ
   .signal      (signal)
);
endmodule
