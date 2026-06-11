use std::{collections::HashMap, io, string};

#[derive(Debug)]
enum Request {
    Set(String, String),
    Get(String),
    Del(String),
    Exists(String),
    Keys,
    Quit,
    Undefined
}

#[derive(Debug)]
enum Response {
    Ok,
    Value(String),
    Error(String),
    Null,
    True,
    False,
}

fn main() {
    let mut database: HashMap<String,String> = HashMap::new();

    loop {
        println!("Make your request:");
        let mut input = string::String::new();

        let _ = io::stdin().read_line(&mut input);

        let req_op: Result<Request, String> = parse_request(input);

        if req_op.is_err() {
            println!("Error: {}", req_op.err().unwrap());
            println!("");
            continue;
        }

        let req = req_op.unwrap();

        print_request(&req);

        let res= execute_request(&req, &mut database);

        print_response(&res);

        if matches!(res, Response::Ok) && matches!(req, Request::Quit) {
            break;
        }

        println!("");
    };
}

fn print_response(res: &Response) {
    match res {
        Response::Value(value) => println!("VALUE {}", value),
        Response::Error(error) => println!("ERROR {}", error),
        Response::Ok => println!("OK"),
        Response::Null => println!("NULL"),
        Response::True => println!("TRUE"),
        Response::False => println!("FALSE"),
    }
}

fn execute_request(req: &Request, db:&mut HashMap<String, String>) -> Response {    
    match req {
        Request::Set(key, value) => {
            db.insert(key.to_owned(), value.to_owned());
            Response::Ok
        },
        Request::Get(key) => {
            match db.get(key) {
                Some(value) => Response::Value(value.to_owned()),
                None => Response::Null,
            }
        },
        Request::Del(key) => {
            if db.contains_key(key) {
                db.remove_entry(key);
                return Response::Ok;
            }

            Response::Error("Entry does not exists".to_owned())
        },
        Request::Exists(key) => match db.contains_key(key) {
            true => Response::True,
            false => Response::False,
        },
        Request::Keys =>  {
            let keys = db
                .iter()
                .map(|(key, _)| key.as_str())
                .collect::<Vec<&str>>()
                .join(", ");

            Response::Value(keys)
        },
        Request::Quit => Response::Ok,
        Request::Undefined => Response::Error("Undefined error".to_owned())
    }
}

fn print_request(req: &Request) {
    let fmt = match req {
        Request::Set(key, value) => format!("action: SET\n\tkey: {}\n\tvalue: {}", key, value),
        Request::Get(key) => format!("action: GET\n\tkey: {}", key),
        Request::Del(key) => format!("action: DEL\n\tkey: {}", key),
        Request::Exists(key) => format!("action: EXISTS\n\tkey: {}", key),
        Request::Keys => "action: KEYS".to_owned(),
        Request::Quit => "action: QUIT".to_owned(),
        Request::Undefined => "action: Unkown".to_owned()
    };

    println!("You request is ->\n\t{}", fmt);
}

fn parse_request(input: String) -> Result<Request, String> {
    let trimmed_input = input.trim();
    let mut input_phases = trimmed_input.split(" ");
    let input_action = input_phases
        .next();

    match input_action {
        None => Err("No action".to_owned()),
        Some(input) => {
            let action = input.to_uppercase();
            let key = input_phases.next();
            let value = input_phases.next();

            let req = match (action.as_str(), key, value) {
                ("SET", Some(key), Some(value)) => Request::Set(key.to_owned(), value.to_owned()),
                ("GET", Some(key), None) => Request::Get(key.to_owned()),
                ("DEL", Some(key), None) => Request::Del(key.to_owned()),
                ("EXISTS", Some(key), None) => Request::Exists(key.to_owned()),
                ("KEYS", None, None) => Request::Keys,
                ("QUIT", None, None) => Request::Quit,        
                _ => Request::Undefined
            };

            match req {
                Request::Undefined => return Err("Undefined or malformed action".to_owned()),
                _ => Ok(req),
            }
        },
    }
}
