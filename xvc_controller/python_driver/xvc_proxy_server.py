#!/usr/bin/python3
import sys
from config import *
from utils import *

#proxy server <--> xvc on GULF-Stream
udpsock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
udpsock.bind(udp_client_address)

#local vivado xvc client <--> proxy server
tcpsock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
tcpsock.bind(tcp_server_address)
tcpsock.listen(1)
tcp_connection, dummy = tcpsock.accept()

while True:
	data = tcp_connection.recv(MAX_PKT_SIZE_TCP)
	if data is None:
		break
	if len(data) == 8:
		if data == b"getinfo:":
			#got getinfo
			tcp_connection.send(b"xvcServer_v1.0:10000\n")
	elif data[0:7] == b"settck:":
		#got settck
		tcp_connection.send(data[7:11])
	elif data[0:6] == b"shift:":
		#got shift
		num_bits = (data[6] | (data[7]<<8) | (data[8]<<16) | (data[9]<<24))
		num_bytes = int((num_bits+7)/8)
		tms_index = 10
		tdi_index = 10+num_bytes
		tdo_index = 0
		tdo = bytearray(num_bytes)
		while num_bits > 0:
			#calcuate how many bytes to send for this iteration
			curr_bytes = int(min(num_bytes, MAX_TMS_TDI_SIZE_UDP))
			curr_bits = int(min(num_bits, MAX_TMS_TDI_SIZE_UDP*8))
			num_bits -= curr_bits
			num_bytes -= curr_bytes
			#send tms and tdi to the FPGA, get tdo back to the client, here we need to re-pack the data into a more efficient format for FPGA processing
			curr_words = int((curr_bytes+3)/4)
			pkt_len = 2*4*curr_words+64
			xvc_udp_packet = bytearray(pkt_len)
			xvc_udp_packet[0] = (curr_bits >> 24) & 0xff
			xvc_udp_packet[1] = (curr_bits >> 16) & 0xff
			xvc_udp_packet[2] = (curr_bits >> 8) & 0xff
			xvc_udp_packet[3] = curr_bits & 0xff
			xvc_udp_packet[4] = (curr_bytes >> 24) & 0xff
			xvc_udp_packet[5] = (curr_bytes >> 16) & 0xff
			xvc_udp_packet[6] = (curr_bytes >> 8) & 0xff
			xvc_udp_packet[7] = curr_bytes & 0xff
			for i in range(curr_words):
				for j in range(int(min(curr_bytes-i*4,4))):
					#convert endianess here
					xvc_udp_packet[64+2*i*4+3-j] = data[tms_index+i*4+j]
					xvc_udp_packet[64+2*i*4+7+j] = data[tdi_index+i*4+j]

			tms_index += curr_bytes
			tdi_index += curr_bytes

			udpsock.sendto(xvc_udp_packet, udp_server_address)
			tdo_partial, dummy = udpsock.recvfrom(MAX_PKT_SIZE_UDP)
			if len(tdo_partial) != curr_bytes:
				sys.exit('Error! Partial tdo size not corret!')
			for i in range(curr_bytes):
				tdo[tdo_index+i] = tdo_partial[i]
			tdo_index += curr_bytes
		tcp_connection.send(tdo)
	tcp_connection.close()
