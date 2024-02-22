use log::{info, warn, error};
use tokio::{
    sync::{Mutex, OnceCell, RwLock},
    time::Duration,
    runtime::Runtime,
};
use std::{
    cell::Cell,
    ffi::{CStr, CString, c_char},
};

static mut IS_API_KEY_VALID: bool = false;
static mut IS_VIDEO_ID_VALID: bool = false;
static mut CHAT_ID: Cell<String> = Cell::new(String::new());
static mut IS_POLL_RUNNING: bool = false;
static mut POLL_RESULT: RwLock<[u16; 4]> = RwLock::const_new([0, 0, 0, 0]);
static mut IS_BUSY: bool = false;
static mut LAST_VALID_VIDEO_ID: Cell<String> = Cell::new(String::new());
static mut TOKIO_RT: OnceCell<Runtime> = OnceCell::const_new();
static mut UNIQUE_USERS: Mutex<Vec<String>> = Mutex::const_new(vec![]);

#[no_mangle]
pub unsafe extern fn Init(version_ptr: *const c_char) {
    simple_logging::log_to_stderr(log::LevelFilter::Info);
    let mut version = "...";
    if version_ptr.is_null() {
        warn!("Caught null pointer string (version_ptr)");
    } else {
        let version_cstr = CStr::from_ptr(version_ptr);
        if version_cstr.is_empty() {
            warn!("Caught empty string (version_ptr)");
        } else {
            version = version_cstr.to_str().unwrap();
        }
    }
    if let None = TOKIO_RT.get() {
        TOKIO_RT.set(Runtime::new().unwrap()).unwrap();
    }
    info!("yt_wrapper ({}) initialized", version);
}


#[no_mangle]
pub unsafe extern fn SendApiKeyCheck(raw_key: *const c_char) {
    if raw_key.is_null() {
        error!("Caught null pointer API key string");
        return
    }
    let key_cstr = CStr::from_ptr(raw_key);
    if key_cstr.is_empty() {
        error!("Caught empty API key string");
        return
    }
    let addr = format!(
        "https://www.googleapis.com/youtube/v3/search?part=snippet&q=YouTube+Data+API&type=video&key={}",
        key_cstr.to_string_lossy()
    );
    info!("Validating API key...");
    info!("{}", addr);

    TOKIO_RT.get().unwrap().spawn(async move {
        IS_BUSY = true;
        match minreq::get(addr).send() {
            Ok(resp) => {
                IS_API_KEY_VALID = resp.status_code == 200;
            },
            Err(err) => {
                error!("Looks like API key is invalid");
                error!("{}", err.to_string());
                IS_API_KEY_VALID = false;
            }
        };
        IS_BUSY = false;
    });
}

#[no_mangle]
pub unsafe extern fn SendVideoIdCheck(raw_key: *const c_char, raw_id: *const c_char) {
    if raw_key.is_null() || raw_id.is_null() {
        error!("Caught null pointer string (API key or video_id)");
        ClearChatId();
        return
    }
    let key_cstr = CStr::from_ptr(raw_key);
    let id_cstr = CStr::from_ptr(raw_id);
    if key_cstr.is_empty() {
        error!("Caught empty API key string");
        ClearChatId();
        return
    } else if id_cstr.is_empty() {
        error!("Caught empty video_id string");
        ClearChatId();
        return
    }
    let addr = format!(
        "https://youtube.googleapis.com/youtube/v3/videos?part=snippet&id={}&key={}",
        id_cstr.to_string_lossy(), key_cstr.to_string_lossy()
    );
    info!("Checking video_id...");
    info!("{}", addr);

    TOKIO_RT.get().unwrap().spawn(async move {
        IS_BUSY = true;
        let resp = match minreq::get(addr).send() {
            Ok(val) => val,
            Err(err) => {
                error!("Failed to check video_id");
                error!("{}", err.to_string());
                ClearChatId();
                IS_BUSY = false;
                IS_VIDEO_ID_VALID = false;
                return
            }
        };
        match json::parse(resp.as_str().unwrap()) {
            Ok(mut val) => {
                if  val["items"].len() == 0
                    || !val["items"][0]["snippet"].has_key("liveBroadcastContent")
                {
                    error!("Looks like the video_id refers to a video or VOD");
                    IS_VIDEO_ID_VALID = false;
                    IS_BUSY = false;
                    return
                }
                let status = val["items"][0]["snippet"]["liveBroadcastContent"].take();
                if let Some("live") = status.as_str() {
                    IS_VIDEO_ID_VALID = true;
                    LAST_VALID_VIDEO_ID.set(id_cstr.to_str().unwrap().to_owned());
                } else {
                    ClearChatId();
                    IS_VIDEO_ID_VALID = false;
                }
                IS_BUSY = false;
            },
            Err(err) => {
                error!("Could not parse video_id check response");
                error!("{}", err.to_string());
                ClearChatId();
                IS_BUSY = false;
                IS_VIDEO_ID_VALID = false;
                return
            }
        }
    });
}

