Nonterminals root meta_pairs meta_pair expression expressions left_match
             type_def basic_expr assignment assertion list function arg_list var attribute math
             uminus_math data data_basic data_arg data_list value_number number boolean.
Terminals '@' '[' ']' '(' ')' '$' '\'' '=' '-' '+' '*' '/' '%' 'true' 'false' ',' isa is func_begin op and
          or not in default label datetime integer float string.
Rootsymbol root.

Left      30 ','.
Right     50 '='.
Left      70 or.
Left      80 and.
Unary     90 'not'.
Left     100 op.              %% <, >, <=, >=, ==, ===, !=, !==
Left     120 in.
Left     150 '+'.
Left     150 '-'.
Left     160 '*'.
Left     160 '/'.
Left     160 '%'.
Unary    200 uminus_math.

root -> meta_pairs                                     : '$1'.
root -> expressions                                    : '$1'.

meta_pairs -> meta_pair                                : ['$1'].
meta_pairs -> meta_pair meta_pairs                     : ['$1' | '$2'].

meta_pair -> '@' label expressions                     : {extract_token('$2'), '$3'}.

expressions -> expression                              : ['$1'].
expressions -> expression expressions                  : ['$1' | '$2'].

expression -> var label type_def                       : relation('$1', '$2', '$3').
expression -> type_def                                 : '$1'.
expression -> assignment                               : '$1'.
expression -> assertion                                : '$1'.
expression -> attribute 'default' basic_expr           : expr('$2', '$1', '$3').
expression -> left_match                               : '$1'.

type_def -> var 'isa' label                            : type_def('$1', '$3').

assignment -> left_match 'is' attribute                : expr('$2', '$1', '$3').
assignment -> attribute '=' left_match                 : expr('$2', '$1', '$3').

assertion -> left_match op left_match                  : expr('$2', '$1', '$3').

left_match -> function                                 : '$1'.
left_match -> basic_expr                               : '$1'.

basic_expr -> math                                     : '$1'.
basic_expr -> data                                     : '$1'.

function -> func_begin ')'                             : function('$1', []).
function -> func_begin arg_list ')'                    : function('$1', '$2').

arg_list -> basic_expr                                 : ['$1'].
arg_list -> basic_expr ',' arg_list                    : ['$1' | '$3'].

math -> attribute                                      : '$1'.
math -> number                                         : value('$1').
math -> uminus_math                                    : '$1'.
math -> math '+' math                                  : expr('$2', '$1', '$3').
math -> math '-' math                                  : expr('$2', '$1', '$3').
math -> math '*' math                                  : expr('$2', '$1', '$3').
math -> math '/' math                                  : expr('$2', '$1', '$3').
math -> math '%' math                                  : expr('$2', '$1', '$3').
math -> '(' math ')'                                   : '$2'.

uminus_math -> '-' math                                : expr('$1', '$2', 'nil').

var -> '$' label                                       : var('$2', '$2', nil).

attribute -> '$' label '\'' label                      : var('$2', '$2', '$4').
attribute -> label                                     : var('$1', 'nil', '$1').

data -> '[' ']'                                        : [].
data -> '[' data_list ']'                              : '$2'.
data -> data_basic                                     : '$1'.

data_basic -> datetime                                 : value('$1').
data_basic -> string                                   : value(string('$1')).
data_basic -> boolean                                  : value('$1').

data_list -> data_arg                                  : ['$1'].
data_list -> data_arg ',' data_list                    : ['$1' | '$3'].

data_arg -> value_number                               : '$1'.
data_arg -> data_basic                                 : '$1'.

value_number -> '-' number                             : negative_number_value('$2').
value_number -> number                                 : value('$1').

number -> integer                                      : '$1'.
number -> float                                        : '$1'.

boolean -> 'true'                                      : boolean('$1').
boolean -> 'false'                                     : boolean('$1').

Erlang code.

extract_token({_Token, _Line, Value}) -> Value;
extract_token({Token, _Line}) -> Token.

% Ast transformation
expr(Token, Left, Right) -> expr(extract_token(Token), Token, Left, Right).
expr('-', _, #{type := integer, val := Value} = Expr, nil) ->
    % Optimization, which move - to a static numbers to match behaviour of `negative` numbers
    % inside of negative elements inside of lists
    Expr#{val := Value * -1};
expr(Type, Token, Left, Right) ->
    ast('Elixir.Calypte.Ast.Expr', Token, [{type, Type}, {left, Left}, {right, Right}]).

type_def(#{} = Var, Type) ->
    Var#{type := extract_token(Type)}.

relation(From, Edge, To) ->
    ast('Elixir.Calypte.Ast.Relation', Edge, [{from, From}, {edge, extract_token(Edge)}, {to, To}]).

function(Token, Args) ->
    Function = extract_token(Token),
    Name = binary:part(Function, 0, byte_size(Function) - 1),
    ast('Elixir.Calypte.Ast.Function', Token, [{name, Name}, {args, Args}]).

var(Token, {_, _, Name} = Token, Attr) -> var(Token, Name, Attr);
var(Token, Name, {_, _, Attr}) -> var(Token, Name, Attr);
var(Token, Name, Attr) ->
    ast('Elixir.Calypte.Ast.Var', Token, [{name, Name}, {attr, Attr}]).

value({Type, _Line, Value} = Token) ->
    ast('Elixir.Calypte.Ast.Value', Token, [{type, Type}, {val, Value}]).

ast(Struct, {Tag, Line}, Opts) -> ast(Struct, {Tag, Line, nil}, Opts);
ast(Struct, {_, Line, _}, Opts) -> 'Elixir.Kernel':struct(Struct, [{line, Line} | Opts]).

string({string, Line, Value}) ->
    {string, Line, binary:replace(Value, <<"\\\"">>, <<"\"">>, [global])}.

boolean({Bool, Line}) when is_boolean(Bool) -> {boolean, Line, Bool}.

negative_number_value({Type, Line, Number}) -> value({Type, Line, Number * -1}).