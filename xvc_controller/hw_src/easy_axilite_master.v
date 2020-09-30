`timescale 1ns / 1ps
module easy_axilite_master # (
	parameter ADDR_LEN = 8,
	parameter DATA_LEN = 32
)
(
//clk and rst
    input wire clk,
    input wire rst,
//user interface
	input wire [ADDR_LEN-1:0] addr,
	input wire [DATA_LEN-1:0] wdata,
	input wire [1:0] opcode,
	output wire [DATA_LEN-1:0] rdata,
	output wire rvalid,
	output wire wdone,
	output wire rd_err,
	output wire wr_err,
	output wire busy,
//axi-lite master
	output wire [ADDR_LEN-1:0] m_axi_araddr,
	output wire [3:0] m_axi_arcache,
	output wire [2:0] m_axi_arprot,
	input wire m_axi_arready,
	output wire m_axi_arvalid,
	output wire [ADDR_LEN-1:0] m_axi_awaddr,
	output wire [3:0] m_axi_awcache,
	output wire [2:0] m_axi_awprot,
	input wire m_axi_awready,
	output wire m_axi_awvalid,
	output wire m_axi_bready,
	input wire [1:0] m_axi_bresp,
	input wire m_axi_bvalid,
	input wire [DATA_LEN-1:0] m_axi_rdata,
	output wire m_axi_rready,
	input wire [1:0] m_axi_rresp,
	input wire m_axi_rvalid,
	output wire [DATA_LEN-1:0] m_axi_wdata,
	input wire m_axi_wready,
	output wire [3:0] m_axi_wstrb,
	output wire m_axi_wvalid
);
	reg [1:0] state;

	reg [ADDR_LEN-1:0] m_axi_awaddr_reg;
	reg [DATA_LEN-1:0] m_axi_wdata_reg;
	reg wait_aw_rdy;
	reg wait_w_rdy;
	reg wdone_reg;
	reg wr_err_reg;

	reg [ADDR_LEN-1:0] m_axi_araddr_reg;
	reg wait_ar_rdy;
	reg [DATA_LEN-1:0] rdata_reg;
	reg rvalid_reg;
	reg rd_err_reg;

	localparam IDLE = 2'd0;
	localparam WAIT_WRITE = 2'd1;
	localparam WAIT_READ = 2'd2;
	localparam WRITE = 2'd1;
	localparam READ = 2'd2;
    always @(posedge clk) begin
		if (rst) begin
			state <= IDLE;
			wdone_reg <= 1'b0;
			wr_err_reg <= 1'b0;
			rvalid_reg <= 1'b0;
			rd_err_reg <= 1'b0;
			m_axi_awaddr_reg <= {{ADDR_LEN}{1'b0}};
			m_axi_wdata_reg <= {{DATA_LEN}{1'b0}};
			wait_aw_rdy <= 1'b0;
			wait_w_rdy <= 1'b0;
			m_axi_araddr_reg <= {{ADDR_LEN}{1'b0}};
			wait_ar_rdy <= 1'b0;
		end
		else begin
			case (state)
				IDLE: begin
					//wr
					wdone_reg <= 1'b0;
					wr_err_reg <= 1'b0;
					//rd
					rvalid_reg <= 1'b0;
					rd_err_reg <= 1'b0;
					if (opcode == WRITE) begin
						m_axi_awaddr_reg <= addr;
						m_axi_wdata_reg <= wdata;
						wait_aw_rdy <= 1'b1;
						wait_w_rdy <= 1'b1;
						state <= WAIT_WRITE;
					end
					else if (opcode == READ) begin
						m_axi_araddr_reg <= addr;
						wait_ar_rdy <= 1'b1;
						state <= WAIT_READ;
					end
				end
				WAIT_WRITE : begin
					if (m_axi_awready) wait_aw_rdy <= 1'b0;
					if (m_axi_wready) wait_w_rdy <= 1'b0;
					if (m_axi_bvalid) begin
						wdone_reg <= 1'b1;
						wr_err_reg <= m_axi_bresp == 2'b00 ? 1'b0 : 1'b1;
						state <= IDLE;
					end
				end
				WAIT_READ : begin
					if (m_axi_arready) wait_ar_rdy <= 1'b0;
					if (m_axi_rvalid) begin
						rvalid_reg <= 1'b1;
						rd_err_reg <= m_axi_rresp == 2'b00 ? 1'b0 : 1'b1;
						rdata_reg <= m_axi_rdata;
						state <= IDLE;
					end
				end
			endcase
		end
	end
//user ports
    assign rdata = rdata_reg;
    assign rvalid = rvalid_reg;
    assign wdone = wdone_reg;
    assign rd_err = rd_err_reg;
    assign wr_err = wr_err_reg;
    assign busy = state != IDLE ? 1'b1 : 1'b0;

//axi-lite master
	//write channel
	assign m_axi_awaddr = m_axi_awaddr_reg;
	assign m_axi_awvalid = wait_aw_rdy;
	assign m_axi_wdata = m_axi_wdata_reg;
	assign m_axi_wvalid = wait_w_rdy;
	//read channel
    assign m_axi_araddr = m_axi_araddr_reg;
    assign m_axi_arvalid = wait_ar_rdy;

	//constants
	assign m_axi_arcache = 4'b0011;
	assign m_axi_arprot = 3'b000;
	assign m_axi_awcache = 4'b0011;
	assign m_axi_awprot = 3'b000;
	assign m_axi_wstrb = 4'b1111;
	assign m_axi_bready = 1'b1;
	assign m_axi_rready = 1'b1;
endmodule
