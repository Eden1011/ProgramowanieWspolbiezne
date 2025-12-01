import socket
import time

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
server_address = ("127.0.0.1", 5555)

print("Sending test message...")
sock.sendto(b"R", server_address)
print("Sent R")

time.sleep(1)
print("Waiting for response...")
sock.settimeout(5)
try:
    data, addr = sock.recvfrom(1024)
    print(f"Got response: {data}")
except socket.timeout:
    print("No response received")

sock.close()
