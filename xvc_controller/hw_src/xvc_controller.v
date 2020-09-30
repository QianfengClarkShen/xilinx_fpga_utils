`timescale 1ps / 1ps
module xvc_controller # (
	parameter XVC_PORT = 16'd2542
) (
//clk and rst
	input wire clk,
	input wire rst,
//axi stream interfaces
	//input
	input wire [511:0] s_axis_tdata,
	input wire [63:0] s_axis_tkeep,
	input wire s_axis_tlast,
	input wire s_axis_tvalid,
	input wire [31:0] remote_ip_rx,
	input wire [15:0] remote_port_rx,
	input wire [15:0] local_port_rx,
	//output
	output wire [511:0] m_axis_tdata,
	output wire [63:0] m_axis_tkeep,
	output wire m_axis_tlast,
	output wire m_axis_tvalid,
	output wire [31:0] remote_ip_tx,
	output wire [15:0] remote_port_tx,
	output wire [15:0] local_port_tx,
//axi-lite master
	output wire [15:0] m_axi_araddr,
	output wire [3:0] m_axi_arcache,
	output wire [2:0] m_axi_arprot,
	input wire m_axi_arready,
	output wire m_axi_arvalid,
	output wire [15:0] m_axi_awaddr,
	output wire [3:0] m_axi_awcache,
	output wire [2:0] m_axi_awprot,
	input wire m_axi_awready,
	output wire m_axi_awvalid,
	output wire m_axi_bready,
	input wire [1:0] m_axi_bresp,
	input wire m_axi_bvalid,
	input wire [31:0] m_axi_rdata,
	output wire m_axi_rready,
	input wire [1:0] m_axi_rresp,
	input wire m_axi_rvalid,
	output wire [31:0] m_axi_wdata,
	input wire m_axi_wready,
	output wire [3:0] m_axi_wstrb,
	output wire m_axi_wvalid
);

	reg [511:0] s_axis_tdata_reg;
	reg [63:0] s_axis_tkeep_reg;
	reg s_axis_tlast_reg;
	reg s_axis_tvalid_reg;
	reg [31:0] remote_ip_reg;
	reg [15:0] remote_port_reg;
	reg [15:0] local_port_reg;
	reg in_packet;

	wire [511:0] s_axis_tdata_int;
	wire [63:0] s_axis_tkeep_int;
	wire s_axis_tlast_int;
	wire s_axis_tvalid_int;
	wire s_axis_tready_int;

	wire [15:0] addr;
	wire [31:0] wdata;
	wire [31:0] rdata;
	wire [1:0] opcode;
	wire rvalid;
	wire wdone;
	wire busy;

	always @(posedge clk) begin
		if (rst) begin
			s_axis_tdata_reg <= 512'b0;
			s_axis_tkeep_reg <= 64'b0;
			s_axis_tlast_reg <= 1'b0;
			s_axis_tvalid_reg <= 1'b0;
			remote_ip_reg <= 32'b0;
			remote_port_reg <= 16'b0;
			local_port_reg <= 16'b0;
			in_packet <= 1'b0;
		end
		else begin
			s_axis_tdata_reg <= s_axis_tdata;
			s_axis_tkeep_reg <= s_axis_tkeep;
			s_axis_tlast_reg <= s_axis_tlast;
			s_axis_tvalid_reg <= s_axis_tvalid && (local_port_rx == XVC_PORT || (in_packet && local_port_reg == XVC_PORT));
			
			if (~in_packet && s_axis_tvalid && local_port_rx == XVC_PORT) begin
				remote_ip_reg <= remote_ip_rx;
				remote_port_reg <= remote_port_rx;
			end
			if (s_axis_tvalid & s_axis_tlast) begin
				in_packet <= 1'b0;
				local_port_reg <= 16'b0;
			end
			else if (s_axis_tvalid) begin
				in_packet <= 1'b1;
				local_port_reg <= local_port_rx;
			end
		end
	end

	zero_latency_axis_fifo # (
		.DATA_WIDTH(512),
		.FIFO_DEPTH(128),
		.HAS_DATA(1),
		.HAS_KEEP(1),
		.HAS_LAST(1)
	) rx_fifo (
		.clk(clk),
		.rst(rst),
		.s_axis_tdata(s_axis_tdata_reg),
		.s_axis_tkeep(s_axis_tkeep_reg),
		.s_axis_tlast(s_axis_tlast_reg),
		.s_axis_tvalid(s_axis_tvalid_reg),
		.m_axis_tdata(s_axis_tdata_int),
		.m_axis_tkeep(s_axis_tkeep_int),
		.m_axis_tlast(s_axis_tlast_int),
		.m_axis_tvalid(s_axis_tvalid_int),
		.m_axis_tready(s_axis_tready_int)
	);
	xvc_controller_core xvc_controller_core_inst (
		.clk(clk),
		.rst(rst),
		.addr(addr),
		.wdata(wdata),
		.opcode(opcode),
		.rdata(rdata),
		.rvalid(rvalid),
		.wdone(wdone),
		.busy(busy),
		.s_axis_tdata(s_axis_tdata_int),
		.s_axis_tkeep(s_axis_tkeep_int),
		.s_axis_tlast(s_axis_tlast_int),
		.s_axis_tvalid(s_axis_tvalid_int),
		.s_axis_tready(s_axis_tready_int),
		.m_axis_tdata(m_axis_tdata),
		.m_axis_tkeep(m_axis_tkeep),
		.m_axis_tlast(m_axis_tlast),
		.m_axis_tvalid(m_axis_tvalid)
	);
	easy_axilite_master # (
		.ADDR_LEN(16),
		.DATA_LEN(32)
	) easy_axilite_master_inst( 
//clk and rst
		.clk(clk),
		.rst(rst),
//user interface
		.addr(addr),
		.wdata(wdata),
		.opcode(opcode),
		.rdata(rdata),
		.rvalid(rvalid),
		.wdone(wdone),
		.rd_err(),
		.wr_err(),
		.busy(busy),
//axi-lite master
		.m_axi_araddr(m_axi_araddr),
		.m_axi_arcache(m_axi_arcache),
		.m_axi_arprot(m_axi_arprot),
		.m_axi_arready(m_axi_arready),
		.m_axi_arvalid(m_axi_arvalid),
		.m_axi_awaddr(m_axi_awaddr),
		.m_axi_awcache(m_axi_awcache),
		.m_axi_awprot(m_axi_awprot),
		.m_axi_awready(m_axi_awready),
		.m_axi_awvalid(m_axi_awvalid),
		.m_axi_bready(m_axi_bready),
		.m_axi_bresp(m_axi_bresp),
		.m_axi_bvalid(m_axi_bvalid),
		.m_axi_rdata(m_axi_rdata),
		.m_axi_rready(m_axi_rready),
		.m_axi_rresp(m_axi_rresp),
		.m_axi_rvalid(m_axi_rvalid),
		.m_axi_wdata(m_axi_wdata),
		.m_axi_wready(m_axi_wready),
		.m_axi_wstrb(m_axi_wstrb),
		.m_axi_wvalid(m_axi_wvalid)
	);
	assign remote_ip_tx = remote_ip_reg;
	assign remote_port_tx = remote_port_reg;
	assign local_port_tx = XVC_PORT;
endmodule
