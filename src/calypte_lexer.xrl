Definitions.

D          = [0-9]
FUN_BEGIN  = [a-z_?]+\(
WHITESPACE = (\s|\t|\n|\r)
COMMENTS   = #.*
CODEWORDS  = (isa|is|and|or|not|in|default|true|false)
OP         = (<=|<|!=|==|>=|>|=~)
MATH       = (\+|\*|/|%)
Labels     = [A-Za-z_][0-9a-zA-Z_/-]*

Rules.

{D}{D}{D}{D}-{D}{D}-{D}{D}(T{D}{D}:{D}{D}:{D}{D})? :
                        {token, {datetime, TokenLine, TokenChars}}.
{CODEWORDS}           : {token, {list_to_atom(TokenChars), TokenLine}}.
{OP}                  : {token, {op, TokenLine, list_to_atom(TokenChars)}}.
\$                    : {token, {'$', TokenLine}}.
@                     : {token, {'@', TokenLine}}.
=                     : {token, {'=', TokenLine}}.
-                     : {token, {'-', TokenLine}}.
\.                    : {token, {'.', TokenLine}}.
\?                    : {token, {'?', TokenLine}}.
{MATH}                : {token, {list_to_atom(TokenChars), TokenLine}}.
{FUNC_BEGIN}          : {token, {func_begin, TokenLine, list_to_binary(TokenChars)}}.
{D}+                  : {token, {integer,TokenLine,list_to_integer(TokenChars)}}.
{D}+\.{D}+((E|e)(\+|\-)?{D}+)? :
                        {token, {float, TokenLine, list_to_float(TokenChars)}}.
{Labels}              : {token, {label, TokenLine, list_to_binary(TokenChars)}}.
"(\\\^.|\\.|[^"])*"   : S = lists:sublist(TokenChars, 2, TokenLen - 2),
                        {token, {string, TokenLine, 'Elixir.String.Chars':to_string(S)}}.
[]()[,]               : {token, {list_to_atom(TokenChars), TokenLine}}.
{COMMENTS}+           : {token, {'#', TokenLine, list_to_binary(TokenChars)}}.
{WHITESPACE}+         : skip_token.

Erlang code.