format ELF64 executable

SYS_read equ 0
SYS_write equ 1
SYS_open equ 2
SYS_close equ 3
SYS_SOCKET equ 41
SYS_accept equ 43
SYS_bind equ 49
SYS_listen equ 50
SYS_exit equ 60

SEEK_SET equ 0
SEEK_END equ 2

MAX_CONN equ 5

AF_INET equ 2
SOCK_STREAM equ 1
INADDR_ANY equ 0

STDOUT equ 1
STDERR equ 2

EXIT_SUCCESS equ 0
EXIT_FAILURE equ 1

macro syscall1 number, a
{
    mov rax, number
    mov rdi, a
    syscall
}

macro syscall2 number, a, b
{
    mov rax, number
    mov rdi, a
    mov rsi, b
    syscall
}

macro syscall3 number, a, b, c
{
    mov rax, number
    mov rdi, a
    mov rsi, b
    mov rdx, c
    syscall
}

macro write fd, buf, count
{
    mov rax, SYS_write
    mov rdi, fd
    mov rsi, buf
    mov rdx, count
    syscall
}

;int socket(int domain, int type, int protocol);
macro socket domain, type, protocol
{
    mov rax, SYS_SOCKET
    mov rdi, domain
    mov rsi, type
    mov rdx, protocol
    syscall
}

macro bind sockfd, addr, addrlen
{   
    syscall3 SYS_bind, sockfd, addr, addrlen
}

macro listen sockfd, backlog
{
    syscall2 SYS_listen, sockfd, backlog
}

macro accept sockfd, addr, addrlen
{
    syscall3 SYS_accept, sockfd, addr, addrlen
}

macro close fd
{
    syscall1 SYS_close, fd
}

macro exit code
{
    mov rax, SYS_exit
    mov rdi, code
    syscall
}

macro open pathname
{
    syscall3 SYS_open, pathname, 0, 0 ; 0 for read only (O_RDONLY)
}

macro lseek fd, offset, whence
{
    syscall3 8, fd, offset, whence
}

macro read fd, buf, size
{
    syscall3 SYS_read, fd, buf, size
}

segment readable executable
entry main
main:
    ;; Startup
    write STDOUT, msg, msg_len

    ;; Reading a file
    ;; Open
    write STDOUT, file_open_msg, file_open_msg_len
    open main_html
    cmp rax, 0
    jl error
    mov qword [htmlfd], rax

    ;; Find the len of the html page
    lseek [htmlfd], 0, SEEK_END
    cmp rax, 0
    jl error
    
    mov [html_file_len], rax

    lseek [htmlfd], 0, SEEK_SET
    cmp rax, 0
    jl error

    ;; Set up stack
    push rbp
    mov rbp, rsp

    sub rsp, [html_file_len]
    
    read [htmlfd], rsp, [html_file_len]

    cmp rax, -9 ;; Bad file descriptor
    je debug_error
    cmp rax, 0
    jl error

    write STDOUT, rsp, [html_file_len]

    ;; BREAK POINT
    mov eax, 1
    cmp eax, 1
    je break_point

    write STDOUT, socket_trace_msg, socket_trace_msg_len
    socket AF_INET, SOCK_STREAM, 0
    cmp rax, 0
    jl error
    mov qword [sockfd], rax


    write STDOUT, bind_trace_msg, bind_trace_msg_len
    mov word [servaddr.sin_family], AF_INET
    mov word [servaddr.sin_port], 16415 ;14619 ;37151 ;36895 ;14619
    mov dword [servaddr.sin_addr], INADDR_ANY
    
    bind [sockfd], servaddr.sin_family, sizeof_servaddr
    cmp rax, 0
    jl error

next_request:
    ;; Listen connections
    write STDOUT, list_trace_msg, list_trace_msg_len
    listen [sockfd], MAX_CONN
    cmp rax, 0
    jl error

    ;; Accept connections
    write STDOUT, accept_trace_msg, accept_trace_msg_len
    accept [sockfd], cliaddr.sin_family, cliaddr_len 
    cmp rax, 0
    jl error

    mov qword [connfd], rax
    
    ;; Send a message
    write STDOUT, message_trace_msg, message_trace_msg_len
    write [connfd], response, response_len
    cmp rax, 0
    jl error

    close [connfd]
    jmp next_request

    write STDOUT, ok_msg, ok_msg_len
    
    close [sockfd]
    exit EXIT_SUCCESS


error:
    write STDERR, error_msg, error_msg_len
    
    close [htmlfd]
    close [connfd]      ;; Maybe not safe 
    close [sockfd]      ;; Maybe not safe 
    exit EXIT_FAILURE

debug_error:
    write STDERR, depug_msg, depug_msg_len

    close [htmlfd]
    close [connfd]      ;; Maybe not safe 
    close [sockfd]      ;; Maybe not safe 
    exit EXIT_FAILURE

break_point:
    write STDERR, brake_msg, brake_msg_len

    close [htmlfd]
    close [connfd]      ;; Maybe not safe 
    close [sockfd]      ;; Maybe not safe 
    exit EXIT_FAILURE

;; db - 1 byte 
;; dw - 2 byte 
;; dd - 4 byte 
;; dq - 8 byte 

segment readable writeable

;; struct sockaddr_in {
;;     sa_family_t    sin_family; // 16 bits
;;     in_port_t      sin_port;   // 16 bits
;;     struct in_addr sin_addr;   // 32 bits
;;     uint8_t sin_zero[8];       // 64 bits
;; }

struc servaddr_in
{
    .sin_family dw 0
    .sin_port   dw 0
    .sin_addr   dd 0
    .sin_zero   dq 0
}

htmlfd dq -1
sockfd dq -1
connfd dq -1

servaddr servaddr_in
sizeof_servaddr = $ - servaddr.sin_family

cliaddr servaddr_in
cliaddr_len dd sizeof_servaddr

html_file_len dq -1

response db "HTTP/1.1 200 OK", 13, 10
         db "Content-Type: text/html; charset=utf-8", 13, 10
         db "Connection: close", 13, 10, 13, 10
         db "<h1>Hello from flat assembler!</h1>", 10

response_len = $ - response

msg db "INFO: Starting Web Server!", 10
msg_len = $ - msg
ok_msg db "INFO: Ok!", 10
ok_msg_len = $ - ok_msg
socket_trace_msg db "INFO: Creating a socket...", 10
socket_trace_msg_len = $ - socket_trace_msg
list_trace_msg db "INFO: Staring to listen", 10
list_trace_msg_len  = $ - list_trace_msg
bind_trace_msg db "INFO: Binding socket...", 10 
bind_trace_msg_len = $ - bind_trace_msg
accept_trace_msg db "INFO: Accepting client connections", 10
accept_trace_msg_len = $ - accept_trace_msg
message_trace_msg db "INFO: Sending a message to client", 10
message_trace_msg_len = $ - message_trace_msg
error_msg db "ERROR: Something went wrong", 10
error_msg_len = $ - error_msg
file_open_msg db "INFO:  Opening  a file", 10
file_open_msg_len = $ - file_open_msg
main_html db "./main.html", 0
main_html_len = $ - main_html
depug_msg db "DEBUG: Problem", 10
depug_msg_len = $ - depug_msg
brake_msg db "BRAKE: STOP!", 10
brake_msg_len = $ - brake_msg

;; DEBUG VALUES 
debug_file_size = 319
