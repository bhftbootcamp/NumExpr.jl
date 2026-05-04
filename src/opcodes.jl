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

opcode(::Func{:sqrt})::UInt8 = OP_SQRT
opcode(::Func{:abs})::UInt8  = OP_ABS
opcode(::Func{:sin})::UInt8  = OP_SIN
opcode(::Func{:cos})::UInt8  = OP_COS
opcode(::Func{:atan})::UInt8 = OP_ATAN
opcode(::Func{:exp})::UInt8  = OP_EXP
opcode(::Func{:log})::UInt8  = OP_LOG
