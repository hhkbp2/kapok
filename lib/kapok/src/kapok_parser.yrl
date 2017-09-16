%%
Header "%% THIS FILE IS AUTO-GENERATED BY YECC. "
"%% DO NOT EDIT UNLESS YOU ARE SURE THAT YOU KNOW WHAT YOU ARE DOING.".

Nonterminals
    grammar
    expression expression_list expressions
    number signed_number keyword_expr atom_expr
    bitstring_arg commas_bitstring_arg bitstring_arg_list bitstring_args bitstring_container
    quote_expr backquote_expr unquote_expr unquote_splicing_expr
    value container_value comma_container_value container_value_list container_values
    open_paren close_paren open_bracket close_bracket list_container cons_list
    open_curly close_curly tuple_container
    paired_comma_container_values paired_container_value_list paired_container_values
    unpaired_container_value_list unpaired_container_values open_bang_curly map_container
    open_percent_curly set_container
    dot_op dot_identifier dot_identifier_part
    .

Terminals
    hex_number octal_number n_base_number char_number integer float '+' '-'
    binary_string list_string identifier '.'
    keyword keyword_safe keyword_unsafe atom atom_safe atom_unsafe
    '(' ')' '[' ']' '{' '%{' '#{' '}'  '<<' '>>' ','
    unquote_splicing backquote quote unquote keyword_as keyword_optional keyword_rest keyword_key cons
    .

Rootsymbol grammar.

%% MAIN FLOW OF EXPRESSIONS

grammar -> expressions : '$1'.
grammar -> '$empty' : nil.

% expression as represented in list format
expression -> value : '$1'.

expression_list -> expression : ['$1'].
expression_list -> expression_list expression : ['$2' | '$1'].

expressions -> expression_list : lists:reverse('$1').

%% Value

%% Literals
%% number
number      -> hex_number : build_number('$1').
number      -> octal_number : build_number('$1').
number      -> n_base_number : build_number('$1').
number      -> char_number : build_number('$1').
number      -> integer : build_number('$1').
number      -> float : build_number('$1').

value       -> number : '$1'.
value       -> signed_number : '$1'.
%% keyword
value       -> keyword_expr : '$1'.
%% atom
value       -> atom_expr : '$1'.
%% identifier
value       -> identifier : '$1'.
value       -> dot_identifier : '$1'.
%% function argument keywords
value       -> keyword_optional : '$1'.
value       -> keyword_rest : '$1'.
value       -> keyword_key : '$1'.
%% macro syntax
value       -> quote_expr : '$1'.
value       -> backquote_expr : '$1'.
value       -> unquote_expr : '$1'.
value       -> unquote_splicing_expr : '$1'.
%% strings
value       -> binary_string : '$1'.
value       -> list_string : '$1'.
%% containers
value       -> bitstring_container : '$1'.
value       -> list_container : '$1'.
value       -> cons_list: '$1'.
value       -> tuple_container : '$1'.
value       -> map_container : '$1'.
value       -> set_container : '$1'.

%% signed number
signed_number    -> '+' : build_signed_number('$1').
signed_number    -> '-' : build_signed_number('$1').

%% keyword
keyword_expr   -> keyword : build_keyword_atom('$1').
keyword_expr   -> keyword_safe : build_quoted_keyword_atom('$1', true).
keyword_expr   -> keyword_unsafe : build_quoted_keyword_atom('$1', false).

%% atom
atom_expr      -> atom : build_keyword_atom('$1').
atom_expr      -> atom_safe : build_quoted_keyword_atom('$1', true).
atom_expr      -> atom_unsafe : build_quoted_keyword_atom('$1', false).

%% identifier
dot_op         -> '.' : '$1'.

dot_identifier_part -> atom_expr : '$1'.
dot_identifier_part -> identifier : '$1'.
dot_identifier -> dot_identifier_part dot_op dot_identifier_part : build_dot('$2', '$1', '$3').
dot_identifier -> dot_identifier dot_op dot_identifier_part : build_dot('$2', '$1', '$3').

%% Macro syntaxs
quote_expr            -> quote value : build_quote('$1', '$2').
backquote_expr        -> backquote value : build_backquote('$1', '$2').
unquote_expr          -> unquote value : build_unquote('$1', '$2').
unquote_splicing_expr -> unquote_splicing list_container : build_unquote_splicing('$1', '$2').
unquote_splicing_expr -> unquote_splicing identifier : build_unquote_splicing('$1', '$2').

%%% Containers

%% Bitstring

bitstring_arg        -> number : build_bitstring_element('$1').
bitstring_arg        -> list_container : '$1'.
commas_bitstring_arg -> bitstring_arg  : '$1'.
commas_bitstring_arg -> ',' bitstring_arg  : '$2'.
bitstring_arg_list   -> bitstring_arg : ['$1'].
bitstring_arg_list   -> bitstring_arg_list commas_bitstring_arg : ['$2' | '$1'].

bitstring_args      -> bitstring_arg_list : lists:reverse('$1').

bitstring_container -> '<<' '>>' : build_bitstring('$1', []).
bitstring_container -> '<<' bitstring_args '>>' : build_bitstring('$1', '$2').
bitstring_container -> '<<' list_string '>>' : build_bitstring('$1', '$2').
bitstring_container -> '<<' binary_string '>>' : build_bitstring('$1', '$2').

%% List

container_value -> value: '$1'.
container_value -> value keyword_as identifier: build_bind('$2', '$1', '$3').

comma_container_value -> container_value : '$1'.
comma_container_value -> ',' container_value : '$2'.

