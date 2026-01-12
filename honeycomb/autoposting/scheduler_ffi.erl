-module(scheduler_ffi).
-export([get_current_time/0]).

%% Get current time in ISO 8601 format (UTC)
get_current_time() ->
    {{Year, Month, Day}, {Hour, Minute, Second}} = calendar:universal_time(),
    io_lib:format("~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0BZ",
                  [Year, Month, Day, Hour, Minute, Second]).
