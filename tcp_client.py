# tcp_server.py
import socket

HOST, PORT = "127.0.0.1", 9000
REPLY = b"ACK: got your message\n"

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as srv:
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((HOST, PORT))
    srv.listen(8)
    print(f"[+] Listening on {HOST}:{PORT}")
    while True:
        conn, addr = srv.accept()
        with conn:
            data = conn.recv(4096)     # read once, whatever arrived
            print(f"[>] {len(data)} bytes from {addr}: {data!r}")
            conn.sendall(REPLY)        # <-- immediate reply
            print(f"[<] replied: {REPLY!r}")