#[no_mangle]
pub unsafe extern fn SendChatId(raw_key: *const c_char, raw_id: *const c_char) {
    if raw_key.is_null() || raw_id.is_null() {
        error!("Caught null pointer string (API key or video_id)");
        return
    }
    let key_cstr = CStr::from_ptr(raw_key);
    let id_cstr = CStr::from_ptr(raw_id);
    if key_cstr.is_empty() {
        error!("Caught empty API key string");
        return
    } else if id_cstr.is_empty() {
        error!("Caught empty video_id string");
        return
    }
    let addr = format!(
        "https://youtube.googleapis.com/youtube/v3/videos?part=liveStreamingDetails&id={}&key={}",
        id_cstr.to_string_lossy(), key_cstr.to_string_lossy()
    );
    info!("Requesting activeLiveChatId for stream...");
    info!("{}", addr);

    TOKIO_RT.get().unwrap().spawn(async move {
        IS_BUSY = true;
        let resp = match minreq::get(addr).send() {
            Ok(val) => val,
            Err(err) => {
                error!("Failed to request the stream activeLiveChatId");
                error!("{}", err.to_string());
                IS_BUSY = false;
                return
            }
        };
        let resp_json = match json::parse(resp.as_str().unwrap()) {
            Ok(val) => val,
            Err(err) => {
                error!("Failed to parse response json");
                error!("{}", err.to_string());
                IS_BUSY = false;
                return
            }
        };
        CHAT_ID = Cell::new(
            resp_json["items"][0]["liveStreamingDetails"]
                ["activeLiveChatId"].as_str().unwrap()
                    .to_owned().replace("\"", "")
        );
        IS_BUSY = false;
    });
}

