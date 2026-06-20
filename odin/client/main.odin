package client

import "core:fmt"
import "core:net"

main:: proc() {
    socket, dial_err := net.dial_tcp(net.Endpoint{port = 1717, address = net.IP4_Loopback});
    
    if dial_err != nil {
        fmt.printf("Error on dialing TCP %s", dial_err);
        return
    }

    send_str_tcp(socket, "SET teste 123\n");
    send_str_tcp(socket, "GET teste\n");
    send_str_tcp(socket, "KEYS\r\n");
    send_str_tcp(socket, "EXISTS teste\r\n");
    send_str_tcp(socket, "EXISTS test\r\n");
    send_str_tcp(socket, "DEL teste\r\n");
    send_str_tcp(socket, "EXISTS teste\r\n");
    
    net.shutdown(socket, net.Shutdown_Manner.Both);
    net.close(socket);
}

send_str_tcp:: proc(socket:net.TCP_Socket, str:string) -> (bytes_written:int , err:net.TCP_Send_Error) {
    bytes_written, err = net.send_tcp(socket, transmute([]byte) str);
    if err != nil {
        fmt.printf("Error on sending %s", err);
    }

    return bytes_written, err
}