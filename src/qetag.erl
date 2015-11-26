-module(qetag).
-include_lib("kernel/include/file.hrl").

-compile(export_all).

-define(BLOCK_SIZE, 4194304).

etag_file(Filename) ->
    {ok, FInfo} = file:read_file_info(Filename),
    Fsize = FInfo#file_info.size,
    if
        Fsize > ?BLOCK_SIZE ->
            etag_big(Filename, Fsize);
        true -> erlang:display([hehe])
    end.


etag_small_stream(Input_stream) ->
    urlsafe_base64_encode(erlang:iolist_to_binary([<<22>>, crypto:hash(sha, Input_stream)])).


etag_small_file(File_path) ->
    {ok, File_data} = file:read_file(File_path),
    etag_small_stream(File_data).


etag_middle_file(Filename, Fsize) ->
    Num_blocks = Fsize div ?BLOCK_SIZE,
    urlsafe_base64_encode
    (erlang:iolist_to_binary
    ([<<150>>,
        crypto:hash(sha,
            get_rawblock_sha1_list(Filename,
                lists:seq(0, Num_blocks), <<>>))])).


get_rawblock_sha1_list(_, [], Raw_BIN) ->
    Raw_BIN;
get_rawblock_sha1_list(Filename, [H|T], Raw_bin) ->
    {ok, Fd} = file:open(Filename, [raw, binary]),
    {ok, Fd_bs} = file:pread(Fd,  H * ?BLOCK_SIZE, ?BLOCK_SIZE),
    Raw_BIN = erlang:iolist_to_binary([Raw_bin, crypto:hash(sha, Fd_bs)]),
    file:close(Fd),
    get_rawblock_sha1_list(Filename,  T, Raw_BIN).


etag_big(Filename, Fsize) ->
    {Num_thread,  Num_blocks_in_rawblock, Num_blocks_in_lastsize, Start} = get_num_thread(Fsize),
    if
        Num_blocks_in_lastsize == 0 ->
            First_part_sha1 = combine_sha1(
                                    lists:sort(
                                        sha1_list(Filename, Num_thread, Num_blocks_in_rawblock)), <<>>),
                urlsafe_base64_encode(erlang:iolist_to_binary([<<150>>,
                    crypto:hash(sha, First_part_sha1)]));
        true ->
            First_part_sha1 = combine_sha1(
                                    lists:sort(
                                        sha1_list(Filename, Num_thread, Num_blocks_in_rawblock)), <<>>),
            Second_part_sha1 = combine_sha1(
                                    lists:sort(sha1_list_last(Filename, Num_blocks_in_lastsize, Start)), <<>>),
                urlsafe_base64_encode(erlang:iolist_to_binary([<<150>>,
                    crypto:hash(sha,
                        erlang:iolist_to_binary([First_part_sha1, Second_part_sha1]))]))
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


sha1_list(Filename, Num_thread, Num_blocks_in_rawblock) ->
    up_map(fun (Off) ->
        %%SHA1_maps_rawblock_init = maps:new(),
        Read_start = Off * (Num_blocks_in_rawblock + 1),
        Read_off = Read_start + Num_blocks_in_rawblock,
        SHA1_list_rawblock = get_rawblock_sha1_list(Filename, lists:seq(Read_start, Read_off), <<>>),
        %%maps:put(Off, SHA1_list_rawblock, SHA1_maps_rawblock_init)
        [{Off, SHA1_list_rawblock}]
           end, lists:seq(0, Num_thread)).


up_map(F, L) ->
    Parent = self(),
    Ref = make_ref(),
    [receive {Ref, Result} ->
        Result ++ []
        %%SHA1_maps = maps:new(),
        %%maps:merge(SHA1_maps, Result)
     end
        || _ <- [spawn(fun() -> Parent ! {Ref, F(X)} end) || X <- L]].


sha1_list_last(Filename, Num_thread, Start)->
    up_map(fun (Off)->
      %%SHA1_maps_init = maps:new(),
      {ok, Fd} = file:open(Filename, [raw, binary]),
      {ok, Fd_bs} = file:pread(Fd, (Off + Start) * ?BLOCK_SIZE, ?BLOCK_SIZE),
      SHA1 = crypto:hash(sha, Fd_bs),
      file:close(Fd),
      [{Off, SHA1}]
      %%maps:put(Off, SHA1, SHA1_maps_init)
    end, lists:seq(0, Num_thread)).


combine_sha1([], SHA1_BIN) ->
    SHA1_BIN;
combine_sha1([H|T], SHA1_bin) ->
    [{_, RAW_sha1}] = H,
    SHA1_BIN = erlang:iolist_to_binary([SHA1_bin,RAW_sha1]),
    %%SHA1_BIN = erlang:iolist_to_binary([SHA1_bin,maps:values(H)]),
    combine_sha1(T, SHA1_BIN).

urlsafe_base64_encode(Data) ->
    binary:bin_to_list(base64url:encode_mime(Data)).


urlsafe_base64_decode(Data) ->
    binary:bin_to_list(base64url:decode(Data)).