//! monoio, `SPIKE_DRIVER=uring` (IoUringDriver, as ruxen) or `legacy`
//! (LegacyDriver: epoll via mio), or `fusion` (io_uring if it works, else
//! legacy).
use monoio::io::{AsyncReadRent, AsyncWriteRentExt};
use monoio::net::{TcpListener, TcpStream};
use runtime_spike::*;

fn main() {
    run_workers(worker);
}

fn worker(conf: Conf, i: usize) {
    match driver().as_str() {
        "uring" => monoio::RuntimeBuilder::<monoio::IoUringDriver>::new()
            .enable_timer()
            .with_entries(4096)
            .build()
            .unwrap()
            .block_on(serve(conf)),
        "legacy" => monoio::RuntimeBuilder::<monoio::LegacyDriver>::new()
            .enable_timer()
            .build()
            .unwrap()
            .block_on(serve(conf)),
        // What a server that just wants "io_uring if it works" builds:
        // monoio probes io_uring once and falls back to LegacyDriver.
        "fusion" => {
            let mut rt = monoio::RuntimeBuilder::<monoio::FusionDriver>::new()
                .enable_timer()
                .with_entries(4096)
                .build()
                .unwrap();
            if i == 0 {
                let picked = match rt {
                    monoio::FusionRuntime::Uring(_) => "io_uring",
                    monoio::FusionRuntime::Legacy(_) => "legacy (epoll)",
                };
                eprintln!("monoio FusionDriver picked {picked}");
            }
            rt.block_on(serve(conf))
        }
        d => panic!("unknown SPIKE_DRIVER {d}"),
    }
}

async fn serve(conf: Conf) {
    let listener = TcpListener::from_std(listener(conf.port)).unwrap();
    loop {
        let Ok((stream, _)) = listener.accept().await else {
            continue;
        };
        let _ = stream.set_nodelay(true);
        monoio::spawn(conn(stream, conf.keepalive));
    }
}

async fn conn(mut stream: TcpStream, keepalive: bool) {
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
        if count == 0 {
            continue;
        }
        let out = responses(count, keepalive);
        let res = match out {
            std::borrow::Cow::Borrowed(s) => stream.write_all(s).await.0,
            std::borrow::Cow::Owned(v) => stream.write_all(v).await.0,
        };
        if res.is_err() || !keepalive {
            return;
        }
    }
}