container_value_list  -> container_value :  ['$1'].
container_value_list  -> container_value_list comma_container_value : ['$2' | '$1'].

container_values      -> container_value_list : lists:reverse('$1').

open_bracket  -> '[' : '$1'.
close_bracket -> ']' : '$1'.
open_paren  -> '(' : '$1'.
close_paren -> ')' : '$1'.

list_container -> open_bracket close_bracket : build_literal_list('$1', []).
list_container -> open_bracket container_values close_bracket : build_literal_list('$1', '$2').
list_container -> open_paren close_paren : build_list('$1', []).
list_container -> open_paren container_values close_paren: build_list('$1', '$2').

cons_list -> open_bracket container_values cons value close_bracket : build_cons_list('$3', '$2', '$4').
cons_list -> open_paren container_values cons value close_paren : build_cons_list('$3', '$2', '$4').

%% Tuple
open_curly   -> '{' : '$1'.
close_curly  -> '}' : '$1'.

tuple_container -> open_curly close_curly : build_tuple('$1', []).
tuple_container -> open_curly container_values close_curly: build_tuple('$1', '$2').

%% Map

paired_comma_container_values -> comma_container_value comma_container_value : ['$2', '$1'].

paired_container_value_list -> container_value comma_container_value : ['$2', '$1'].
paired_container_value_list -> paired_container_value_list paired_comma_container_values : lists:append('$2', '$1').

paired_container_values   -> paired_container_value_list : lists:reverse('$1').

unpaired_container_value_list -> container_value : ['$1'].
unpaired_container_value_list -> paired_container_value_list comma_container_value : ['$2' | '$1'].

unpaired_container_values -> unpaired_container_value_list : lists:reverse('$1').

open_bang_curly -> '#{' : '$1'.

map_container -> open_bang_curly close_curly : build_map('$1', []).
map_container -> open_bang_curly paired_container_values close_curly : build_map('$1', '$2').
map_container -> open_bang_curly unpaired_container_values close_curly : throw_unpaired_map('$1').

%% Set

open_percent_curly -> '%{' : '$1'.

set_container -> open_percent_curly close_curly : build_set('$1', []).
set_container -> open_percent_curly container_values close_curly : build_set('$1', '$2').

Erlang code.

-import(kapok_scanner, [token_category/1,
                        token_meta/1,
                        token_symbol/1]).
-export([dot_fullname/1]).
-include("kapok.hrl").

%% Build token

build_number(Token) ->
  {number, token_meta(Token), token_symbol(Token)}.

build_signed_number(Sign) ->
  {token_category(Sign), token_meta(Sign), build_number(token_symbol(Sign))}.

build_keyword_atom(Token) ->
  {token_category(Token), token_meta(Token), token_symbol(Token)}.

build_quoted_keyword_atom(Token, Safe) ->
  Op = binary_to_atom_op(Safe),
  C = token_category(Token),
  [Type, _] = string:tokens(atom_to_list(C), "_"),
  {list_to_atom(Type), token_meta(Token), erlang:Op(token_symbol(Token), utf8)}.

binary_to_atom_op(true)  -> binary_to_existing_atom;
binary_to_atom_op(false) -> binary_to_atom.

build_dot(Dot, {Category, _, Id} = _Left, Right) when ?is_local_id(Category) ->
  {dot, token_meta(Dot), {Id, token_symbol(Right)}};
build_dot(Dot, {dot, _, _} = Left, Right) ->
  {dot, token_meta(Dot), {dot_fullname(Left), token_symbol(Right)}}.

build_bitstring_element(Token) ->
  Symbol = token_symbol(Token),
  E = case is_integer(Symbol) of
        true -> Symbol;
        false -> throw_invalid_bitstring_element(Token)
      end,
  {list, token_meta(Token), [E]}.

build_bitstring(Marker, Args) ->
  {bitstring, token_meta(Marker), Args}.

build_quote(Marker, Arg) ->
  {quote, token_meta(Marker), Arg}.

build_backquote(Marker, Arg) ->
  {backquote, token_meta(Marker), Arg}.

build_unquote(Marker, Arg) ->
  {unquote, token_meta(Marker), Arg}.

build_unquote_splicing(Marker, Arg) ->
  {unquote_splicing, token_meta(Marker), Arg}.

build_bind(Keyword, Value, Id) ->
  {bind, token_meta(Keyword), {Value, Id}}.

build_literal_list(Marker, Args) ->
  {literal_list, token_meta(Marker), Args}.

build_list(Marker, Args) ->
  {list, token_meta(Marker), Args}.

build_cons_list(Marker, Head, Tail) ->
  {cons_list, token_meta(Marker), {Head, Tail}}.

build_tuple(Marker, Args) ->
  {tuple, token_meta(Marker), Args}.

build_map(Marker, Args) ->
  {map, token_meta(Marker), Args}.

build_set(Marker, Args) ->
  {set, token_meta(Marker), Args}.

%% Helper Functions

dot_fullname({dot, _, {Left, Right}}) ->
  list_to_atom(string:join([atom_to_list(Left), atom_to_list(Right)], ".")).

%% Errors
throw(Line, Error, Token) ->
  throw({error, {Line, ?MODULE, [Error, Token]}}).

throw_unpaired_map(Marker) ->
  throw(?line(token_meta(Marker)), "unpaired values in map", token_symbol(Marker)).

throw_invalid_bitstring_element(Token) ->
  throw(?line(token_meta(Token)), "invalid bitstring element", token_symbol(Token)).
