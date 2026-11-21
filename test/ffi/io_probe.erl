%% SPDX-License-Identifier: Apache-2.0
-module(io_probe).
-export([capture/2]).

%% Isolated stdout for this test process. The device can accept writes or
%% return an error without touching the node's real standard streams.
capture(Fail, Work) ->
    Original = group_leader(),
    Device = spawn(fun() -> device(Fail, []) end),
    group_leader(Device, self()),
    try
        Value = Work(),
        Ref = make_ref(),
        Device ! {output, self(), Ref},
        receive {Ref, Text} -> {Value, Text}
        after 1000 -> erlang:error(io_probe_timeout)
        end
    after
        group_leader(Original, self()),
        Device ! stop
    end.

device(Fail, Chunks) ->
    receive
        {io_request, From, Reply, {put_chars, _Encoding, Chars}} ->
            From ! {io_reply, Reply, case Fail of true -> {error, enospc}; false -> ok end},
            device(Fail, [Chars | Chunks]);
        {output, From, Ref} ->
            From ! {Ref, unicode:characters_to_binary(lists:reverse(Chunks))},
            device(Fail, Chunks);
        stop -> ok
    end.
