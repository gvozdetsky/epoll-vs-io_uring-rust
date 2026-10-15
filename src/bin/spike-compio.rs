//! compio, `SPIKE_DRIVER=uring` or `poll` (the fusion driver forced to
//! one side).
use compio::driver::{DriverType, ProactorBuilder};
use compio::io::{AsyncRead, AsyncWriteExt};
use compio::net::{TcpListener, TcpStream};
use runtime_spike::*;

fn main() {
    run_workers(worker);
}

fn worker(conf: Conf, _i: usize) {
    let mut proactor = ProactorBuilder::new();
    proactor.capacity(4096);
    proactor.driver_type(match driver().as_str() {
        "uring" => DriverType::IoUring,
        "poll" => DriverType::Poll,
        d => panic!("unknown SPIKE_DRIVER {d}"),
    });
    let rt = compio::runtime::RuntimeBuilder::new()
        .with_proactor(proactor)
        .build()
        .unwrap();
    rt.block_on(serve(conf));
}

async fn serve(conf: Conf) {
    let listener = TcpListener::from_std(listener(conf.port)).unwrap();
    loop {
        let Ok((stream, _)) = listener.accept().await else {
            continue;
        };
        let _ = stream.set_nodelay(true);
        compio::runtime::spawn(conn(stream, conf.keepalive)).detach();
    }
}

async fn conn(mut stream: TcpStream, keepalive: bool) {
    let mut reqs = Requests::default();
    let mut buf = Vec::with_capacity(READ_BUF);
    loop {
        let compio::BufResult(res, b) = stream.read(buf).await;
        buf = b;
        let n = match res {
            Ok(0) | Err(_) => return,
            Ok(n) => n,
        };
        let count = reqs.feed(&buf[..n]);
        if count == 0 {
            continue;
        }
        let res = match responses(count, keepalive) {
            std::borrow::Cow::Borrowed(s) => stream.write_all(s).await.0,
            std::borrow::Cow::Owned(v) => stream.write_all(v).await.0,
        };
        if res.is_err() || !keepalive {
            return;
        }
    }
}
