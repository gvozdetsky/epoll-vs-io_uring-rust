//! Shared parts of the runtime spike servers: the command line pair.sh
//! passes (`-p PREFIX -c CONF`), the two settings read from the bench
//! config (`listen PORT`, `keepalive_timeout 0`), the listening socket and
//! the request scan. Each binary only differs in its runtime and I/O calls.

use std::net::{SocketAddr, TcpListener};

/// What the bench config asks for.
#[derive(Clone, Copy)]
pub struct Conf {
    pub port: u16,
    pub keepalive: bool,
}

pub const READ_BUF: usize = 4096;

/// Byte-for-byte the size of ruxen's `m1_hello` response.
pub const RESP_KEEPALIVE: &[u8] = b"HTTP/1.1 200 OK\r\nServer: ruxen/0.1.2\r\n\
Date: Mon, 12 Oct 2026 07:30:04 GMT\r\nContent-Type: text/plain\r\n\
Content-Length: 5\r\nConnection: keep-alive\r\n\r\nhello";
pub const RESP_CLOSE: &[u8] = b"HTTP/1.1 200 OK\r\nServer: ruxen/0.1.2\r\n\
Date: Mon, 12 Oct 2026 07:30:04 GMT\r\nContent-Type: text/plain\r\n\
Content-Length: 5\r\nConnection: close\r\n\r\nhello";

pub fn conf_from_args() -> Conf {
    let args: Vec<String> = std::env::args().collect();
    let path = args
        .iter()
        .position(|a| a == "-c")
        .and_then(|i| args.get(i + 1))
        .expect("usage: -c CONF");
    let text = std::fs::read_to_string(path).expect("read config");
    let mut port = None;
    let mut keepalive = true;
    for line in text.lines() {
        let line = line.trim();
        if let Some(rest) = line.strip_prefix("listen ") {
            let p = rest.split([' ', ';']).next().unwrap();
            let p = p.rsplit(':').next().unwrap();
            port = Some(p.parse().expect("listen port"));
        } else if line.starts_with("keepalive_timeout") && line.contains(" 0;") {
            keepalive = false;
        }
    }
    Conf {
        port: port.expect("no listen in config"),
        keepalive,
    }
}

pub fn workers() -> usize {
    std::env::var("RUXEN_WORKERS")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or_else(|| std::thread::available_parallelism().map_or(1, |n| n.get()))
}

/// The driver a binary should use: `SPIKE_DRIVER`, else the suffix of the
/// executable's name (`spike-compio-poll`), else `uring`. The name form is
/// for the bench laptop's queue, which passes no environment.
pub fn driver() -> String {
    if let Ok(d) = std::env::var("SPIKE_DRIVER") {
        return d;
    }
    let exe = std::env::args().next().unwrap_or_default();
    let name = exe.rsplit('/').next().unwrap_or("");
    for d in ["uring", "legacy", "poll"] {
        if name.ends_with(&format!("-{d}")) {
            return d.into();
        }
    }
    "uring".into()
}

/// A per-worker `SO_REUSEPORT` listener, as ruxen and the bench nginx
/// configs (`reuseport backlog=4096`) have.
pub fn listener(port: u16) -> TcpListener {
    use socket2::{Domain, Socket, Type};
    let addr: SocketAddr = ([0, 0, 0, 0], port).into();
    let s = Socket::new(Domain::IPV4, Type::STREAM, None).unwrap();
    s.set_reuse_address(true).unwrap();
    s.set_reuse_port(true).unwrap();
    s.set_nonblocking(true).unwrap();
    s.bind(&addr.into()).unwrap();
    s.listen(4096).unwrap();
    s.into()
}

/// SIGQUIT / SIGTERM end the process at once (pair.sh stops servers with
/// SIGQUIT and waits for the pid).
pub fn install_signals() {
    extern "C" fn quit(_: libc::c_int) {
        unsafe { libc::_exit(0) }
    }
    unsafe {
        let h = quit as extern "C" fn(libc::c_int) as libc::sighandler_t;
        libc::signal(libc::SIGQUIT, h);
        libc::signal(libc::SIGTERM, h);
        libc::signal(libc::SIGPIPE, libc::SIG_IGN);
    }
}

/// Requests read on one connection: whole ones are counted and dropped,
/// a partial one is kept for the next read.
#[derive(Default)]
pub struct Requests {
    pending: Vec<u8>,
}

impl Requests {
    /// Feeds newly read bytes; returns how many complete requests they end.
    pub fn feed(&mut self, data: &[u8]) -> usize {
        if self.pending.is_empty() {
            let (n, used) = scan(data);
            if used < data.len() {
                self.pending.extend_from_slice(&data[used..]);
            }
            n
        } else {
            self.pending.extend_from_slice(data);
            let (n, used) = scan(&self.pending);
            self.pending.drain(..used);
            n
        }
    }
}

fn scan(data: &[u8]) -> (usize, usize) {
    let mut n = 0;
    let mut used = 0;
    while let Some(end) = find_head_end(&data[used..]) {
        n += 1;
        used += end;
    }
    (n, used)
}

fn find_head_end(data: &[u8]) -> Option<usize> {
    data.windows(4)
        .position(|w| w == b"\r\n\r\n")
        .map(|p| p + 4)
}

/// The bytes to send for `n` requests (one prebuilt response in the
/// common case, no allocation).
pub fn responses(n: usize, keepalive: bool) -> std::borrow::Cow<'static, [u8]> {
    let one = if keepalive {
        RESP_KEEPALIVE
    } else {
        RESP_CLOSE
    };
    if n == 1 {
        one.into()
    } else {
        one.repeat(n).into()
    }
}

/// Starts `workers()` threads running `worker`, then parks the main thread.
pub fn run_workers(worker: fn(Conf, usize)) {
    install_signals();
    let conf = conf_from_args();
    let handles: Vec<_> = (0..workers())
        .map(|i| std::thread::spawn(move || worker(conf, i)))
        .collect();
    for h in handles {
        h.join().unwrap();
    }
}
