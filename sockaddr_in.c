struct sockaddr_in addr;

addr.sin_family = AF_INET;           // Always AF_INET for IPv4
addr.sin_port = htons(9000);         // Convert 9000 to network byte order
addr.sin_addr.s_addr = inet_addr("127.0.0.1"); // IPv4 loopback address
memset(addr.sin_zero, 0, sizeof(addr.sin_zero)); // zero padding
