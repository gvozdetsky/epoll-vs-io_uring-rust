//! tokio, one current-thread runtime + LocalSet per worker (no work
//! stealing), a SO_REUSEPORT listener each. epoll only.
use runtime_spike::*;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};

fn main() {
    run_workers(worker);
}

fn worker(conf: Conf, _i: usize) {
    let rt = tokio::runtime::Builder::new_current_thread()
        .enable_io()
        .build()
        .unwrap();
    let local = tokio::task::LocalSet::new();
    local.block_on(&rt, serve(conf));
}

async fn serve(conf: Conf) {
    let listener = TcpListener::from_std(listener(conf.port)).unwrap();
    loop {
        let Ok((stream, _)) = listener.accept().await else {
            continue;
        };
        let _ = stream.set_nodelay(true);
        tokio::task::spawn_local(conn(stream, conf.keepalive));
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
