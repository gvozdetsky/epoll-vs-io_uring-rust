//! tokio-uring: one tokio-uring runtime (a current-thread tokio runtime
//! with an io_uring driver) per worker, a SO_REUSEPORT listener each.
use runtime_spike::*;
use tokio_uring::net::{TcpListener, TcpStream};

fn main() {
    run_workers(worker);
}

fn worker(conf: Conf, _i: usize) {
    tokio_uring::builder().entries(4096).start(serve(conf));
}

async fn serve(conf: Conf) {
    let listener = TcpListener::from_std(listener(conf.port));
    loop {
        let Ok((stream, _)) = listener.accept().await else {
            continue;
        };
        let _ = stream.set_nodelay(true);
        tokio_uring::spawn(conn(stream, conf.keepalive));
    }
}

async fn conn(stream: TcpStream, keepalive: bool) {
    let mut reqs = Requests::default();
    let mut buf = Vec::with_capacity(READ_BUF);
    loop {
        let (res, b) = stream.read(buf).await;
        buf = b;
        let n = match res {
            Ok(0) | Err(_) => return,
            Ok(n) => n,
        };
        let count = reqs.feed(&buf[..n]);
        buf.clear();
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
