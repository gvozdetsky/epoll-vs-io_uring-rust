//! tokio as most servers use it: one multi-thread (work-stealing) runtime
//! with `workers()` threads, one listener, `tokio::spawn` per connection.
//! epoll only.
use runtime_spike::*;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};

fn main() {
    install_signals();
    let conf = conf_from_args();
    tokio::runtime::Builder::new_multi_thread()
        .worker_threads(workers())
        .enable_io()
        .build()
        .unwrap()
        .block_on(serve(conf));
}

async fn serve(conf: Conf) {
    let listener = TcpListener::from_std(listener(conf.port)).unwrap();
    loop {
        let Ok((stream, _)) = listener.accept().await else {
            continue;
        };
        let _ = stream.set_nodelay(true);
        tokio::spawn(conn(stream, conf.keepalive));
    }
}

async fn conn(mut stream: TcpStream, keepalive: bool) {
    let mut reqs = Requests::default();
    let mut buf = vec![0u8; READ_BUF];
    loop {
        let n = match stream.read(&mut buf).await {
            Ok(0) | Err(_) => return,
            Ok(n) => n,
        };
        let count = reqs.feed(&buf[..n]);
        if count == 0 {
            continue;
        }
        if stream
            .write_all(&responses(count, keepalive))
            .await
            .is_err()
            || !keepalive
        {
            return;
        }
    }
}
