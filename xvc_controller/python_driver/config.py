MAX_PKT_SIZE_UDP = 1400
MAX_PKT_SIZE_TCP = 10000+42 #according to Xilinx official xvc pci-e driver
MAX_TMS_TDI_SIZE_UDP = (MAX_PKT_SIZE_UDP - 64)/2

#proxy server <--> xvc on GULF-Stream
udp_client_address = ('10.1.2.106', 0)
udp_server_address = ('10.1.100.10', 2542)

#local vivado xvc client <--> proxy server
tcp_server_address = ('127.0.0.1', 2542)
