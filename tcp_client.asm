; x86-64 Linux NASM TCP client (no dotted labels to avoid local-scope issues)
; - Non-blocking connect with 10s timeout (poll + SO_ERROR)
; - Sends "Hello from asm\n", shutdown(SHUT_WR)
; - Non-blocking recv (50ms x 200 = 10s)
; - Clear progress logs + errno print

BITS 64

%define SOL_SOCKET     1
%define SO_ERROR       4
%define SO_RCVTIMEO    20

%define AF_INET        2
%define SOCK_STREAM    1
%define IPPROTO_TCP    6
%define SHUT_WR        1

%define F_GETFL        3
%define F_SETFL        4
%define O_NONBLOCK     0x800

%define POLLOUT        0x0004
%define MSG_DONTWAIT   0x40

section .data
    ; 127.0.0.1:9000 -> port bytes must be 23 28 in memory; with little endian dw, use 0x2823
    sockaddr_in:
        dw AF_INET
        dw 0x2823               ; htons(9000)
        dd 0x0100007F           ; 127.0.0.1
        dq 0

    msg db "Will this work", 10
    msg_len equ $ - msg

    ; nanosleep timespec 50ms
    ts:
        dq 0
        dq 50_000_000

    ; logs
    l_connect     db "[*] connect...",10
    l_connect_len equ $-l_connect
    l_connect_ok  db "[+] connect OK",10
    l_connect_ok_len equ $-l_connect_ok
    l_send        db "[*] send...",10
    l_send_len    equ $-l_send
    l_shutdown    db "[*] shutdown(SHUT_WR)...",10
    l_shutdown_len equ $-l_shutdown
    l_wait        db "[*] waiting for reply (non-blocking, 10s)...",10
    l_wait_len    equ $-l_wait
    l_got         db "[+] got reply:",10
    l_got_len     equ $-l_got
    l_timeout     db "[!] timeout: no data after 10s",10
    l_timeout_len equ $-l_timeout

    ; errors
    err_prefix db "connect() failed, errno=",0
    err_prefix_len equ $-err_prefix
    err_send   db "send() failed",10
    err_send_len equ $-err_send

section .bss
    buf     resb 4096
    numbuf  resb 32

section .text
    global _start

; helper: write(rdi=fd, rsi=ptr, rdx=len)
print_write:
    mov rax, 1
    syscall
    ret

_start:
    ; socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
    mov rax, 41
    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    mov rdx, IPPROTO_TCP
    syscall
    mov r12, rax
    test rax, rax
    js  fatal_exit

    ; optional kernel recv timeout {10,0} (not relied upon)
    mov rax, 54
    mov rdi, r12
    mov rsi, SOL_SOCKET
    mov rdx, SO_RCVTIMEO
    sub rsp, 16
    mov qword [rsp], 10
    mov qword [rsp+8], 0
    mov r10, rsp
    mov r8, 16
    xor r9, r9
    syscall
    add rsp, 16

    ; progress
    mov rdi, 2
    lea rsi, [rel l_connect]
    mov rdx, l_connect_len
    call print_write

    ; ---------- non-blocking connect with timeout ----------

    ; fcntl(fd, F_GETFL)
    mov rax, 72
    mov rdi, r12
    mov rsi, F_GETFL
    xor rdx, rdx
    syscall
    ; set O_NONBLOCK
    or  rax, O_NONBLOCK
    mov rdx, rax
    mov rax, 72
    mov rdi, r12
    mov rsi, F_SETFL
    syscall

    ; connect(fd, &sockaddr_in, 16)
    mov rax, 42
    mov rdi, r12
    lea rsi, [rel sockaddr_in]
    mov rdx, 16
    syscall
    test rax, rax
    jns connect_ok_immediate

    ; rax < 0 => -errno
    neg rax
    cmp rax, 115               ; EINPROGRESS
    jne connect_failed_errno_rax

    ; poll for POLLOUT up to 10s
    sub rsp, 8                 ; pollfd {int fd; short events; short revents}
    mov dword [rsp], r12d
    mov word  [rsp+4], POLLOUT
    mov word  [rsp+6], 0

    mov rax, 7                 ; poll
    mov rdi, rsp
    mov rsi, 1
    mov rdx, 10000
    syscall
    cmp rax, 1
    jl  connect_poll_timeout

    ; getsockopt(SO_ERROR)
    sub rsp, 16
    xor rax, rax
    mov dword [rsp], eax
    mov dword [rsp+8], 4
    mov rax, 55
    mov rdi, r12
    mov rsi, SOL_SOCKET
    mov rdx, SO_ERROR
    lea r10, [rsp]
    lea r8,  [rsp+8]
    xor r9,  r9
    syscall
    mov eax, [rsp]
    add rsp, 16
    add rsp, 8
    test eax, eax
    jnz connect_failed_errno_eax
    jmp connect_ok

