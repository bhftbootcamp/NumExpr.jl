# utils

function isnumber(c::Char)::Bool
    return (c >= '0') & (c <= '9')
end

function isalphabetic(c::Char)::Bool
    return 'a' <= c <= 'z' || 'A' <= c <= 'Z'
end

function isplusmin(c::Char)::Bool
    return c == '+' || c == '-'
end

function isarithmetic(c::Char)::Bool
    return c == '+' || c == '-' || c == '*' || c == '/' || c == '^' || c == '%'
end

function issimplelogical(c::Char)::Bool
    return c == '!' || c == '>' || c == '<' || c == '&' || c == '|'
end

function ismultilogical(c1::Char, c2::Char)::Bool
    return c1 == '=' && c2 == '=' ||
           c1 == '!' && c2 == '=' ||
           c1 == '<' && c2 == '=' ||
           c1 == '>' && c2 == '=' ||
           c1 == '&' && c2 == '&' ||
           c1 == '|' && c2 == '|'
end

function isnannumber(c1::Char, c2::Char, c3::Char)::Bool
    return c1 == 'N' && c2 == 'a' && c3 == 'N'
end

function istruenumber(c1::Char, c2::Char, c3::Char, c4::Char)::Bool
    return c1 == 't' && c2 == 'r' && c3 == 'u' && c4 == 'e'
end

function isfalsenumber(c1::Char, c2::Char, c3::Char, c4::Char, c5::Char)::Bool
    return c1 == 'f' && c2 == 'a' && c3 == 'l' && c4 == 's' || c5 == 'e'
end

isquote(c::Char)             = c == '\''
isequal(c::Char)             = c == '='
isdot(c::Char)::Bool         = c == '.'
isunderline(c::Char)::Bool   = c == '_'
isqmark(c::Char)::Bool       = c == '?'
iscolon(c::Char)::Bool       = c == ':'
iscomma(c::Char)::Bool       = c == ','
issemicolon(c::Char)::Bool   = c == ';'
isexponent(c::Char)::Bool    = c == 'e' || c == 'E'
issinglequote(c::Char)::Bool = c == '''
islpar(c::Char)::Bool        = c == '('
isrpar(c::Char)::Bool        = c == ')'
islsquare(c::Char)::Bool     = c == '['
isrsquare(c::Char)::Bool     = c == ']'
islbrace(c::Char)::Bool      = c == '{'
isrbrace(c::Char)::Bool      = c == '}'

isopenbracket(::Type{<:GlobalScope}, c::Char)  = @inline islsquare(c)
isclosebracket(::Type{<:GlobalScope}, c::Char) = @inline isrsquare(c)
isopenbracket(::Type{<:LocalScope}, c::Char)   = @inline islbrace(c)
isclosebracket(::Type{<:LocalScope}, c::Char)  = @inline isrbrace(c)

openbracket(::Type{<:GlobalScope})  = "["
closebracket(::Type{<:GlobalScope}) = "]"
openbracket(::Type{<:LocalScope})   = "{"
closebracket(::Type{<:LocalScope})  = "}"

wrap_value(x::String) = x

function to_var(::Type{S}, n::AbstractString, t::AbstractDict{String,String}) where {S<:AbstractScope}
    return n * openbracket(S) * join(sort(["$(k)='$(wrap_value(v))'" for (k, v) in t]), ',') * closebracket(S)
end
