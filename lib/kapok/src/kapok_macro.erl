-module(kapok_macro).
-export(['__info__'/1,
         expand/2,
         expand_n/3,
         expand_1/2,
         append/2,
         'list*'/2]).
-import(kapok_scanner, [token_meta/1, token_text/1]).
-import(kapok_config, [get_compiler_opt/1]).
-include("kapok.hrl").

'__info__'(functions) ->
  [];
'__info__'(macros) ->
  [{append, 2, 'normal'},
   {'list*', 2, 'normal'}].

%% Expending macros.

expand(List, Ctx) when is_list(List) ->
  lists:mapfoldl(fun expand/2, Ctx, List);
expand(Ast, Ctx) ->
  {EAst, ECtx, Expanded} = expand_1(Ast, Ctx),
  case Expanded of
    true -> expand(EAst, ECtx);
    false -> {EAst, ECtx}
  end.

expand_n(Ast, Ctx, N) when N == 0 ->
  {Ast, Ctx};
expand_n(Ast, Ctx, N) when N > 0 ->
  {EAst, ECtx, Expanded} = expand_1(Ast, Ctx),
  case Expanded of
    true -> expand_n(EAst, ECtx, N-1);
    false -> {EAst, ECtx}
  end.

%% a list of ast
expand_1(List, Ctx) when is_list(List) ->
  expand_list(List, Ctx);