connect_ok_immediate:
    jmp connect_ok

connect_poll_timeout:
    add rsp, 8
    mov rax, 110               ; ETIMEDOUT
    jmp connect_failed_errno_rax

connect_failed_errno_eax:
    mov rax, rax
    ; fallthrough

connect_failed_errno_rax:
    ; stderr: "connect() failed, errno="
    mov rbx, rax
    mov rax, 1
    mov rdi, 2
    lea rsi, [rel err_prefix]
    mov rdx, err_prefix_len
    syscall

    ; print errno decimal + '\n'
    mov rax, rbx
    lea rdi, [rel numbuf+31]
    mov byte [rdi], 10
    mov r8, 10
    cmp rax, 0
    jne itoa_loop_nb
    dec rdi
    mov byte [rdi], '0'
    jmp itoa_done_nb
itoa_loop_nb:
    xor rdx, rdx
    div r8
    add dl, '0'
    dec rdi
    mov [rdi], dl
    test rax, rax
    jnz itoa_loop_nb
itoa_done_nb:
    mov rax, 1
    mov rdi, 2
    mov rsi, rdi
    lea rbx, [rel numbuf+32]
    mov rdx, rbx
    sub rdx, rsi
    syscall
    mov rax, 60
    mov rdi, 1
    syscall

connect_ok:
    ; clear O_NONBLOCK now that we’re connected
    mov rax, 72
    mov rdi, r12
    mov rsi, F_GETFL
    xor rdx, rdx
    syscall
    and rax, ~O_NONBLOCK
    mov rdx, rax
    mov rax, 72
    mov rdi, r12
    mov rsi, F_SETFL
    syscall

    ; announce
    mov rdi, 2
    lea rsi, [rel l_connect_ok]
    mov rdx, l_connect_ok_len
    call print_write

    ; send
    mov rdi, 2
    lea rsi, [rel l_send]
    mov rdx, l_send_len
    call print_write

    mov rax, 44                ; sendto(fd, msg, msg_len, 0, NULL, 0)
    mov rdi, r12
    lea rsi, [rel msg]
    mov rdx, msg_len
    xor r10, r10
    xor r8,  r8
    xor r9,  r9
    syscall
    test rax, rax
    js  send_failed

    ; shutdown write
    mov rdi, 2
    lea rsi, [rel l_shutdown]
    mov rdx, l_shutdown_len
    call print_write

    mov rax, 48
    mov rdi, r12
    mov rsi, SHUT_WR
    syscall

    ; non-blocking recv loop up to ~10s
    mov rdi, 2
    lea rsi, [rel l_wait]
    mov rdx, l_wait_len
    call print_write

    ; set O_NONBLOCK
    mov rax, 72
    mov rdi, r12
    mov rsi, F_GETFL
    xor rdx, rdx
    syscall
    or  rax, O_NONBLOCK
    mov rdx, rax
    mov rax, 72
    mov rdi, r12
    mov rsi, F_SETFL
    syscall

    mov rcx, 600               ; 600 * 50ms = ~10s
wait_loop:
    mov rax, 45                ; recvfrom(fd, buf, 4096, MSG_DONTWAIT, NULL, NULL)
    mov rdi, r12
    lea rsi, [rel buf]
    mov rdx, 4096
    mov r10, MSG_DONTWAIT
    xor r8,  r8
    xor r9,  r9
    syscall
    cmp rax, 0
    jg  got_data
    js  sleep_and_dec
    ; rax == 0 -> peer closed without data; wait a bit more
sleep_and_dec:
    mov rax, 35                ; nanosleep(&ts, NULL)
    lea rdi, [rel ts]
    xor rsi, rsi
    syscall
    loop wait_loop

    ; timeout
    mov rdi, 2
    lea rsi, [rel l_timeout]
    mov rdx, l_timeout_len
    call print_write
    jmp cleanup_exit1

got_data:
    ; header
    mov rdi, 1
    lea rsi, [rel l_got]
    mov rdx, l_got_len
    call print_write
    ; payload
    mov rdx, rax
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel buf]
    syscall
    jmp cleanup_exit0

send_failed:
    mov rax, 1
    mov rdi, 2
    lea rsi, [rel err_send]
    mov rdx, err_send_len
    syscall
    jmp cleanup_exit1

cleanup_exit0:
    mov rax, 3                 ; close(fd)
    mov rdi, r12
    syscall
    mov rax, 60                ; exit(0)
    xor rdi, rdi
    syscall

cleanup_exit1:
    mov rax, 3
    mov rdi, r12
    syscall
    mov rax, 60
    mov rdi, 1
    syscall

fatal_exit:
    mov rax, 60
    mov rdi, 1
    syscall
