# opcodes

#__ load

const OP_LOAD_CONST = 0x01
const OP_LOAD_VAR   = 0x02
const OP_LOAD_TRUE  = 0x03
const OP_LOAD_FALSE = 0x04
const OP_LOAD_NAN   = 0x05

#__ arithmetic

const OP_ADD = 0x10
const OP_SUB = 0x11
const OP_MUL = 0x12
const OP_DIV = 0x13
const OP_POW = 0x14
const OP_MOD = 0x15
const OP_NEG = 0x16

#__ comparison

const OP_GT = 0x20
const OP_LT = 0x21
const OP_GE = 0x22
const OP_LE = 0x23
const OP_EQ = 0x24
const OP_NE = 0x25

#__ logic

const OP_AND = 0x30
const OP_OR  = 0x31

#__ function

const OP_SQRT = 0x40
const OP_ABS  = 0x41
const OP_SIN  = 0x42
const OP_COS  = 0x43
const OP_ATAN = 0x44
const OP_EXP  = 0x45
const OP_LOG  = 0x46

#__ unary predicates

const OP_ISNAN  = 0x47
const OP_NOT    = 0x48
const OP_ISZERO = 0x49
const OP_ISONE  = 0x4A
const OP_FLOOR  = 0x4B
const OP_CEIL   = 0x4C
const OP_TG     = 0x4D
const OP_CTG    = 0x4E

#__ binary / ternary functions

const OP_MAX2   = 0x50
const OP_MIN2   = 0x51
const OP_IFELSE = 0x52
const OP_GET    = 0x53
const OP_ROUND  = 0x54
const OP_ISLESS = 0x55
const OP_DIV_INT = 0x56
const OP_MEAN    = 0x57

#__ opcode dispatch

opcode(::Arithmetic{:+})::UInt8  = OP_ADD
opcode(::Arithmetic{:-})::UInt8  = OP_SUB
opcode(::Arithmetic{:*})::UInt8  = OP_MUL
opcode(::Arithmetic{:/})::UInt8  = OP_DIV
opcode(::Arithmetic{:^})::UInt8  = OP_POW
opcode(::Arithmetic{:%})::UInt8  = OP_MOD

opcode(::Logic{:>})::UInt8   = OP_GT
opcode(::Logic{:<})::UInt8   = OP_LT
opcode(::Logic{:>=})::UInt8  = OP_GE
opcode(::Logic{:<=})::UInt8  = OP_LE
opcode(::Logic{:(==)})::UInt8 = OP_EQ
opcode(::Logic{:!=})::UInt8  = OP_NE

opcode(::Logic{:&&})::UInt8  = OP_AND
opcode(::Logic{:||})::UInt8  = OP_OR

opcode(::Func{:sqrt})::UInt8  = OP_SQRT
opcode(::Func{:abs})::UInt8   = OP_ABS
opcode(::Func{:sin})::UInt8   = OP_SIN
opcode(::Func{:cos})::UInt8   = OP_COS
opcode(::Func{:atan})::UInt8  = OP_ATAN
opcode(::Func{:exp})::UInt8   = OP_EXP
opcode(::Func{:log})::UInt8   = OP_LOG

opcode(::Func{:isnan})::UInt8  = OP_ISNAN
opcode(::Func{:not})::UInt8    = OP_NOT
opcode(::Func{:iszero})::UInt8 = OP_ISZERO
opcode(::Func{:isone})::UInt8  = OP_ISONE
opcode(::Func{:floor})::UInt8  = OP_FLOOR
opcode(::Func{:ceil})::UInt8   = OP_CEIL
opcode(::Func{:tg})::UInt8    = OP_TG
opcode(::Func{:ctg})::UInt8   = OP_CTG

opcode(::Func{:max})::UInt8    = OP_MAX2
opcode(::Func{:min})::UInt8    = OP_MIN2
opcode(::Func{:ifelse})::UInt8 = OP_IFELSE
opcode(::Func{:get})::UInt8    = OP_GET
opcode(::Func{:round})::UInt8  = OP_ROUND
opcode(::Func{:isless})::UInt8 = OP_ISLESS
opcode(::Func{:div})::UInt8    = OP_DIV_INT
opcode(::Func{:mean})::UInt8  = OP_MEAN