%% list
expand_1({list, Meta, [{identifier, _, Id} = Ident | T]}, Ctx) when ?is_def(Id) ->
  %% TODO move defs into `core' as predefined macros
  {ET, ECtx, Expanded} = expand_1(T, Ctx),
  {{list, Meta, [Ident | ET]}, ECtx, Expanded};
expand_1({list, Meta, [{identifier, _, Id} | T]} = Ast, Ctx) ->
  Arity = length(T),
  {R, Ctx1} = kapok_dispatch:find_local_macro(Meta, {Id, Arity}, Ctx),
  case R of
    {F, A, P} ->
      %% to call a previously defined macro in the namespace
      Namespace = ?m(Ctx, namespace),
      kapok_code:load_ns(Namespace, Ctx),
      {ok, Module} = kapok_code:get_module(Namespace),
      NewArgs = kapok_trans:construct_new_args('expand', Arity, A, P, T),
      {EAst, ECtx} = expand_macro_named(Meta, Module, F, A, NewArgs, Ctx),
      {EAst, ECtx, true};
    {M, F, A, P} ->
      %% to call a macro defined in another module
      NewArgs = kapok_trans:construct_new_args('expand', Arity, A, P, T),
      {EAst, ECtx} = expand_macro_named(Meta, M, F, A, NewArgs, Ctx1),
      {EAst, ECtx, true};
    false ->
      expand_list(Ast, Ctx)
  end;
expand_1({list, Meta, [{dot, _, {Module, Fun}} | T]} = Ast, Ctx) ->
  Arity = length(T),
  {R, Ctx1} = kapok_dispatch:find_remote_macro(Meta, Module, {Fun, Arity}, Ctx),
  case R of
    {M, F, A, P} ->
      NewArgs = kapok_trans:construct_new_args('expand', Arity, A, P, T),
      {EAst, ECtx} = expand_macro_named(Meta, M, F, A, NewArgs, Ctx1),
      {EAst, ECtx, true};
    false ->
      expand_list(Ast, Ctx1)
  end;
%% list and literal list
expand_1({Category, _, _} = Ast, Ctx) when ?is_list(Category) ->
  expand_list(Ast, Ctx);
%% cons_list
expand_1({Category, Meta, {Head, Tail}}, Ctx) when ?is_cons_list(Category) ->
  {EHead, ECtx1, Expanded1} = expand_1(Head, Ctx),
  {ETail, ECtx2, Expanded2} = expand_1(Tail, ECtx1),
  {{Category, Meta, {EHead, ETail}}, ECtx2, Expanded1 orelse Expanded2};
%% non-list containers
expand_1({Category, Meta, Args}, Ctx)
    when Category == 'bitstring', is_list(Args);
         Category == 'tuple';
         Category == 'map';
         Category == 'set' ->
  {EArgs, ECtx, Expanded} = expand_1(Args, Ctx),
  {{Category, Meta, EArgs}, ECtx, Expanded};

%% macro special forms

%% quote
expand_1({Category, Meta, Arg}, Ctx) when Category =:= quote ->
  {EArg, ECtx, Expanded} = expand_1(Arg, Ctx),
  {{Category, Meta, EArg}, ECtx, Expanded};

%% backquote, unquote, unquote_splicing
expand_1({Category, _Meta, _Arg} = Ast, Ctx) when Category =:= quote;
                                          Category =:= backquote;
                                          Category =:= unquote;
                                          Category =:= unquote_splicing ->
  %% don't expand backquote since its evaluation is meant to be delayed.
  {Ast, Ctx, false};

%% atom
expand_1(Ast, Ctx) ->
  {Ast, Ctx, false}.

expand_list({Category, Meta, List}, Ctx) when ?is_list(Category), is_list(List) ->
  {EList, ECtx, Expanded} = expand_list(List, Ctx),
  {{Category, Meta, EList}, ECtx, Expanded};
expand_list(List, Ctx) when is_list(List) ->
  {EList, {ECtx, Expanded}} = lists:mapfoldl(fun(Ast, {Ctx1, Expanded1}) ->
                                                 {EAst, ECtx1, Expanded2} = expand_1(Ast, Ctx1),
                                                 {EAst, {ECtx1, Expanded2 orelse Expanded1}}
                                             end,
                                             {Ctx, false},
                                             List),
  {EList, ECtx, Expanded}.


%% macro expansion helper functions

expand_macro_named(Meta, Receiver, Name, Arity, Args, Ctx) ->
  case get_compiler_opt(debug) of
    true -> io:format("macro ~s:~s/~B args:~n~p~n", [Receiver, Name, Arity, Args]);
    false -> ok
  end,
  Fun = fun Receiver:Name/Arity,
  Result = expand_macro_fun(Meta, Fun, Receiver, Name, Args, Ctx),
  case get_compiler_opt(debug) of
    true -> io:format("macro ~s:~s/~B result:~n~p~n", [Receiver, Name, Arity, Result]);
    false -> ok
  end,
  {Result, Ctx}.

expand_macro_fun(Meta, Fun, Receiver, Name, Args, Ctx) ->
  %% TODO push  meta, name, ctx into process cache
  %% and then pop it when macro finishs.
  Line = ?line(Meta),
  try
    apply(Fun, Args)
  catch
    Kind:Reason ->
      Arity = length(Args),
      MFA = {Receiver, Name, Arity},
      Info = [{Receiver, Name, Arity, [{file, "expand macro"}]}, caller(Line, Ctx)],
      erlang:raise(Kind, Reason, prune_stacktrace(erlang:get_stacktrace(), MFA, Info, nil))
  end.

caller(Line, #{namespace := Namespace} = Ctx) ->
  {Namespace, undefined, undefined, location(Line, Ctx)}.

location(Line, Ctx) ->
  [{file, kapok_utils:characters_to_list(?m(Ctx, file))},
   {line, Line}].

%% We've reached the invoked macro, skip it with the rest
prune_stacktrace([{M, F, A, _} | _], {M, F, A}, Info, _Ctx) ->
  Info;
%% We've reached the expand/dispatch internals, skip it with the rest
prune_stacktrace([{Mod, _, _, _} | _], _MFA, Info, _Ctx)
    when Mod == kapok_dispatch; Mod == kapok_macro ->
  Info;
prune_stacktrace([H|T], MFA, Info, Ctx) ->
  [H|prune_stacktrace(T, MFA, Info, Ctx)];
prune_stacktrace([], _MFA, Info, _Ctx) ->
  Info.


%% List building after evaluating macros.

append(Ast1, Ast2) ->
  Ctx = kapok_ctx:ctx_for_eval([{line, ?LINE}, {file, kapok_utils:to_binary(?FILE)}]),
  {EAst1, _} = expand(Ast1, Ctx),
  {EAst2, _} = expand(Ast2, Ctx),
  RAst = do_append(EAst1, EAst2),
  case get_compiler_opt(debug) of
    true -> io:format("--- call kapok_macro:append() ---~nAst1: ~p~nAst2: ~p~nresult: ~p~n===~n",
                      [Ast1, Ast2, RAst]);
    false -> ok
  end,
  RAst.

do_append({Category1, Meta1, List1}, {Category2, _, List2})
    when ?is_list(Category1), ?is_list(Category2), is_list(List1), is_list(List2) ->
  {Category2, Meta1, lists:append(List1, List2)};
do_append(List1, {Category2, Meta2, List2})
    when ?is_list(Category2), is_list(List1), is_list(List2) ->
  {Category2, Meta2, lists:append(List1, List2)};
do_append(Ast1, Ast2) ->
  kapok_error:compile_error(token_meta(Ast1),
                            <<"in macro:append()">>,
                            "invalid arguments, (~s, ~s)",
                            [token_text(Ast1), token_text(Ast2)]).

'list*'(Ast1, Ast2) ->
  Ctx = kapok_ctx:ctx_for_eval([{line, ?LINE}, {file, kapok_utils:to_binary(?FILE)}]),
  {EAst1, _} = expand(Ast1, Ctx),
  {EAst2, _} = expand(Ast2, Ctx),
  RAst = 'do_list*'(EAst1, EAst2),
  case get_compiler_opt(debug) of
    true -> io:format("--- call kapok_macro:list*() ---~nAst1: ~p~nAst2: ~p~nresult: ~p~n===~n",
                      [Ast1, Ast2, RAst]);
    false -> ok
  end,
  RAst.

'do_list*'({Category1, Meta1, List1}, {Category2, _Meta2, List2})
    when ?is_list(Category1), is_list(List1), ?is_list(Category2), is_list(List2) ->
  {Category1, Meta1, lists:append(List1, List2)};
'do_list*'(Ast1, Ast2) ->
  kapok_error:compile_error(token_meta(Ast1),
                            <<"in macro:list*()">>,
                            "invalid arguments: (~s, ~s)",
                            [token_text(Ast1), token_text(Ast2)]).