#[no_mangle]
pub unsafe extern fn StartPoll(
    raw_key: *const c_char,
    raw_chat_id: *const c_char,
    duration: u16,      // in secs
    poll_period: u32    // in millis
) {
    if raw_key.is_null() || raw_chat_id.is_null() {
        error!("Caught null pointer string (API key or activeLiveChatId)");
        return
    }
    let key_cstr = CStr::from_ptr(raw_key);
    let chat_id_cstr = CStr::from_ptr(raw_chat_id);
    if key_cstr.is_empty() {
        error!("Caught empty API key string");
        return
    } else if chat_id_cstr.is_empty() {
        error!("Caught empty activeLiveChatId string");
        return
    }
    let mut remaining = u64::from(1000 * duration);
    let poll_period = u64::from(poll_period);
    let from = chrono::Utc::now();
    let mut users_lock = UNIQUE_USERS.blocking_lock();
    *users_lock = vec![];
    let addr = format!(
        "https://www.googleapis.com/youtube/v3/liveChat/messages?part=id%2C%20snippet&key={}&liveChatId={}",
        key_cstr.to_string_lossy(), chat_id_cstr.to_string_lossy()
    );
    info!("Starting chat poll...");
    info!("{}", addr);

    TOKIO_RT.get().unwrap().spawn(async move {
        IS_BUSY = true;
        IS_POLL_RUNNING = true;
        let mut poll_lock = POLL_RESULT.write().await;
        *poll_lock = [0, 0, 0, 0];
        std::mem::drop(poll_lock);
        while remaining > 0 {
            let address = addr.clone();
            if remaining > poll_period {
                tokio::time::sleep(Duration::from_millis(poll_period)).await;
                remaining -= poll_period;
            } else {
                tokio::time::sleep(Duration::from_millis(remaining)).await;
                remaining = 0;
            }
            TOKIO_RT.get().unwrap().spawn(async move {
                let mut result: [u16; 4] = [0, 0, 0, 0];
                let resp = match minreq::get(address.as_str()).send() {
                    Ok(val) => val,
                    Err(err) => {
                        error!("Could not fetch chat messages");
                        error!("{}", err.to_string());
                        return
                    }
                };
                let resp_json = match json::parse(resp.as_str().unwrap()) {
                    Ok(val) => val,
                    Err(err) => {
                        error!("Could not parse messages list");
                        error!("{}", err.to_string());
                        return
                    }
                };
                for msg in resp_json["items"].members() {
                    let mut unique_users = UNIQUE_USERS.lock().await;
                    let user_id = msg["snippet"]["authorChannelId"].to_string();
                    let timestamp = chrono::DateTime::parse_from_rfc3339(
                        msg["snippet"]["publishedAt"].as_str().unwrap()
                    ).unwrap();
                    if !unique_users.contains(&user_id) && timestamp > from {
                        unique_users.push(user_id);
                        match parse(
                            msg["snippet"]["displayMessage"].as_str().unwrap()
                        ) {
                            Some(i) => { result[i - 1] += 1 },
                            None => { continue }
                        }
                    }
                }
                let mut lock = POLL_RESULT.write().await;
                lock[0] += result[0];
                lock[1] += result[1];
                lock[2] += result[2];
                lock[3] += result[3];
            });
        }
        IS_POLL_RUNNING = false;
        tokio::time::sleep(Duration::from_secs_f32(3.5)).await;
        IS_BUSY = false;
    });
}

fn parse(message: &str) -> Option<usize> {
    match message.chars().find(|ch| ch.is_ascii_digit()) {
        Some(val) => {
            let i = val.to_digit(10).unwrap();
            if 0 < i && i < 5 {
                return Some(i as usize)
            } else {
                return None
            }
        },
        None => { return None },
    }
}

#[no_mangle]
pub unsafe extern fn ClearChatId() {
    CHAT_ID.set(String::new());
}

#[no_mangle]
pub unsafe extern fn IsBusy() -> bool {
    IS_BUSY
}

#[no_mangle]
pub unsafe extern fn IsPollRunning() -> bool {
    IS_POLL_RUNNING
}

#[no_mangle]
pub unsafe extern fn GetApiKeyCheck() -> bool {
    IS_API_KEY_VALID
}

#[no_mangle]
pub unsafe extern fn GetVideoIdCheck() -> bool {
    IS_VIDEO_ID_VALID
}

#[no_mangle]
pub unsafe extern fn GetLastValidVideoId() -> *mut c_char {
    let result = CString::new(LAST_VALID_VIDEO_ID.get_mut().as_bytes()).unwrap();
    result.into_raw()
}

#[no_mangle]
pub unsafe extern fn GetChatId() -> *mut c_char {
    let result = CString::new(CHAT_ID.get_mut().as_bytes()).unwrap();
    result.into_raw()
}

#[no_mangle]
pub unsafe extern fn GetPollResult() -> *const [u16; 4] {
    &*POLL_RESULT.blocking_read()
}

#[no_mangle]
pub unsafe extern fn InterruptPoll() {
    let rt = TOKIO_RT.take().unwrap();
    rt.shutdown_background();
    TOKIO_RT.set(Runtime::new().unwrap()).unwrap();
    POLL_RESULT = RwLock::new([0, 0, 0, 0]);
    IS_POLL_RUNNING = false;
    IS_BUSY = false;
}
