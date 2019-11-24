`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/20 10:21:08
// Design Name: 
// Module Name: myram
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


module myram #(
    parameter WIDTH = 1  ,               // 数据的位宽(位数)
    parameter DEPTH = 800,               // 数据的深度(个数)
    parameter DEPBIT= 10                 // 地址的位宽
)(
    //module clock
    input                     clk  ,     // 时钟信号

    //ram interface
    input                     we   ,
    input  [DEPBIT- 1'b1:0]   waddr,
    input  [DEPBIT- 1'b1:0]   raddr,
    input  [WIDTH - 1'b1:0]   dq_i ,
    output [WIDTH - 1'b1:0]   dq_o

    //user interface
);

//reg define
reg [WIDTH - 1'b1:0] mem [DEPTH - 1'b1:0];

//*****************************************************
//**                    main code
//*****************************************************

assign dq_o = mem[raddr];

always @ (posedge clk) begin
    if(we)
        mem[waddr-1] <= dq_i;
end

endmodule
