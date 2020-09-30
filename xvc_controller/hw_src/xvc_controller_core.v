`timescale 1ps / 1ps
module xvc_controller_core (
//clk and rst
	input wire clk,
	input wire rst,
//memory map interface
	output wire [15:0] addr,
	output wire [31:0] wdata,
	output wire [1:0] opcode,
	input wire [31:0] rdata,
	input wire rvalid,
	input wire wdone,
	input wire busy,
//axi stream interfaces
	//input
	input wire [511:0] s_axis_tdata,
	input wire [63:0] s_axis_tkeep,
	input wire s_axis_tlast,
	input wire s_axis_tvalid,
	output wire s_axis_tready,
	//output
	output wire [511:0] m_axis_tdata,
	output wire [63:0] m_axis_tkeep,
	output wire m_axis_tlast,
	output wire m_axis_tvalid
);

	localparam IDLE = 3'd0;
	localparam WR_LEN = 3'd1;
	localparam WR_TMS = 3'd2;
	localparam WR_TDI = 3'd3;
	localparam WR_CTRL = 3'd4;
	localparam RD_CTRL = 3'd5;
	localparam RD_TDO = 3'd6;
	localparam PKT_FILL = 3'd7;

	localparam WAIT = 2'd0;
	localparam WRITE = 2'd1;
	localparam READ = 2'd2;

	localparam LENGTH_REG_OFFSET = 5'd0;
	localparam TMS_REG_OFFSET = 5'd4;
	localparam TDI_REG_OFFSET = 5'd8;
	localparam TDO_REG_OFFSET = 5'd12;
	localparam CONTROL_REG_OFFSET = 5'd16;

	reg [2:0] state;
	reg [2:0] wr_cnt;
	reg [3:0] rd_cnt;
	reg [4:0] addr_reg;
	reg [31:0] wdata_reg;
	reg [1:0] opcode_reg;
	reg [511:0] m_axis_tdata_reg;
	reg [63:0] m_axis_tkeep_reg;
	reg m_axis_tlast_reg;
	reg m_axis_tvalid_reg;

	reg [15:0] num_bits;
	reg [15:0] num_bytes;

	reg [511:0] network_content;

	always @(posedge clk) begin
		if (rst) begin
			state <= IDLE;
			wr_cnt <= 3'd0;
			rd_cnt <= 4'd0;
			addr_reg <= 5'd0;
			wdata_reg <= 32'd0;
			opcode_reg <= 2'd0;
			num_bits <= 16'd0;
			num_bytes <= 16'd0;
			m_axis_tdata_reg <= 512'b0;
			m_axis_tlast_reg <= 1'b0;
			m_axis_tvalid_reg <= 1'b0;
		end
		else begin
			case (state)
				IDLE: begin
					wr_cnt <= 3'd0;
					rd_cnt <= 4'd0;
					m_axis_tdata_reg <= 512'b0;
					m_axis_tlast_reg <= 1'b0;
					m_axis_tvalid_reg <= 1'b0;
					if (s_axis_tvalid) begin
						num_bits <= s_axis_tdata[511-16:512-32];
						num_bytes <= s_axis_tdata[511-48:512-64];
						state <= WR_LEN;
					end
				end
				WR_LEN: begin
					m_axis_tvalid_reg <= 1'b0;
					addr_reg <= LENGTH_REG_OFFSET;
					if (num_bits > 16'd32)
						wdata_reg <= 32'd32;
					else
						wdata_reg <= {16'd0,num_bits};
					if (busy)
						opcode_reg <= WAIT;
					else if (~wdone)
						opcode_reg <= WRITE;
					if (wdone) begin
						state <= WR_TMS;
						if (wr_cnt == 3'd0)
							network_content <= s_axis_tdata;
						else
							network_content <= {network_content[511-64:0], 64'd0};
					end
				end
				WR_TMS: begin
					addr_reg <= TMS_REG_OFFSET;
					//convert endianess
					wdata_reg <= {network_content[511-24:512-32],network_content[511-16:512-24],network_content[511-8:512-16],network_content[511:512-8]};
					if (busy)
						opcode_reg <= WAIT;
					else if (~wdone)
						opcode_reg <= WRITE;
					if (wdone)
						state <= WR_TDI;
				end
				WR_TDI: begin
					addr_reg <= TDI_REG_OFFSET;
					//convert endianess
					wdata_reg <= {network_content[511-56:512-64],network_content[511-48:512-56],network_content[511-40:512-48],network_content[511-32:512-40]};
					if (busy)
						opcode_reg <= WAIT;
					else if (~wdone)
						opcode_reg <= WRITE;
					if (wdone)
						state <= WR_CTRL;
				end
				WR_CTRL: begin
					addr_reg <= CONTROL_REG_OFFSET;
					wdata_reg <= 32'd1;
					if (busy)
						opcode_reg <= WAIT;
					else if (~wdone)
						opcode_reg <= WRITE;
					if (wdone)
						state <= RD_CTRL;
				end
				RD_CTRL: begin
					if (busy)
						opcode_reg <= WAIT;
					else if (~rvalid)
						opcode_reg <= READ;
					if (rvalid && rdata == 32'd0)
						state <= RD_TDO;
				end
				RD_TDO: begin
					addr_reg <= TDO_REG_OFFSET;
					if (busy)
						opcode_reg <= WAIT;
					else if (~rvalid)
						opcode_reg <= READ;
					if (rvalid) begin
						wr_cnt <= wr_cnt + 1'b1;
						rd_cnt <= rd_cnt + 1'b1;
						//convert endianess
						m_axis_tdata_reg <= {m_axis_tdata_reg[511-32:0],rdata[7:0],rdata[15:8],rdata[23:16],rdata[31:24]};
						if (rd_cnt == 4'd0) m_axis_tlast_reg <= (num_bytes <= 16'd64) ? 1'b1 : 1'b0;
						m_axis_tvalid_reg <= rd_cnt == 4'd15 ? 1'b1 : 1'b0;

						if (num_bits <= 16'd32) begin
							num_bits <= 16'd0;
							num_bytes <= 16'd0;
							if (rd_cnt != 4'd15)
								state <= PKT_FILL;
							else
								state <= IDLE;
						end
						else begin
							num_bits <= num_bits - 16'd32;
							num_bytes <= num_bytes - 16'd4;
							state <= WR_LEN;
						end
					end
				end
				PKT_FILL: begin
					rd_cnt <= rd_cnt + 1'b1;
					m_axis_tdata_reg <= {m_axis_tdata_reg[511-32:0],32'd0};
					m_axis_tvalid_reg <= rd_cnt == 4'd15 ? 1'b1 : 1'b0;
					if (rd_cnt == 4'd15) state <= IDLE;
				end
			endcase
		end
	end

	genvar i;
	for (i = 0; i < 64; i = i + 1) begin
		always @(posedge clk) begin
			if (rst)
				m_axis_tkeep_reg[i] <= 1'b0;
			else if (state == RD_TDO && rvalid && rd_cnt == 4'd0)
				m_axis_tkeep_reg[i] <= (num_bytes >= (64-i)) ? 1'b1 : 1'b0;
		end
	end

	assign s_axis_tready = s_axis_tvalid && (state == IDLE || (state == WR_LEN && wdone && wr_cnt == 3'd0));
	assign m_axis_tdata = m_axis_tdata_reg;
	assign m_axis_tkeep = m_axis_tkeep_reg;
	assign m_axis_tlast = m_axis_tlast_reg;
	assign m_axis_tvalid = m_axis_tvalid_reg;
	assign addr = addr_reg;
	assign wdata = wdata_reg;
	assign opcode = opcode_reg;

endmodule
