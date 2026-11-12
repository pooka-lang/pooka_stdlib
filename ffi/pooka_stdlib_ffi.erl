%% SPDX-License-Identifier: Apache-2.0

%%% A small Erlang workshop behind the Pooka standard library.
%%%
%%% Most Pooka APIs keep their algorithms and types in Pooka. This module lends
%%% them OTP's files, clocks, processes, Unicode conversion and native maps.
%%% Values crossing this door use the BEAM representation expected by the
%%% declared external signatures; there is no second BEAM language in the middle.
%%%
%%% The two wrappers below describe different states. EOF is absence, not an
%%% operating-system error, and a command's nonzero exit is still completion.
%%%
%%% ```erlang
%%% {ok, {some, <<"oak\n">>}}. % a successfully read line
%%% {ok, none}.                % EOF
%%% {error, <<"reason">>}.     % a bridge failure
%%% {ok, {7, <<>>, <<"no">>}}. % a command completed with status 7
%%% ```
%%%
%%% Keep error conversion at the boundary, retain stdout/stderr separately, and
%%% preserve the old map when creating updated Storage capabilities. The Erlang
%%% formatter owns this file's layout; Pooka formatting does not apply here.

-module(pooka_stdlib_ffi).

-include_lib("kernel/include/file.hrl").

-export([
    cons/2,
    quotient/2,
    dict_new/1,
    dict_from_list/2,
    string_points/1,
    string_from_points/1,
    string_concat/2,
    string_join/2,
    string_split/2,
    string_contains/2,
    string_starts/2,
    string_ends/2,
    string_replace/3,
    string_trim/2,
    string_upper/1,
    string_lower/1,
    int_parse/1,
    int_string/1,
    int_float/1,
    int_to_float/1,
    float_parse/1,
    float_string/1,
    float_floor/1,
    float_ceil/1,
    float_round/1,
    float_truncate/1,
    float_sqrt/1,
    float_pow/2,
    io_print/2,
    io_read_line/0,
    io_read_char/0,
    io_flush/0,
    file_read/1,
    file_read_bytes/1,
    file_write/3,
    file_text/1,
    file_predicate/2,
    file_action/2,
    file_copy/2,
    file_rename/2,
    file_list/1,
    path_join/1,
    path_basename/1,
    path_dirname/1,
    path_extension/1,
    path_stem/1,
    path_absolute_test/1,
    path_normalize/1,
    path_absolute/1,
    path_relative/2,
    wall_time/0,
    monotonic_time/0,
    sleep/1,
    env_args/0,
    env_get/1,
    env_set/2,
    env_unset/1,
    env_cwd/0,
    env_home/0,
    process_run/3,
    process_pid/0,
    process_exit/1,
    process_run_timeout/3,
    int_to_base/2,
    int_parse_base/2,
    bits_byte_size/1,
    bits_bit_size/1,
    bits_concat/1,
    bits_slice/3,
    bits_to_string/1,
    io_is_terminal/1,
    hash_sha256/1,
    env_os/0,
    env_architecture/0
]).

%% Prepend a value to an immutable list. The values-first argument order follows the Pooka
%% pipe convention.
%%
%% ```erlang
%% cons([2, 3], 1). % [1,2,3]
%% ```
cons(Values, Value) -> [Value | Values].

%% Use integer div, truncating toward zero. The Pooka wrapper checks zero divisors where a
%% Result is promised.
%%
%% ```erlang
%% quotient(-5, 2). % -2
%% ```
quotient(A, B) -> A div B.

