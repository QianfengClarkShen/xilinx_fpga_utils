#!/usr/bin/python3
import sys
from config import *
from utils import *

#proxy server <--> xvc on GULF-Stream
udp_client_address = (get_ip_address(udp_interface), 0)
udp_server_address = (fpga_address, fpga_port)
udpsock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
udpsock.bind(udp_client_address)

#local vivado xvc client <--> proxy server
tcp_server_address = (get_ip_address(tcp_interface), tcp_port)
tcpsock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
tcpsock.bind(tcp_server_address)
tcpsock.listen(1)

tcp_connection, dummy = tcpsock.accept()
print("got xvc connection!")
while True:
	data = tcp_connection.recv(MAX_PKT_SIZE)
	if len(data) < 8:
		continue
	if data == b"getinfo:":
		#got getinfo
		tcp_connection.send(b"xvcServer_v1.0:1400\n")
	elif data[0:7] == b"settck:":
		#got settck
		tcp_connection.send(data[7:11])
	elif data[0:6] == b"shift:":
		#got shift
		num_bits = (data[6] | (data[7]<<8) | (data[8]<<16) | (data[9]<<24))
		num_bytes = int((num_bits+7)/8)
		tms_index = 10
		tdi_index = 10+num_bytes
		tdo = bytearray(num_bytes)

		num_words = int((num_bytes+3)/4)
		pkt_len = 2*4*num_words+64
		xvc_udp_packet = bytearray(pkt_len)
		for i in range(4):
			xvc_udp_packet[i] = num_bits.to_bytes(4, 'big')[i]
			xvc_udp_packet[i+4] = num_bytes.to_bytes(4, 'big')[i]
		for i in range(num_words):
			for j in range(int(min(num_bytes-i*4,4))):
				xvc_udp_packet[64+2*i*4+j] = data[tms_index+i*4+j]
				xvc_udp_packet[64+2*i*4+4+j] = data[tdi_index+i*4+j]
		udpsock.sendto(xvc_udp_packet, udp_server_address)
		tdo, dummy = udpsock.recvfrom(MAX_PKT_SIZE)
		if len(tdo) != num_bytes:
			tcp_connection.close()
			sys.exit('Error! tdo size not corret!')
		tcp_connection.send(tdo)

#code should never reach here
print("something wrong with the OS")
tcp_connection.close()
