-module(qetag).
-include_lib("kernel/include/file.hrl").

-compile(export_all).

-define(BLOCK_SIZE, 4194304).

etag_file(FileName) ->
    {ok, FInfo} = file:read_file_info(FileName),
    Fsize = FInfo#file_info.size,
    if
        Fsize > ?BLOCK_SIZE ->
            {ok, File} = file:open(FileName, [read, binary]),
            try
                etag_big(File, Fsize)
            after
                file:close(File)
            end;
        true -> etag_small_file(FileName)
    end.


etag_small_file(File_path) ->
    {ok, File_data} = file:read_file(File_path),
    etag_small_stream(File_data).


etag_small_stream(Input_stream) ->
    %%urlsafe_base64_encode(
        erlang:iolist_to_binary([<<22>>, crypto:hash(sha, Input_stream)]).


etag_big(File, Fsize) ->
    {Num_thread,  Num_blocks_in_rawblock, Num_blocks_in_lastsize, Start} = get_num_thread(Fsize),
    First_part_sha1 = combine_sha1( <<>>,
                                    lists:sort(sha1_list(File, Num_thread, Num_blocks_in_rawblock))),
    if
        Num_blocks_in_lastsize == 0 ->            
            %%urlsafe_base64_encode(
                    erlang:iolist_to_binary([<<150>>, crypto:hash(sha, First_part_sha1)]);
        true ->
            Second_part_sha1 = combine_sha1(<<>>,
                                            lists:sort(sha1_list_last(File, Num_blocks_in_lastsize, Start))),
            %%urlsafe_base64_encode(
                erlang:iolist_to_binary([<<150>>,
                                        crypto:hash(sha, erlang:iolist_to_binary([First_part_sha1, Second_part_sha1]))])
    end.


get_num_thread(Fsize) ->
    PoolSize = erlang:system_info(thread_pool_size),
    Num_blocks_in_rawblock = Fsize div ?BLOCK_SIZE div PoolSize,
    Onetime_size = PoolSize * ?BLOCK_SIZE * Num_blocks_in_rawblock,
    Last_size = Fsize - Onetime_size,
    Num_blocks_in_lastsize = Last_size div ?BLOCK_SIZE,
    if
        Fsize / ?BLOCK_SIZE == Fsize div ?BLOCK_SIZE ->
            {PoolSize - 1,  Num_blocks_in_rawblock - 1, Num_blocks_in_lastsize - 1, Num_blocks_in_rawblock * PoolSize};
        true ->
            {PoolSize - 1,  Num_blocks_in_rawblock - 1, Num_blocks_in_lastsize, Num_blocks_in_rawblock * PoolSize}
    end.



sha1_list(File, Num_thread, Num_blocks_in_rawblock) ->
    upmap(fun (Off) ->
        Read_start = Off * (Num_blocks_in_rawblock + 1),
        Read_off = Read_start + Num_blocks_in_rawblock,
        SHA1_list_rawblock = get_rawblock_sha1_list(File, lists:seq(Read_start, Read_off), <<>>),
        [{Off, SHA1_list_rawblock}]
           end, lists:seq(0, Num_thread)).


sha1_list_last(File, Num_thread, Start)->
    upmap(fun (Off)->
        {ok, Fd_bs} = file:pread(File, (Off + Start) * ?BLOCK_SIZE, ?BLOCK_SIZE),
        SHA1 = crypto:hash(sha, Fd_bs),
        %%file:close(File),
        [{Off, SHA1}]
           end, lists:seq(0, Num_thread)).


get_rawblock_sha1_list(_, [], Raw_BIN) ->
    Raw_BIN;
get_rawblock_sha1_list(File, [H|T], Raw_bin) ->
    {ok, Fd_bs} = file:pread(File,  H * ?BLOCK_SIZE, ?BLOCK_SIZE),
    Raw_BIN = erlang:iolist_to_binary([Raw_bin, crypto:hash(sha, Fd_bs)]),
    %%file:close(File),
    get_rawblock_sha1_list(File,  T, Raw_BIN).


upmap(F, L) ->
    Parent = self(),
    Ref = make_ref(),
    [receive {Ref, Result} ->
        Result ++ []
     end
        || _ <- [spawn(fun() -> Parent ! {Ref, F(X)} end) || X <- L]].


combine_sha1(SHA1_BIN, []) ->
    SHA1_BIN;
combine_sha1(SHA1_bin, [H|T]) ->
    [{_, RAW_SHA1}] = H,
    SHA1_BIN = erlang:iolist_to_binary([SHA1_bin, RAW_SHA1]),
    combine_sha1(SHA1_BIN, T).

%%urlsafe_base64_encode(Data) ->
    %%binary:bin_to_list(base64url:encode_mime(Data)).