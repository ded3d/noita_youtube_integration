void Init(const char *version);
void SendApiKeyCheck(const char* raw_key);
void SendVideoIdCheck(const char* raw_key, const char* raw_id);
void SendChatId(const char* raw_key, const char* raw_id);
void StartPoll(const char* raw_key,
               const char* raw_chat_id,
               uint16_t duration,
               uint32_t poll_period);
bool IsBusy(void);
bool IsPollRunning(void);
void ClearChatId(void);
bool GetApiKeyCheck(void);
bool GetVideoIdCheck(void);
char* GetLastValidVideoId(void);
char* GetChatId(void);
const uint16_t (*GetPollResult(void))[4];
void InterruptPoll(void);
