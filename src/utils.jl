# utils

#__ char predicates

isnumber(c::Char)::Bool     = (c >= '0') & (c <= '9')
isalphabetic(c::Char)::Bool = ('a' <= c <= 'z') || ('A' <= c <= 'Z')
isplusmin(c::Char)::Bool    = c == '+' || c == '-'
isexponent(c::Char)::Bool   = c == 'e' || c == 'E'
isdot(c::Char)::Bool        = c == '.'
isunderline(c::Char)::Bool  = c == '_'
iscomma(c::Char)::Bool      = c == ','
isquote(c::Char)::Bool      = c == '\''
iseqsign(c::Char)::Bool     = c == '='

islpar(c::Char)::Bool    = c == '('
isrpar(c::Char)::Bool    = c == ')'
islsquare(c::Char)::Bool = c == '['
isrsquare(c::Char)::Bool = c == ']'
islbrace(c::Char)::Bool  = c == '{'
isrbrace(c::Char)::Bool  = c == '}'

function isarithmetic(c::Char)::Bool
    return c == '+' || c == '-' || c == '*' || c == '/' || c == '^' || c == '%'
end

function issimplelogical(c::Char)::Bool
    return c == '>' || c == '<'
end

function ismultilogical(c1::Char, c2::Char)::Bool
    return c1 == '=' && c2 == '=' ||
           c1 == '!' && c2 == '=' ||
           c1 == '<' && c2 == '=' ||
           c1 == '>' && c2 == '=' ||
           c1 == '&' && c2 == '&' ||
           c1 == '|' && c2 == '|'
end

#__ keyword predicates

isnannumber(c1::Char, c2::Char, c3::Char)::Bool = c1 == 'N' && c2 == 'a' && c3 == 'N'

function istruenumber(c1::Char, c2::Char, c3::Char, c4::Char)::Bool
    return c1 == 't' && c2 == 'r' && c3 == 'u' && c4 == 'e'
end

function isfalsenumber(c1::Char, c2::Char, c3::Char, c4::Char, c5::Char)::Bool
    return c1 == 'f' && c2 == 'a' && c3 == 'l' && c4 == 's' && c5 == 'e'
end

#__ scope brackets

isopenbracket(::Type{<:GlobalScope}, c::Char)::Bool  = islsquare(c)
isclosebracket(::Type{<:GlobalScope}, c::Char)::Bool = isrsquare(c)
isopenbracket(::Type{<:LocalScope}, c::Char)::Bool   = islbrace(c)
isclosebracket(::Type{<:LocalScope}, c::Char)::Bool  = isrbrace(c)

openbracket(::Type{<:GlobalScope})::String  = "["
closebracket(::Type{<:GlobalScope})::String = "]"
openbracket(::Type{<:LocalScope})::String   = "{"
closebracket(::Type{<:LocalScope})::String  = "}"

#__ variable formatting

function to_var(::Type{S}, n::AbstractString, t::AbstractDict{String,String})::String where {S<:AbstractScope}
    pairs = sort(["$(k)='$(v)'" for (k, v) in t])
    return n * openbracket(S) * join(pairs, ',') * closebracket(S)
end
