package server

import "core:fmt"
import "core:hash"
import "core:net"
import "core:strings"

Command_Type :: enum {
	Get,
	Set,
	Del,
	Exists,
	Keys,
}

Response_Type :: enum {
	Ok,
	Value,
	Null,
	Error,
}

Command :: struct {
	type:  Command_Type,
	key:   string,
	value: string,
}

Response :: struct {
	type: Response_Type,
	body: string,
}

Parse_Error :: enum i32 {
	RequireOneCommand,
	RequireOneParameter,
	RequireTwoParameters,
	NoParameters,
}

Command_Error :: enum i32 {
	Unknown,
	KeyDoesNotExist,
	FailedToResizeStore,
}

Store :: map[string]string

main :: proc() {
	socket, listen_error := net.listen_tcp(net.Endpoint{port = 1717, address = net.IP4_Loopback})

	if listen_error != nil {
		fmt.panicf("listen error: %s", listen_error)
	}

	store: Store = make(Store)
	defer delete(store)

	fmt.print("Listening for TCP connection... \n")
	client_socket, client_endpoint, accp_error := net.accept_tcp(socket)

	if accp_error != nil {
		fmt.panicf("%s", accp_error)
	}

	fmt.printf("Accepted tcp for client:%s \n", net.to_string(client_endpoint))

	handleTpcClient(client_socket, &store)
}

handleTpcClient :: proc(socket: net.TCP_Socket, store: ^Store) {
	pending: [dynamic]byte = make([dynamic]byte)
	defer delete(pending)
	for {
		data_in_bytes: [64]byte
		size_return, err := net.recv_tcp(socket, data_in_bytes[:])

		if size_return == 0 {
			break
		}

		if err != nil {
			fmt.panicf("error while recieving data %s", err)
		}

		for b in data_in_bytes {
			if b == '\r' {
				continue
			}
			else if b == '\n' {
				fmt.printf("\nREQ: %s\n", pending[:])
				cmd, err := parse_command(pending[:])
				if err != nil {
					fmt.printf("Error code: %s\n", err)
					fmt.printf("full command: %s\n", pending[:])
					return
				}

				res, cmd_err := execute_command(cmd, store)
				clear(&pending)

				if cmd_err != nil {
					fmt.printf("Error code: %s\n", cmd_err)
					fmt.printf("full command: %s\n", pending[:])
				}

				fmt.printf("RES type: %s body: %s\n", res.type, res.body)
			}
			else {
				append(&pending, b)
			}
		}
	}

	net.shutdown(socket, net.Shutdown_Manner.Both)
	net.close(socket)
}


parse_command :: proc(data: []byte) -> (cmd: Command, err: Parse_Error) {
	raw := string(data)
	inputs := strings.split(raw, " ")

	if len(inputs) == 0 {
		return {}, Parse_Error.RequireOneCommand
	}

	command := strings.to_upper(inputs[0])

	switch command {
	case "SET":
		if len(inputs) < 3 || len(inputs) > 3 {
			fmt.printf("size: %d %s\n", len(inputs), strings.join(inputs[:], ","))
			return {}, Parse_Error.RequireTwoParameters
		}

		return {
				type = Command_Type.Set,
				key = strings.clone(inputs[1]),
				value = strings.clone(inputs[2]),
			},
			nil
	case "GET":
		if len(inputs) < 2 || len(inputs) > 2 {
			return {}, Parse_Error.RequireOneParameter
		}

		return {type = Command_Type.Get, key = strings.clone(inputs[1])}, nil
	case "DEL":
		if len(inputs) < 2 || len(inputs) > 2 {
			return {}, Parse_Error.RequireOneParameter
		}

		return {type = Command_Type.Del, key = strings.clone(inputs[1])}, nil
	case "EXISTS":
		if len(inputs) < 2 || len(inputs) > 2 {
			return {}, Parse_Error.RequireOneParameter
		}

		return {type = Command_Type.Exists, key = strings.clone(inputs[1])}, nil
	case "KEYS":
		if len(inputs) < 1 || len(inputs) > 1 {
			return {}, Parse_Error.NoParameters
		}

		return {type = Command_Type.Keys}, nil
	}

	return {}, nil
}

execute_command :: proc(cmd: Command, store: ^Store) -> (res: Response, err: Command_Error) {
	switch cmd.type {
	case .Get:
		value, err := store[cmd.key]
		return {type = Response_Type.Value, body = value}, nil
	case .Set:
		prev_key, value_ptr, found_prev := map_upsert(store, cmd.key, cmd.key)
		if value_ptr == nil {
			return {type = Response_Type.Error}, Command_Error.FailedToResizeStore
		}
		return {type = Response_Type.Ok}, nil
	case .Del:
		value, ok := store[cmd.key]
		if !ok {
			return {type = Response_Type.Error}, Command_Error.KeyDoesNotExist
		}
		delete_key(store, cmd.key)
		return {type = Response_Type.Ok}, nil
	case .Exists:
		value, ok := store[cmd.key]
		if ok  && value != "" {
			return {type = Response_Type.Value, body = "True"}, nil
		} else {
			return {type = Response_Type.Value, body = "False"}, nil
		}
	case .Keys:
		keys := make([dynamic]string, len(store))
		defer delete(keys)
		for key, value in store {
			append(&keys, key)
		}
		res := strings.clone(strings.join(keys[:], "")); 
		return {type = Response_Type.Value, body = res}, nil
	}
	return {type = Response_Type.Error}, Command_Error.Unknown
}