%% Capture an empty map in the typed Storage constructor supplied by Pooka.
dict_new(Create) -> dict_wrap(#{}, Create).

%% Build native map storage from pairs; the final occurrence of a key supplies its value.
dict_from_list(Pairs, Create) ->
    dict_wrap(maps:from_list(Pairs), Create).

%% Keep the map behind four capabilities: lookup, enumeration, count and persistent change.
%% No untyped map crosses the Pooka signature.
%%
%% ```erlang
%% % Lookup(Key) -> {some, Value} | none
%% % Change(Key, {some, Value}) -> NewStorage
%% % Change(Key, none) -> StorageWithoutKey
%% ```
dict_wrap(Map, Create) ->
    Create(
        fun(Key) ->
            case maps:find(Key, Map) of
                {ok, Value} -> {some, Value};
                error -> none
            end
        end,
        fun() -> maps:to_list(Map) end,
        fun() -> map_size(Map) end,
        fun(Key, Value) ->
            dict_wrap(
                case Value of
                    {some, V} -> maps:put(Key, V, Map);
                    none -> maps:remove(Key, Map)
                end,
                Create
            )
        end
    ).

%% Decode a trusted UTF-8 binary into Unicode code-point integers.
%%
%% ```erlang
%% string_points(<<"A">>). % [65]
%% ```
string_points(B) -> unicode:characters_to_list(B, utf8).

%% Encode a code-point list as a UTF-8 binary.
string_from_points(P) -> unicode:characters_to_binary(P).

%% Concatenate two trusted UTF-8 binary values without turning them into character lists.
string_concat(A, B) -> <<A/binary, B/binary>>.

%% Interleave a binary separator between parts and flatten the resulting iolist once.
string_join(P, S) -> iolist_to_binary(lists:join(S, P)).

%% Split globally; an empty separator selects individual Unicode code points.
%%
%% ```erlang
%% string_split(<<"oak:pine">>, <<":">>). % [<<"oak">>,<<"pine">>]
%% ```
string_split(B, <<>>) ->
    [unicode:characters_to_binary([C]) || C <- string_points(B)];
string_split(B, S) ->
    binary:split(B, S, [global]).

%% Test binary substring membership. The empty substring is explicitly accepted.
string_contains(_, <<>>) -> true;
string_contains(B, S) -> binary:match(B, S) =/= nomatch.

%% Check prefix length before asking binary:part for a slice.
string_starts(B, S) ->
    byte_size(S) =< byte_size(B) andalso
        binary:part(B, 0, byte_size(S)) =:= S.

%% Check suffix length before selecting the final bytes.
string_ends(B, S) ->
    byte_size(S) =< byte_size(B) andalso
        binary:part(B, byte_size(B) - byte_size(S), byte_size(S)) =:= S.

%% Replace all occurrences of a nonempty search binary. Empty search leaves the text
%% unchanged.
string_replace(B, <<>>, _) -> B;
string_replace(B, S, R) -> binary:replace(B, S, R, [global]).

%% Choose both, leading or trailing trimming over the explicit whitespace code-point set.
string_trim(B, N) ->
    unicode:characters_to_binary(
        string:trim(
            B,
            case N of
                0 -> both;
                1 -> leading;
                2 -> trailing
            end,
            [
                9,
                10,
                11,
                12,
                13,
                32,
                133,
                160,
                5760,
                8192,
                8193,
                8194,
                8195,
                8196,
                8197,
                8198,
                8199,
                8200,
                8201,
                8202,
                8232,
                8233,
                8239,
                8287,
                12288
            ]
        )
    ).

%% Apply Unicode uppercase conversion and return a UTF-8 binary.
string_upper(B) -> unicode:characters_to_binary(string:uppercase(B)).

%% Apply Unicode lowercase conversion and return a UTF-8 binary.
string_lower(B) -> unicode:characters_to_binary(string:lowercase(B)).

%% Parse an integer binary, translating a bad spelling into the foreign error
%% representation.
int_parse(B) ->
    case re:run(B, <<"^[+-]?[0-9]+$">>, [{capture, none}]) of
        match -> protect(fun() -> {ok, binary_to_integer(B)} end);
        nomatch -> {error, <<"invalid integer">>}
    end.

%% Render an arbitrary-precision integer as decimal bytes.
int_string(N) -> integer_to_binary(N).

%% Convert a trusted integer to float for internal clock arithmetic.
int_float(N) -> float(N).

%% Perform the fallible public conversion, retaining out-of-range failures as an error
%% binary.
%%
%% ```erlang
%% int_to_float(2). % {ok,2.0}
%% ```
int_to_float(N) -> protect(fun() -> {ok, float(N)} end).

%% Validate the supported decimal spelling and normalize it for Erlang float conversion.
float_parse(B) ->
    case
        re:run(
            B,
            <<
                "^[+-]?(?:[0-9]+(?:\\.[0-9]+)?|\\.[0-9]+)(?:[eE][+-]?[0-9"
                "]+)?$"
            >>,
            [{capture, none}]
        )
    of
        nomatch ->
            {error, <<"invalid float">>};
        match ->
            protect(fun() ->
                S =
                    case B of
                        <<"+", Rest/binary>> -> Rest;
                        _ -> B
                    end,
                S1 =
                    case S of
                        <<".", R/binary>> -> <<"0.", R/binary>>;
                        <<"-.", R/binary>> -> <<"-0.", R/binary>>;
                        _ -> S
                    end,
                Parts = re:split(
                    S1,
                    <<"[eE]">>,
                    [{return, binary}]
                ),
                Normal =
                    case Parts of
                        [Mantissa] ->
                            case
                                binary:match(
                                    Mantissa,
                                    <<".">>
                                )
                            of
                                nomatch ->
                                    <<Mantissa/binary, ".0">>;
                                _ ->
                                    Mantissa
                            end;
                        [Mantissa, Exponent] ->
                            M =
                                case
                                    binary:match(
                                        Mantissa,
                                        <<".">>
                                    )
                                of
                                    nomatch ->
                                        <<Mantissa/binary, ".0">>;
                                    _ ->
                                        Mantissa
                                end,
                            <<M/binary, "e", Exponent/binary>>
                    end,
                {ok, binary_to_float(Normal)}
            end)
    end.

%% Use the runtime's shortest floating-point binary representation.
float_string(N) -> float_to_binary(N, [short]).

%% Round toward negative infinity and return an integer.
float_floor(N) -> floor(N).

%% Round toward positive infinity and return an integer.
float_ceil(N) -> ceil(N).

%% Use Erlang's nearest-integer rounding operation.
float_round(N) -> round(N).

%% Discard the fractional part toward zero.
float_truncate(N) -> trunc(N).

%% Keep math:sqrt domain failures inside the foreign Result boundary.
float_sqrt(N) -> protect(fun() -> {ok, math:sqrt(N)} end).

%% Keep math:pow domain failures inside the foreign Result boundary.
float_pow(B, E) -> protect(fun() -> {ok, math:pow(B, E)} end).

%% Translate caught Erlang exception classes and reasons to the shared binary error
%% representation. Successful return shapes remain the caller's responsibility.
%%
%% ```erlang
%% protect(fun() -> {ok, math:sqrt(-1)} end). % {error, BinaryReason}
%% ```
protect(F) ->
    try
        F()
    catch
        error:R -> {error, reason(R)};
        exit:R -> {error, reason(R)}
    end.

%% Render an Erlang failure reason as UTF-8 text without manufacturing new atoms.
reason(R) when is_atom(R) -> atom_to_binary(R, utf8);
reason(R) -> unicode:characters_to_binary(io_lib:format("~tp", [R])).

%% Translate file-style ok into Pooka's {ok,nil}, preserving error reasons as binaries.
%%
%% ```erlang
%% unit(ok). % {ok,nil}
%% ```
unit(ok) -> {ok, nil};
unit({error, R}) -> {error, reason(R)}.

%% Accept only valid UTF-8 binary input. Invalid and incomplete conversions become a shared
%% error result.
%%
%% ```erlang
%% utf8(<<255>>). % {error, BinaryReason}
%% ```
utf8(B) when is_binary(B) ->
    case unicode:characters_to_binary(B, utf8, utf8) of
        Text when is_binary(Text) -> {ok, Text};
        _ -> {error, <<"invalid UTF-8">>}
    end;
utf8(_) ->
    {error, <<"expected whole bytes">>}.

%% Choose standard_io or standard_error explicitly and issue a synchronous Unicode output
%% request.
io_print(Text, Error) ->
    protect(fun() ->
        unit(
            io:put_chars(
                case Error of
                    true -> standard_error;
                    false -> standard_io
                end,
                unicode:characters_to_list(Text)
            )
        )
    end).

%% Read one line from standard_io with its terminator retained.
io_read_line() -> read_io(fun() -> io:get_line(standard_io, "") end).

%% Read one Unicode code point from standard_io; a combining mark remains a separate point.
io_read_char() ->
    read_io(fun() -> io:get_chars(standard_io, "", 1) end).

%% Normalize EOF to {ok,none}, text to {ok,{some,Binary}}, and device/encoding failures to
%% errors.
%%
%% ```erlang
%% % eof -> {ok,none}
%% % "oak\n" -> {ok,{some,<<"oak\n">>}}
%% % {error,Reason} -> {error,BinaryReason}
%% ```
read_io(Read) ->
    protect(fun() ->
        case Read() of
            eof ->
                {ok, none};
            {error, R} ->
                {error, reason(R)};
            Text ->
                case unicode:characters_to_binary(Text) of
                    B when is_binary(B) -> {ok, {some, B}};
                    _ -> {error, <<"invalid input encoding">>}
                end
        end
    end).

%% Issue an ordered empty write on standard_io. Earlier synchronous output requests have
%% completed before it returns.
io_flush() -> io_print(<<>>, false).

%% Read a file and validate UTF-8 before exposing it as Pooka String.
file_read(P) ->
    case file:read_file(P) of
        {ok, B} -> utf8(B);
        {error, R} -> {error, reason(R)}
    end.

%% Read the original file bytes without a text-decoding promise.
file_read_bytes(P) ->
    case file:read_file(P) of
        {ok, B} -> {ok, B};
        {error, R} -> {error, reason(R)}
    end.

%% Use the runtime binary representation shared by Pooka String and whole-byte BitArray.
file_text(Text) -> Text.

%% Write or append whole-byte binaries, rejecting non-byte-aligned input before the file
%% API.
file_write(P, B, Append) when is_binary(B) ->
    protect(fun() ->
        unit(
            file:write_file(
                P,
                B,
                case Append of
                    true -> [append];
                    false -> []
                end
            )
        )
    end);
file_write(_, _, _) ->
    {error, <<"expected whole bytes">>}.

%% Classify a path. Missing entries and non-directory parents yield false; other failures
%% remain errors.
file_predicate(P, Kind) ->
    case file:read_file_info(P) of
        {ok, #file_info{type = T}} ->
            {ok,
                case Kind of
                    0 -> true;
                    1 -> T =:= regular;
                    2 -> T =:= directory
                end};
        {error, enoent} ->
            {ok, false};
        {error, enotdir} ->
            {ok, false};
        {error, R} ->
            {error, reason(R)}
    end.

%% Dispatch deletion and directory operations, retaining the checked idempotent behavior of
%% recursive creation.
file_action(P, Kind) ->
    protect(fun() ->
        unit(
            case Kind of
                0 ->
                    file:delete(P);
                1 ->
                    file:make_dir(P);
                2 ->
                    case filelib:ensure_path(P) of
                        ok ->
                            case file:make_dir(P) of
                                {error, eexist} ->
                                    case filelib:is_dir(P) of
                                        true -> ok;
                                        false -> {error, enotdir}
                                    end;
                                Result ->
                                    Result
                            end;
                        Result ->
                            Result
                    end;
                3 ->
                    file:del_dir(P)
            end
        )
    end).

%% Normalize the byte count returned by file:copy to a unit success.
file_copy(A, B) ->
    case file:copy(A, B) of
        {ok, _} -> {ok, nil};
        {error, R} -> {error, reason(R)}
    end.

%% Rename through the filesystem API and normalize its unit result.
file_rename(A, B) -> unit(file:rename(A, B)).

%% List directory entries as UTF-8 binaries, preserving the runtime's unspecified
%% enumeration order.
file_list(P) ->
    case file:list_dir(P) of
        {ok, Names} -> {ok, [unicode:characters_to_binary(N) || N <- Names]};
        {error, R} -> {error, reason(R)}
    end.

%% Join host path components. Empty input is the relative current-directory marker.
path_join([]) -> <<".">>;
path_join(Parts) -> filename:join(Parts).

%% Read the final path component using host filename conventions.
path_basename(P) -> filename:basename(P).

%% Read the parent path using host filename conventions.
path_dirname(P) -> filename:dirname(P).

%% Represent a missing extension as none and a present leading-dot suffix as some.
%%
%% ```erlang
%% path_extension(<<"notes.txt">>). % {some,<<".txt">>}
%% ```
path_extension(P) ->
    case filename:extension(P) of
        <<>> -> none;
        E -> {some, E}
    end.

%% Remove the final extension from the basename.
path_stem(P) -> filename:rootname(filename:basename(P)).

%% Ask the host filename module whether the path is absolute.
path_absolute_test(P) -> filename:pathtype(P) =:= absolute.

%% Normalize lexical dot and parent components. This does not traverse the filesystem or
%% resolve symlinks.
path_normalize(P) ->
    Parts = filename:split(P),
    Stack = lists:foldl(
        fun
            (<<".">>, Acc) -> Acc;
            (<<"..">>, [<<"/">>] = Acc) -> Acc;
            (<<"..">>, [<<"..">> | _] = Acc) -> [<<"..">> | Acc];
            (<<"..">>, []) -> [<<"..">>];
            (<<"..">>, [_ | Rest]) -> Rest;
            (Part, Acc) -> [Part | Acc]
        end,
        [],
        Parts
    ),
    path_join(lists:reverse(Stack)).

%% Resolve relative paths against the current directory, then normalize them lexically.
path_absolute(P) ->
    protect(fun() ->
        case file:get_cwd() of
            {ok, Cwd} ->
                {ok,
                    path_normalize(
                        filename:absname(
                            P,
                            unicode:characters_to_binary(Cwd)
                        )
                    )};
            {error, R} ->
                {error, reason(R)}
        end
    end).

%% Resolve both paths, discard their common prefix and construct a lexical route from base
%% to target.
path_relative(P, B) ->
    case {path_absolute(P), path_absolute(B)} of
        {{ok, Path}, {ok, Base}} ->
            {A, C} = drop_common(filename:split(Path), filename:split(Base)),
            {ok, path_join(lists:duplicate(length(C), <<"..">>) ++ A)};
        {{error, E}, _} ->
            {error, E};
        {_, {error, E}} ->
            {error, E}
    end.

%% Discard equal leading path components without confusing a string prefix with a path-
%% component prefix.
%%
%% ```erlang
%% drop_common([<<"notes">>,<<"oak">>], [<<"notes">>,<<"pine">>]).
%% % {[<<"oak">>],[<<"pine">>]}
%% ```
drop_common([A | As], [A | Bs]) -> drop_common(As, Bs);
drop_common(A, B) -> {A, B}.

%% Read wall-clock milliseconds for Timestamp. The calendar clock may be adjusted.
wall_time() -> erlang:system_time(millisecond).

%% Read monotonic milliseconds for elapsed measurements; do not interpret these as calendar
%% dates.
monotonic_time() -> erlang:monotonic_time(millisecond).

%% Accept only the supported timer range and translate the sleep completion to unit.
sleep(N) when N >= 0, N =< 4294967295 ->
    timer:sleep(N),
    {ok, nil};
sleep(_) ->
    {error, <<"duration out of range">>}.

%% Drop the bootstrap executable argument only for the generated Pooka escript entrypoint.
%% Ordinary run arguments keep their first user value.
%%
%% ```erlang
%% % escript bootstrap, "one", "two" -> [<<"one">>,<<"two">>]
%% % ordinary run, "one", "two" -> [<<"one">>,<<"two">>]
%% ```
env_args() ->
    Plain = init:get_plain_arguments(),
    Escript = lists:any(
        fun({M, _}) ->
            lists:suffix(
                "@@entrypoint@escript",
                atom_to_list(M)
            )
        end,
        code:all_loaded()
    ),
    Args =
        case {Escript, Plain} of
            {true, [_ | Rest]} -> Rest;
            _ -> Plain
        end,
    [unicode:characters_to_binary(A) || A <- Args].

%% Reject empty environment names, embedded NUL bytes and equals signs before calling the OS
%% interface.
valid_name(N) ->
    byte_size(N) > 0 andalso
        binary:match(N, <<0>>) =:= nomatch andalso
        binary:match(N, <<"=">>) =:= nomatch.

%% Represent an absent variable as none, retaining process-environment failures as errors.
env_get(N) ->
    case valid_name(N) of
        false ->
            {error, <<"invalid environment name">>};
        true ->
            protect(fun() ->
                case os:getenv(unicode:characters_to_list(N)) of
                    false -> {ok, none};
                    V -> {ok, {some, unicode:characters_to_binary(V)}}
                end
            end)
    end.

%% Validate the name and NUL-free value before changing this process's environment.
env_set(N, V) ->
    case valid_name(N) andalso binary:match(V, <<0>>) =:= nomatch of
        false ->
            {error, <<"invalid environment name or value">>};
        true ->
            protect(fun() ->
                true = os:putenv(
                    unicode:characters_to_list(N),
                    unicode:characters_to_list(V)
                ),
                {ok, nil}
            end)
    end.

%% Validate the name before removing the process-environment entry.
env_unset(N) ->
    case valid_name(N) of
        false ->
            {error, <<"invalid environment name">>};
        true ->
            protect(fun() ->
                true = os:unsetenv(unicode:characters_to_list(N)),
                {ok, nil}
            end)
    end.

%% Read the current working directory as UTF-8 bytes.
env_cwd() ->
    case file:get_cwd() of
        {ok, P} -> {ok, unicode:characters_to_binary(P)};
        {error, R} -> {error, reason(R)}
    end.

%% Select the platform's home variable and preserve absence with Option.
env_home() ->
    env_get(
        case os:type() of
            {win32, _} -> <<"USERPROFILE">>;
            _ -> <<"HOME">>
        end
    ).

%% Return the operating-system process identifier, not an Erlang pid term.
process_pid() -> list_to_integer(os:getpid()).

%% Terminate this application VM with the supplied exit status; this operation does not
%% return.
process_exit(Code) -> erlang:halt(Code).

%% Run without a deadline and expose completed status, stdout and stderr separately.
%%
%% ```erlang
%% process_run(<<"printf">>, [<<"%s">>,<<"oak">>], none).
%% % {ok,{0,<<"oak">>,<<>>}}
%% ```
process_run(Command, Args, Directory) ->
    case process_launch(Command, Args, Directory, infinity) of
        {ok, {completed, Status, Out, Err}} -> {ok, {Status, Out, Err}};
        {error, _} = Error -> Error
    end.

%% Keep a completed command in some and a deadline expiration in none. Launch errors remain
%% the error branch.
process_run_timeout(_, _, Timeout) when Timeout < 0 ->
    {error, <<"timeout must not be negative">>};
process_run_timeout(Command, Args, Timeout) ->
    case process_launch(Command, Args, none, Timeout) of
        {ok, {completed, Status, Out, Err}} -> {ok, {some, {Status, Out, Err}}};
        {ok, timed_out} -> {ok, none};
        {error, _} = Error -> Error
    end.

%% Resolve the executable and working directory before opening a port. The current
%% implementation explicitly rejects unsupported non-POSIX hosts.
process_launch(Command, Args, Directory, Timeout) ->
    protect(fun() ->
        case os:type() of
            {win32, _} ->
                {error, <<"process execution currently requires a POSIX host">>};
            _ ->
                Cwd =
                    case Directory of
                        none ->
                            case file:get_cwd() of
                                {ok, D} -> D;
                                {error, R} -> error(R)
                            end;
                        {some, D} ->
                            unicode:characters_to_list(D)
                    end,
                Abs = filename:absname(Cwd),
                case filelib:is_dir(Abs) of
                    false ->
                        {error, <<"working directory does not exist">>};
                    true ->
                        Name = unicode:characters_to_list(Command),
                        Executable =
                            case filename:pathtype(Name) of
                                absolute ->
                                    Name;
                                _ ->
                                    case
                                        lists:member(
                                            $/,
                                            Name
                                        )
                                    of
                                        true ->
                                            filename:join(
                                                Abs,
                                                Name
                                            );
                                        false ->
                                            os:find_executable(Name)
                                    end
                            end,
                        case Executable of
                            false ->
                                {error, <<"command not found">>};
                            _ ->
                                case filelib:is_regular(Executable) of
                                    true ->
                                        run_port(
                                            Executable,
                                            Args,
                                            Abs,
                                            Timeout
                                        );
                                    false ->
                                        {error, <<"command not found">>}
                                end
                        end
                end
        end
    end).

%% Give stderr a private temporary file and stdout a port. A fixed shell trampoline passes
%% the executable and arguments through quoted argv, never interpolated command text.
%%
%% ```erlang
%% % Fixed trampoline; Err, Executable and Args are separate argv entries:
%% % err=$1; shift; exec "$@" </dev/null 2>"$err"
%% ```
run_port(Executable, Args, Cwd, Timeout) ->
    TempBase =
        case os:getenv("TMPDIR") of
            false -> "/tmp";
            D -> D
        end,
    Temp = filename:join(
        TempBase,
        "pooka-stdlib-" ++
            os:getpid() ++
            "-" ++
            integer_to_list(
                erlang:unique_integer([
                    positive,
                    monotonic
                ])
            )
    ),
    ok = file:make_dir(Temp),
    try
        ok = file:change_mode(Temp, 448),
        Err = filename:join(Temp, "stderr"),
        Port = open_port(
            {spawn_executable, "/bin/sh"},
            [
                binary,
                exit_status,
                use_stdio,
                hide,
                {cd, Cwd},
                {args, [
                    "-c",
                    "err=$1; shift; exec \"$@\" </dev/null 2>\"$err\"",
                    "pooka-port",
                    Err,
                    Executable
                    | [unicode:characters_to_list(A) || A <- Args]
                ]}
            ]
        ),
        Timer =
            case Timeout of
                infinity -> none;
                _ -> erlang:start_timer(Timeout, self(), pooka_process_timeout)
            end,
        case collect(Port, Timer, []) of
            timed_out ->
                {ok, timed_out};
            {Status, Output} ->
                case file:read_file(Err) of
                    {ok, Error} ->
                        case {utf8(Output), utf8(Error)} of
                            {{ok, Out}, {ok, E}} -> {ok, {completed, Status, Out, E}};
                            _ -> {error, <<"command output is not UTF-8">>}
                        end;
                    {error, R} ->
                        {error, reason(R)}
                end
        end
    after
        file:delete(filename:join(Temp, "stderr")),
        file:del_dir(Temp)
    end.

%% Drain stdout until exit or this operation's timer wins. Cancel/drain timers on completion
%% and close the owned port on timeout.
%%
%% ```erlang
%% % {Port,{data,Bytes}} -> keep draining
%% % {Port,{exit_status,Status}} -> complete
%% % {timeout,Timer,pooka_process_timeout} -> stop owned command
%% ```
collect(Port, Timer, Acc) ->
    receive
        {Port, {data, Data}} ->
            collect(Port, Timer, [Data | Acc]);
        {Port, {exit_status, Status}} ->
            cancel_timer(Timer),
            {Status, iolist_to_binary(lists:reverse(Acc))};
        {timeout, Timer, pooka_process_timeout} ->
            case erlang:port_info(Port, os_pid) of
                {os_pid, Pid} -> os:cmd("kill -KILL " ++ integer_to_list(Pid));
                undefined -> ok
            end,
            try
                erlang:port_close(Port)
            catch
                error:badarg -> ok
            end,
            timed_out
    end.

%% Cancel the owned timer and consume an already delivered timeout message, so it cannot
%% disturb the next operation.
cancel_timer(none) ->
    ok;
cancel_timer(Timer) ->
    _ = erlang:cancel_timer(Timer),
    receive
        {timeout, Timer, _} -> ok
    after 0 -> ok
    end.

%% Format bases two through thirty-six with lowercase digits; the Pooka caller validates the
%% base.
int_to_base(N, Base) ->
    string:lowercase(integer_to_binary(N, Base)).

%% Catch invalid base or digit failures and return the small foreign parse-error marker.
int_parse_base(Text, Base) ->
    try
        {ok, binary_to_integer(Text, Base)}
    catch
        error:_ -> {error, nil}
    end.

%% Return byte_size for a bitstring, including a partial final byte in its occupied byte
%% count.
bits_byte_size(Bits) -> erlang:byte_size(Bits).

%% Return the exact count of bits, including non-byte-aligned tails.
bits_bit_size(Bits) -> erlang:bit_size(Bits).

%% Concatenate bitstring parts without padding them to byte boundaries.
%%
%% ```erlang
%% bits_concat([<<1:1>>, <<0:1>>]). % <<2:2>>
%% ```
bits_concat(Parts) -> erlang:list_to_bitstring(Parts).

%% Select a whole-byte range after checking nonnegative bounds against the source byte size.
bits_slice(Bits, Start, Length) ->
    case
        Start >= 0 andalso Length >= 0 andalso
            Start + Length =< erlang:byte_size(Bits)
    of
        true -> {ok, binary:part(Bits, Start, Length)};
        false -> {error, nil}
    end.

%% Map UTF-8 validation to the public bridge's small invalid-text marker.
%%
%% ```erlang
%% bits_to_string(<<65>>). % {ok,<<"A">>}
%% ```
bits_to_string(Bits) ->
    case utf8(Bits) of
        {ok, Text} -> {ok, Text};
        {error, _} -> {error, nil}
    end.

%% Asks the runtime about the VM's own descriptors, which works without an
%% Erlang shell; older runtimes without prim_tty report False.
%% Ask prim_tty about the VM descriptor directly, including a VM without an Erlang shell.
%% Older runtimes fall back to false.
io_is_terminal(Error) ->
    Fd =
        case Error of
            true -> stderr;
            false -> stdout
        end,
    try
        prim_tty:isatty(Fd) =:= true
    catch
        error:_ -> false
    end.

%% Return the raw thirty-two-byte SHA-256 digest through OTP crypto.
hash_sha256(Data) -> crypto:hash(sha256, Data).

%% Return the operating-system name from os:type as UTF-8 bytes.
env_os() ->
    {_, Name} = os:type(),
    atom_to_binary(Name, utf8).

%% Expose the runtime system architecture as UTF-8 bytes.
env_architecture() ->
    unicode:characters_to_binary(erlang:system_info(system_architecture)).
