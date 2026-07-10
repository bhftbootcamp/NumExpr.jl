using Test
using Dates
using NumExpr

vectorial(x::NumExpr.NumVal) = [string(x)]
vectorial(x::NumExpr.Variable) = [string(x)]

function vectorial(node::NumExpr.ExprNode)
    return [string(node.head), map(x -> x isa NumExpr.ExprNode ? vectorial(x) : string(x[]), node.args)...]
end

function variables(node::NumExpr.ExprNode)
    outs = Set{NumExpr.Variable}()
    for x in node.args
        if isa(x, NumExpr.Variable)
            push!(outs, x)
        elseif isa(x, NumExpr.ExprNode)
            union!(outs, variables(x))
        end
    end
    return outs
end

@testset verbose = true "NumExpr" begin
    @testset verbose = true "Parse whitespace" begin
        @test vectorial(parse_expr("1")) == ["1.0"]
        @test vectorial(parse_expr("1 ")) == ["1.0"]
        @test vectorial(parse_expr(" 1")) == ["1.0"]
        @test vectorial(parse_expr(" 1 ")) == ["1.0"]
        @test vectorial(parse_expr("  1")) == ["1.0"]
        # test_throws
        @test_throws NumExpr.SyntaxError parse_expr("")
        @test_throws NumExpr.SyntaxError parse_expr(" ")
        @test_throws NumExpr.SyntaxError parse_expr("    ")
    end

    @testset verbose = true "Parse symbols" begin
        @test vectorial(parse_expr("123")) == ["123.0"]
        @test vectorial(parse_expr("1234567890")) == ["1.23456789e9"]
        @test vectorial(parse_expr("a")) == ["a"]
        @test vectorial(parse_expr("abcdefghijklmnopqrstuvwxyz")) == ["abcdefghijklmnopqrstuvwxyz"]
        @test vectorial(parse_expr("A")) == ["A"]
        @test vectorial(parse_expr("ABCDEFGHIJKLMNOPQRSTUVWXYZ")) == ["ABCDEFGHIJKLMNOPQRSTUVWXYZ"]
        # test_throws non-ascii
        @test_throws NumExpr.SyntaxError parse_expr("ф")
        @test_throws NumExpr.SyntaxError parse_expr("α")
        @test_throws NumExpr.SyntaxError parse_expr("фырк")
        @test_throws NumExpr.SyntaxError parse_expr("αβγ")

        # tests for scientific notation
        @test vectorial(parse_expr("1e10")) == ["1.0e10"]
        @test vectorial(parse_expr("2.5E+3")) == ["2500.0"]
        @test vectorial(parse_expr("3.45e-2")) == ["0.0345"]
        @test vectorial(parse_expr("6E4")) == ["60000.0"]
        @test vectorial(parse_expr("7.89e0")) == ["7.89"]

        # test for e edge cases
        @test_throws NumExpr.SyntaxError parse_expr("1e")
        @test_throws NumExpr.SyntaxError parse_expr("2.5E+")
    end

    @testset verbose = true "Parse numbers" begin
        @test vectorial(parse_expr("abc")) == ["abc"]
        @test vectorial(parse_expr("ab123c")) == ["ab123c"]
        @test vectorial(parse_expr("abc123")) == ["abc123"]
    end

    @testset verbose = true "Parse patenthesis" begin
        @test vectorial(parse_expr("(1)")) == ["1.0"]
        @test vectorial(parse_expr("( 1)")) == ["1.0"]
        @test vectorial(parse_expr("(1 )")) == ["1.0"]
        @test vectorial(parse_expr("( 1 )")) == ["1.0"]
        @test vectorial(parse_expr("(( 1) ) ")) == ["1.0"]
        @test vectorial(parse_expr("( (1 )) ")) == ["1.0"]
        # test_throws
        @test_throws NumExpr.SyntaxError parse_expr("(")
        @test_throws NumExpr.SyntaxError parse_expr(")")
        @test_throws NumExpr.SyntaxError parse_expr("(1")
        @test_throws NumExpr.SyntaxError parse_expr("1)")
        @test_throws NumExpr.SyntaxError parse_expr("(()")
        @test_throws NumExpr.SyntaxError parse_expr("((1)")
        @test_throws NumExpr.SyntaxError parse_expr("(1))")
        @test_throws NumExpr.SyntaxError parse_expr(")1")
        @test_throws NumExpr.SyntaxError parse_expr("1(")
        @test_throws NumExpr.SyntaxError parse_expr(")(1)")
        @test_throws NumExpr.SyntaxError parse_expr("(1)(")
    end

    @testset verbose = true "Parse dot" begin
        @test vectorial(parse_expr("1.2")) == ["1.2"]
        @test vectorial(parse_expr("(1.2)")) == ["1.2"]
        @test vectorial(parse_expr("123.123")) == ["123.123"]
        @test vectorial(parse_expr("(123.123)")) == ["123.123"]
        @test vectorial(parse_expr("a")) == ["a"]
        @test vectorial(parse_expr("a.b")) == ["a.b"]
        @test vectorial(parse_expr("abc.abc")) == ["abc.abc"]
        @test vectorial(parse_expr("abc.abc.abc")) == ["abc.abc.abc"]
        @test vectorial(parse_expr("abc.123.abc")) == ["abc.123.abc"]
        @test vectorial(parse_expr("123.")) == ["123.0"]
        @test vectorial(parse_expr("abc.")) == ["abc."]
        # test_throws
        @test_throws NumExpr.SyntaxError parse_expr(".123")
        @test_throws NumExpr.SyntaxError parse_expr("123..3")
        @test_throws NumExpr.SyntaxError parse_expr(".123.")
        @test_throws NumExpr.SyntaxError parse_expr(".(")
        @test_throws NumExpr.SyntaxError parse_expr(").")
        @test_throws NumExpr.SyntaxError parse_expr(".abc")
    end

    @testset verbose = true "Parse functions" begin
        @test vectorial(parse_expr("cos(1)")) == ["cos", "1.0"]
        @test vectorial(parse_expr("cos(sin(1))")) == ["cos", ["sin", "1.0"]]
        @test vectorial(parse_expr("max(1, 2, 3)")) == ["max", "1.0", "2.0", "3.0"]
        @test vectorial(parse_expr("max(1, min(2, 3), 4)")) == ["max", "1.0", ["min", "2.0", "3.0"], "4.0"]
    end

    @testset verbose = true "Parse operators" begin
        @test vectorial(parse_expr("-1")) == ["-", "1.0"]
        @test vectorial(parse_expr("-a")) == ["-", "a"]
        @test vectorial(parse_expr("1 + 2")) == ["+", "1.0", "2.0"]
        @test vectorial(parse_expr("2 - 1")) == ["-", "2.0", "1.0"]
        @test vectorial(parse_expr("1 * 2")) == ["*", "1.0", "2.0"]
        @test vectorial(parse_expr("1 / 2")) == ["/", "1.0", "2.0"]
        @test vectorial(parse_expr("1 % 2")) == ["%", "1.0", "2.0"]
        @test vectorial(parse_expr("1 > 2")) == [">", "1.0", "2.0"]
        @test vectorial(parse_expr("1 < 2")) == ["<", "1.0", "2.0"]
        @test vectorial(parse_expr("1 >= 2")) == [">=", "1.0", "2.0"]
        @test vectorial(parse_expr("1 <= 2")) == ["<=", "1.0", "2.0"]
        @test vectorial(parse_expr("1 == 2")) == ["==", "1.0", "2.0"]
        @test vectorial(parse_expr("1 != 2")) == ["!=", "1.0", "2.0"]
        @test vectorial(parse_expr("1 ^ 2")) == ["^", "1.0", "2.0"]
    end

    @testset verbose = true "Parse priority" begin
        @test vectorial(parse_expr("3 - (2 * 4)")) == ["-", "3.0", ["*", "2.0", "4.0"]]
        @test vectorial(parse_expr("3 - (2 * 4) ^ 5")) == ["-", "3.0", ["^", ["*", "2.0", "4.0"], "5.0"]]
        @test vectorial(parse_expr("1 + 2 + 3")) == ["+", "1.0", "2.0", "3.0"]
        @test vectorial(parse_expr("1 > 2 > 3")) == [">", "1.0", "2.0", "3.0"]
    end

    @testset verbose = true "Parse examples" begin
        @test vectorial(parse_expr("1+(-1)")) == ["+", "1.0", ["-", "1.0"]]
        @test vectorial(parse_expr("1+(+1)")) == ["+", "1.0", ["+", "1.0"]]
        @test vectorial(parse_expr("-1+5")) == ["+", ["-", "1.0"], "5.0"]
        @test vectorial(parse_expr("1")) == ["1.0"]
        @test vectorial(parse_expr("a")) == ["a"]
        @test vectorial(parse_expr("a.a")) == ["a.a"]
        @test vectorial(parse_expr("a.a  + 1.0 ")) == ["+", "a.a", "1.0"]
        @test vectorial(parse_expr("1 + 1")) == ["+", "1.0", "1.0"]
        @test vectorial(parse_expr("3 - (2 * 4)")) == ["-", "3.0", ["*", "2.0", "4.0"]]
        @test vectorial(parse_expr("(4 + (1) == 2) + 3")) == ["+", ["==", ["+", "4.0", "1.0"], "2.0"], "3.0"]
        @test vectorial(parse_expr("cos(sin(cos(0)))")) == ["cos", ["sin", ["cos", "0.0"]]]
        @test vectorial(parse_expr("elseif(1,2,3,4,4,5)")) == ["elseif", "1.0", "2.0", "3.0", "4.0", "4.0", "5.0"]
        @test vectorial(parse_expr("min(1, 2, 3, 4, 5) + 1")) == ["+", ["min", "1.0", "2.0", "3.0", "4.0", "5.0"], "1.0"]
        @test vectorial(parse_expr("(a * b)/(c * d)")) == ["/", ["*","a", "b"],["*","c","d"]]
        @test vectorial(parse_expr("a + 1.0 + 2 + exp(x.x) + Beta(arctan(x))")) ==
            ["+", "a", "1.0", "2.0", ["exp", "x.x"], ["Beta", ["arctan", "x"]]]
        @test vectorial(parse_expr("false || true")) == ["||", "false", "true"]
        @test vectorial(parse_expr("true && false")) == ["&&", "true", "false"]
        @test vectorial(parse_expr("true != false")) == ["!=", "true", "false"]
        @test vectorial(parse_expr("(3) == 2")) == ["==", "3.0", "2.0"]
        @test vectorial(parse_expr("(3) == (2 * 3)")) == ["==", "3.0", ["*", "2.0", "3.0"]]
        @test vectorial(parse_expr("(7 - 1) == (2 * 3)")) == ["==", ["-", "7.0", "1.0"], ["*", "2.0", "3.0"]]
        @test vectorial(parse_expr("3 * (2 +(2 + 2 * 3))")) == ["*", "3.0", ["+", "2.0", ["+", "2.0", ["*", "2.0", "3.0"]]]]
        @test vectorial(parse_expr("false || (true && false)")) == ["||", "false", ["&&", "true", "false"]]
        @test vectorial(parse_expr("a >= b")) == [">=", "a", "b"]
        @test vectorial(parse_expr("-2")) == ["-", "2.0"]
        @test vectorial(parse_expr("div(3, 6)")) == ["div", "3.0", "6.0"]
        @test vectorial(parse_expr("mod(8, 3) - cld(5.5, 2.2)")) == ["-", ["mod", "8.0", "3.0"], ["cld", "5.5", "2.2"]]
        @test vectorial(parse_expr("7 <= 8 <= 9")) == ["<=", "7.0", "8.0", "9.0"]
        @test vectorial(parse_expr("xor(true, false)")) == ["xor", "true", "false"]
        @test vectorial(parse_expr("rad2deg((pi * (pi/3 + pi/6)))")) == ["rad2deg", ["*", "pi", ["+", ["/", "pi", "3.0"], ["/", "pi", "6.0"]]]]
        @test vectorial(parse_expr("log(4, 2)")) == ["log", "4.0", "2.0"]
        @test vectorial(parse_expr("log(4, 2)")) == ["log", "4.0", "2.0"]
        @test vectorial(parse_expr("2.0 * sin(1) + 2/2.0 * (2.1) * cos(1)")) ==
            ["+", ["*", "2.0", ["sin", "1.0"]], ["*", ["/", "2.0", "2.0"], "2.1", ["cos", "1.0"]]]

        # tests for expressions with numbers in e notation
        @test vectorial(parse_expr("1e3 + 2")) == ["+", "1000.0", "2.0"]
        @test vectorial(parse_expr("4.5e-2 * 3")) == ["*", "0.045", "3.0"]
        @test vectorial(parse_expr("6E4 / 2")) == ["/", "60000.0", "2.0"]
        @test vectorial(parse_expr("7e3 - 8e2")) == ["-", "7000.0", "800.0"]
        @test vectorial(parse_expr("(-1.2E+3) + 4.56")) == ["+", ["-", "1200.0"], "4.56"]
        @test vectorial(parse_expr("3.1e-1 * (2 + 1e1)")) == ["*", "0.31", ["+", "2.0", "10.0"]]
    end

    @testset verbose = true "Parse strings" begin
        @test vectorial(parse_expr("length('Hello')")) == ["length", "Hello"]
        @test vectorial(parse_expr("concat('Hello', 'World')")) == ["concat", "Hello", "World"]
        @test vectorial(parse_expr("uppercase('hello')")) == ["uppercase", "hello"]
        @test vectorial(parse_expr("lowercase('WORLD')")) == ["lowercase", "WORLD"]
        @test vectorial(parse_expr("join(', ', ['apple', 'banana', 'cherry'])")) == ["join", ", ", "'apple', 'banana', 'cherry'"]
        @test vectorial(parse_expr("exp(2)")) == ["exp", "2.0"]
        @test vectorial(parse_expr("concat('Hello', ' ', 'World')")) == ["concat", "Hello", " ", "World"]
        @test vectorial(parse_expr("replace('Hello', 'H', 'J')")) == ["replace", "Hello", "H", "J"]
        @test vectorial(parse_expr("substring('Hello', 2, 4)")) == ["substring", "Hello", "2.0", "4.0"]
        @test vectorial(parse_expr("count('banana', 'a')")) == ["count", "banana", "a"]
        @test vectorial(parse_expr("regexmatch('Hello, World!', 'o.*d')")) == ["regexmatch", "Hello, World!", "o.*d"]
        @test vectorial(parse_expr("startswith('Hello', 'H')")) == ["startswith", "Hello", "H"]
        @test vectorial(parse_expr("endswith('World', 'd')")) == ["endswith", "World", "d"]
        @test vectorial(parse_expr("check('你很好奇')")) == ["check", "你很好奇"]
    end

    @testset verbose = true "Parse union" begin
        @test vectorial(parse_expr("1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1")) == ["+", "1.0", "1.0", "1.0", "1.0", "1.0", "1.0", "1.0", "1.0", "1.0", "1.0", "1.0", "1.0", "1.0"]
        @test vectorial(parse_expr("1 + 1 + 1 - 1 + 1")) == ["+", ["-", ["+", "1.0", "1.0", "1.0"], "1.0"], "1.0"]
        @test vectorial(parse_expr("1 + 1 + 1 * 1 - 1 + 1")) == ["+", ["-", ["+", "1.0", "1.0", ["*", "1.0", "1.0"]], "1.0"], "1.0"]
        @test vectorial(parse_expr("sum(sum(1, 2), 3)")) == ["sum", ["sum", "1.0", "2.0"], "3.0"]
        @test vectorial(parse_expr("-1 -2 -3 -4")) == ["-", ["-", "1.0"], "2.0", "3.0", "4.0"]
        @test vectorial(parse_expr("1 -2 -3 -4")) == ["-", "1.0", "2.0", "3.0", "4.0"]
        @test vectorial(parse_expr("1 -2 -3 +4")) ==  ["+", ["-", "1.0", "2.0", "3.0"], "4.0"]
    end

    @testset verbose = true "Eval number" begin
        @test eval_expr(parse_expr("1")) == 1
        @test eval_expr(parse_expr("-1")) == -1
        @test eval_expr(parse_expr("1.0")) == 1
        @test eval_expr(parse_expr("-1.0")) == -1
        @test eval_expr(parse_expr("0.0")) == 0
        @test eval_expr(parse_expr("-0")) == 0
        @test eval_expr(parse_expr("123456789012345678901234567890123456789")) == 1.2345678901234568e38
        @test eval_expr(parse_expr("-123456789012345678901234567890123456789")) == -1.2345678901234568e38
        @test eval_expr(parse_expr("1e10")) == 1.0e10
        @test eval_expr(parse_expr("2.5E+3")) == 2500.0
        @test eval_expr(parse_expr("3.45e-2")) == 0.0345
        @test eval_expr(parse_expr("6E4")) == 60000.0
        @test eval_expr(parse_expr("7.89e0")) == 7.89
    end

    @testset verbose = true "Eval math func" begin
        @test eval_expr(parse_expr("sqrt(2)")) == sqrt(2)
        @test eval_expr(parse_expr("abs(2)")) == abs(2)
        @test eval_expr(parse_expr("sin(2)")) == sin(2)
        @test eval_expr(parse_expr("cos(2)")) == cos(2)
        @test eval_expr(parse_expr("atan(2)")) == atan(2)
        @test eval_expr(parse_expr("exp(2)")) == exp(2)
        @test eval_expr(parse_expr("log(2)")) == log(2)
        @test eval_expr(parse_expr("tg(0)")) == 0.0
        @test eval_expr(parse_expr("tg(1)")) == tan(1)
        @test eval_expr(parse_expr("ctg(1)")) ≈ cos(1) / sin(1)
        @test eval_expr(parse_expr("mean(2, 4, 6)")) == 4.0
        @test eval_expr(parse_expr("mean(10)")) == 10.0
        @test eval_expr(parse_expr("mean(1, 2, 3, 4, 5)")) == 3.0
    end

    @testset verbose = true "Eval math const" begin
        @test eval_expr(parse_expr("1/0")) == 1/0
        @test eval_expr(parse_expr("-1/0")) == -1/0
        @test eval_expr(parse_expr("0/1")) == 0/1
        @test eval_expr(parse_expr("0/0")) === 0/0
    end

    @testset verbose = true "Eval expr with vars" begin
        @test_throws NumExpr.SyntaxError eval_expr(parse_expr("4 - π"))
        @test_throws NumExpr.SyntaxError eval_expr(parse_expr("3 + 2ℯ1 - π"))
        @test_throws NumExpr.SyntaxError eval_expr(parse_expr("(3 + 2ℯ1 - π) * Inf"))
        @test_throws MethodError eval_expr(parse_expr("1/-Inf"))
    end

    @testset verbose = true "Eval expr with strings" begin
        @test_throws NumExpr.SyntaxError eval_expr(parse_expr("'aaaaa"))
        @test_throws NumExpr.SyntaxError eval_expr(parse_expr("'bbb''''"))

        expr = "'a' * 'b' * 'v'"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "'a' ^ 10"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "'a' ^ 10 * 'b' ^ 10"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))
    end

    @testset verbose = true "Eval math exprs" begin
        expr = "2+2"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "2-2"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "2*3"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "1/2"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "49*63/58*36"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "84+62/33*10+15"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "16+25-92+54/66"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "64+19-77-93"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "88-72+55*57"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "99*55/30+50"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "11-88+84-48"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "68*60/87/53+17"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "63-69-46+57"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "60+29/57-85"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "34*18*55-50"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "12*3-18+34-84"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "70/42-52-64/35"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "39/41+100+45"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "20-57*12-(58+84*32/27)"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "77+79/25*(64*63-89*14)*49"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "100-60/38+(19/88*97/82/94)*92"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "(97/48+86+56*94)/43+57"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "(68-85/75*64)/15+73"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "91+18/(42+62+84*95)+30"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "49*31*(20-83/63/46*29)/68"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "35-45/37+84+(41+86/18/41*73)"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "44*13/(26+24*70+89*7)+81"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "53-88+7+(34/54+15/23/6)*73"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "57-71+(14+3-24*100/23)/53"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "(41*76*79-61)/60+83"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "(73+85+64/17)*17+31/60"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "74*96+62/(25/33+96+87+78)"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "33-96+(95-76*98/11)*15"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "72/75+4*(14*2/57*21)/15"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "72*95+53+(2+76-52/1-47)"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "85*97/(89/11-18*96)-61"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "29+24/91-(14*71*18/20*100)+63"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "52*62*(61+12-14*79)+39"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "(38+52+65-19)*(72*3/36*(9/2-17*38/28))/18/84"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "93*30/81*(78*83/(71*13-(14+13-28*62)*62)+99-(80-89+17*42))"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "58*85*(1+16*7+(82*31*(85/75-51-22)+2-24))*22*(27+67+0+93)"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "99-78*(((63+52/67+26/29)+94+(68-11/1*88)+49)/69*15*8)-1"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "(56/33+87+((12/48-44-51)+85*(69-35-67-82+81)-40))-86-85"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "(80/12/47-93)+78/(20/23+(54+36/29+23)-61)"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "((91/57/30-72)-(53*22/23/6)*79-27)-19/30"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "(36+78+(43/89-57/(64+98/57-24-47))*56)-((29-9/76*99-29)*98/11)*31"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "6+78+(55/20-92/55/((94+40+56/61)/38/97+(32/36/25*(12/30-22*(51/87*71/50/(98-37-90-91)))*57)))/42/25"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "((60-42-16/100)*(29*88+51+77)-49-59)-89*45"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "11-92+48/((12/92+(53/74/22+(61/24/42-(13*85+100/77/11)+89)+9)+87)/91*92)"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "66-83+((41*98*10*(40/64+46*33))/(61+91-73*9+12)/(88*29/96-41-72))*(81*40/95+61)+5"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "(93*79/(24+83/(11*45/21*((75-15-(60+94/(70-27-89+71)-81)*27-73)*92-59-57)+13)*84*49)/22)*27/62+76"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "92-34+32*(((89-87/11/66)/49+2/76)/93/45)*92"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "(81+60/54/21)+(77-31+(41+69-62-96)*0)-0-62"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "20*60+9-(89*95*3*(44-51-11-(62+69-22+21)*9)/50)-(94-70/29/7)"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "94/49+36/(39+1^(18*47/20*(66-51/19/19+(22*80/4/74-59))*12)/69)"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "24-23*17/(93+52*70*(6+91/((4/39/8*30)/(22*97*(32*20*(82-80*51/89*9)*56+82)*89)-17-17)/29/81))"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "3*26/((75/18*91*38)/53-(52/34-(10*67-50-78)*51+58))+73"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "(91/56+53*93)+(12*36+55+54/(56+43+45+61-45))/(94-23-66*(71+65/95/27/1)-17)"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "75*97*3-((59-3/88+(93*100*65-38+54))/63-85)"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "(94/78/20/62)^78-((40+46/7*35)/42+41*26)"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "(6+28+18-((61+17*64*98)*(61/53*47/36*98)+82+(69-55/(62*77/88-52/10)-42-(48/84*77+40-13))))-4/99"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "96*67-10+(40-42-25/(96/23*54*(18*30/85/79-90)))"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "93-42/(80*45+46+(66*45-26*0*84))-((20-59-18-62)/(9/90*16-6)*3)"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "(96/83-53-(59-91/91-54))/(75^4/(50-80*45+93+18)-76/54)*14+59"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "29+67-22*(((98+90*90+81-83)*92-79+37)*20-60)"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "((8-5+90+8/7)-9+(5/6+12/39+15)-28)+14^7"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))

        expr = "5-13+(25^2/(47/38*(64/93-91+72)*66)+43-5)*39/55"
        @test eval_expr(parse_expr(expr)) == Meta.eval(Meta.parse(expr))
    end

    @testset "Global Scope Variable Parsing" begin
        global_var_str = "my_global_var[title='Learning Julia',category='books',id='123']"
        parsed_global = parse_expr(global_var_str)

        @test parsed_global.name             == "my_global_var"
        @test parsed_global.tags["category"] == "books"
        @test parsed_global.tags["id"]       == "123"
        @test parsed_global.tags["title"]    == "Learning Julia"
        @test parsed_global.val              == "my_global_var[category='books',id='123',title='Learning Julia']"
    end

    @testset "Local Scope Variable Parsing" begin
        local_var_str = "my_local_var{type='tool',name='screwdriver',size='M4'}"
        parsed_local = parse_expr(local_var_str)

        @test parsed_local.name         == "my_local_var"
        @test parsed_local.tags["type"] == "tool"
        @test parsed_local.tags["name"] == "screwdriver"
        @test parsed_local.tags["size"] == "M4"
        @test parsed_local.val          == "my_local_var{name='screwdriver',size='M4',type='tool'}"
    end

    @testset "Local Scope Variable Parsing With Dot" begin
        local_var_str = "my_local_var{type='tool',name='screwdriver.new',size='M4'}"
        parsed_local = parse_expr(local_var_str)

        @test parsed_local.name         == "my_local_var"
        @test parsed_local.tags["type"] == "tool"
        @test parsed_local.tags["name"] == "screwdriver.new"
        @test parsed_local.tags["size"] == "M4"
        @test parsed_local.val          == "my_local_var{name='screwdriver.new',size='M4',type='tool'}"
    end

    @testset "Old-Style Global Variable Parsing" begin
        global_var_str = "[my_local_var]"
        parsed_global = parse_expr(global_var_str)

        @test parsed_global.name         == "my_local_var"
        @test parsed_global.val          == "my_local_var"
    end

    @testset "Unnamed Variable Parsing" begin
        local_var_str = "{type='tool', size='M4'}"
        parsed_local = parse_expr(local_var_str)

        @test parsed_local.val == "type='tool', size='M4'"
        @test parsed_local.tags === nothing
        @test !var_has_tags(parsed_local)
    end

    @testset "Parsing: Invalid Syntax Error" begin
        @test_throws NumExpr.SyntaxError begin
            var_str = "sum.(1, 2, 3)"
            parse_expr(var_str)
        end

        @test_throws NumExpr.SyntaxError begin
            var_str = "my_global_var[type='total',name='screwdriver]"
            parse_expr(var_str)
        end

        @test_throws NumExpr.SyntaxError begin
            var_str = "my_global_var[type='total' '3', name='screwdriver']"
            parse_expr(var_str)
        end

        @test_throws NumExpr.SyntaxError begin
            var_str = "my_global_var[type='total' count='3', name='screwdriver']"
            parse_expr(var_str)
        end

        @test_throws NumExpr.SyntaxError begin
            var_str = "my_global_var[type='total', 'count'='3', name='screwdriver']"
            parse_expr(var_str)
        end

        @test_throws NumExpr.SyntaxError begin
            var_str = "my_global_var[type='total, '', name='screwdriver']"
            parse_expr(var_str)
        end

        @test_throws NumExpr.SyntaxError begin
            var_str = "my_global_var[type='total '', name='screwdriver']"
            parse_expr(var_str)
        end

        @test_throws NumExpr.SyntaxError begin
            var_str = "my_global_var[ty.pe='total', name='screwdriver']"
            parse_expr(var_str)
        end
    end

    #__ Boolean / NaN literal parsing ────────────────────────────────

    @testset verbose = true "Boolean literal parsing" begin
        # true / false → NumVal{Bool}
        @test vectorial(parse_expr("true")) == ["true"]
        @test vectorial(parse_expr("false")) == ["false"]
        @test eval_expr(parse_expr("true")) === true
        @test eval_expr(parse_expr("false")) === false

        # Case-sensitive: mixed / upper case → variables
        @test vectorial(parse_expr("True")) == ["True"]
        @test vectorial(parse_expr("False")) == ["False"]
        @test vectorial(parse_expr("TRUE")) == ["TRUE"]
        @test vectorial(parse_expr("FALSE")) == ["FALSE"]
        @test vectorial(parse_expr("tRue")) == ["tRue"]
        @test vectorial(parse_expr("fAlse")) == ["fAlse"]

        # 5-char words ending in 'e' must NOT be parsed as false
        # (regression test for the || → && fix in isfalsenumber)
        @test vectorial(parse_expr("state")) == ["state"]
        @test vectorial(parse_expr("valve")) == ["valve"]
        @test vectorial(parse_expr("parse")) == ["parse"]
        @test vectorial(parse_expr("scope")) == ["scope"]
        @test vectorial(parse_expr("value")) == ["value"]
        @test vectorial(parse_expr("close")) == ["close"]
        @test vectorial(parse_expr("price")) == ["price"]
        @test vectorial(parse_expr("space")) == ["space"]
        @test vectorial(parse_expr("store")) == ["store"]
        @test vectorial(parse_expr("trade")) == ["trade"]

        # 4-char words ending in 'e' must NOT be parsed as true
        @test vectorial(parse_expr("time")) == ["time"]
        @test vectorial(parse_expr("type")) == ["type"]
        @test vectorial(parse_expr("rate")) == ["rate"]
        @test vectorial(parse_expr("size")) == ["size"]
        @test vectorial(parse_expr("cure")) == ["cure"]
        @test vectorial(parse_expr("pure")) == ["pure"]
        @test vectorial(parse_expr("more")) == ["more"]
        @test vectorial(parse_expr("sure")) == ["sure"]

        # Prefixed / suffixed true / false → variables
        @test vectorial(parse_expr("truex")) == ["truex"]
        @test vectorial(parse_expr("atrue")) == ["atrue"]
        @test vectorial(parse_expr("truer")) == ["truer"]
        @test vectorial(parse_expr("falsex")) == ["falsex"]
        @test vectorial(parse_expr("afalse")) == ["afalse"]
        @test vectorial(parse_expr("falser")) == ["falser"]
        @test vectorial(parse_expr("istrue")) == ["istrue"]
        @test vectorial(parse_expr("isfalse")) == ["isfalse"]
        @test vectorial(parse_expr("truefalse")) == ["truefalse"]
        @test vectorial(parse_expr("falsetrue")) == ["falsetrue"]
    end

    @testset verbose = true "NaN literal parsing" begin
        @test vectorial(parse_expr("NaN")) == ["NaN"]
        @test eval_expr(parse_expr("NaN")) === NaN

        # Case-sensitive — other cases are variables
        @test vectorial(parse_expr("nan")) == ["nan"]
        @test vectorial(parse_expr("NAN")) == ["NAN"]
        @test vectorial(parse_expr("Nan")) == ["Nan"]
        @test vectorial(parse_expr("naN")) == ["naN"]

        # Prefixed / suffixed
        @test vectorial(parse_expr("NaNx")) == ["NaNx"]
        @test vectorial(parse_expr("aNaN")) == ["aNaN"]
        @test vectorial(parse_expr("isNaN")) == ["isNaN"]
        @test vectorial(parse_expr("NaN1")) == ["NaN1"]
    end

    #__ Operator precedence ──────────────────────────────────────────

    @testset verbose = true "Operator precedence comprehensive" begin
        # ^ (6) tighter than * / (5)
        @test vectorial(parse_expr("2 * 3 ^ 4")) == ["*", "2.0", ["^", "3.0", "4.0"]]
        @test vectorial(parse_expr("2 ^ 3 * 4")) == ["*", ["^", "2.0", "3.0"], "4.0"]
        @test vectorial(parse_expr("2 / 3 ^ 4")) == ["/", "2.0", ["^", "3.0", "4.0"]]

        # * / (5) tighter than + - (3)
        @test vectorial(parse_expr("2 + 3 * 4")) == ["+", "2.0", ["*", "3.0", "4.0"]]
        @test vectorial(parse_expr("2 * 3 + 4")) == ["+", ["*", "2.0", "3.0"], "4.0"]
        @test vectorial(parse_expr("2 - 3 / 4")) == ["-", "2.0", ["/", "3.0", "4.0"]]
        @test vectorial(parse_expr("2 / 3 - 4")) == ["-", ["/", "2.0", "3.0"], "4.0"]

        # % (4) between + (3) and * (5)
        @test vectorial(parse_expr("2 + 3 % 4")) == ["+", "2.0", ["%", "3.0", "4.0"]]
        @test vectorial(parse_expr("2 % 3 + 4")) == ["+", ["%", "2.0", "3.0"], "4.0"]
        @test vectorial(parse_expr("2 * 3 % 4")) == ["%", ["*", "2.0", "3.0"], "4.0"]
        @test vectorial(parse_expr("2 % 3 * 4")) == ["%", "2.0", ["*", "3.0", "4.0"]]

        # Comparison (2) lower than arithmetic (3)
        @test vectorial(parse_expr("1 + 2 > 3")) == [">", ["+", "1.0", "2.0"], "3.0"]
        @test vectorial(parse_expr("1 > 2 + 3")) == [">", "1.0", ["+", "2.0", "3.0"]]
        @test vectorial(parse_expr("1 + 2 == 3 - 1")) == ["==", ["+", "1.0", "2.0"], ["-", "3.0", "1.0"]]
        @test vectorial(parse_expr("1 * 2 != 3 / 4")) == ["!=", ["*", "1.0", "2.0"], ["/", "3.0", "4.0"]]
        @test vectorial(parse_expr("a >= b - 1")) == [">=", "a", ["-", "b", "1.0"]]
        @test vectorial(parse_expr("a + 1 <= b")) == ["<=", ["+", "a", "1.0"], "b"]

        # && (1) lower than comparison (2)
        @test vectorial(parse_expr("1 > 2 && 3 < 4")) == ["&&", [">", "1.0", "2.0"], ["<", "3.0", "4.0"]]
        @test vectorial(parse_expr("a == b && c != d")) == ["&&", ["==", "a", "b"], ["!=", "c", "d"]]

        # || (0) lower than && (1)
        @test vectorial(parse_expr("a || b && c")) == ["||", "a", ["&&", "b", "c"]]
        @test vectorial(parse_expr("a && b || c")) == ["||", ["&&", "a", "b"], "c"]
        @test vectorial(parse_expr("a && b || c && d")) == ["||", ["&&", "a", "b"], ["&&", "c", "d"]]
        @test vectorial(parse_expr("a || b && c || d")) == ["||", "a", ["&&", "b", "c"], "d"]

        # Full precedence chain: || < && < comparison < +- < % < */ < ^
        @test vectorial(parse_expr("1 + 2 * 3 ^ 4 > 5 && 6 || 7")) ==
            ["||", ["&&", [">", ["+", "1.0", ["*", "2.0", ["^", "3.0", "4.0"]]], "5.0"], "6.0"], "7.0"]

        # Parentheses override precedence
        @test vectorial(parse_expr("(1 + 2) * 3")) == ["*", ["+", "1.0", "2.0"], "3.0"]
        @test vectorial(parse_expr("2 ^ (1 + 1)")) == ["^", "2.0", ["+", "1.0", "1.0"]]
        @test vectorial(parse_expr("(a || b) && c")) == ["&&", ["||", "a", "b"], "c"]
        @test vectorial(parse_expr("(1 + 2) * (3 + 4)")) == ["*", ["+", "1.0", "2.0"], ["+", "3.0", "4.0"]]
    end

    #__ N-ary flattening ─────────────────────────────────────────────

    @testset verbose = true "N-ary operator flattening" begin
        # Same-operator chains flatten into n-ary nodes
        @test vectorial(parse_expr("1 + 2 + 3 + 4 + 5")) == ["+", "1.0", "2.0", "3.0", "4.0", "5.0"]
        @test vectorial(parse_expr("2 * 3 * 4")) == ["*", "2.0", "3.0", "4.0"]
        @test vectorial(parse_expr("2 * 3 * 4 * 5")) == ["*", "2.0", "3.0", "4.0", "5.0"]
        @test vectorial(parse_expr("1 - 2 - 3")) == ["-", "1.0", "2.0", "3.0"]
        @test vectorial(parse_expr("8 / 4 / 2")) == ["/", "8.0", "4.0", "2.0"]
        @test vectorial(parse_expr("2 ^ 3 ^ 2")) == ["^", "2.0", "3.0", "2.0"]
        @test vectorial(parse_expr("a || b || c")) == ["||", "a", "b", "c"]
        @test vectorial(parse_expr("a && b && c")) == ["&&", "a", "b", "c"]
        @test vectorial(parse_expr("a > b > c > d")) == [">", "a", "b", "c", "d"]
        @test vectorial(parse_expr("a == b == c")) == ["==", "a", "b", "c"]

        # Different operators at same precedence break the chain
        @test vectorial(parse_expr("1 + 2 - 3")) == ["-", ["+", "1.0", "2.0"], "3.0"]
        @test vectorial(parse_expr("1 - 2 + 3")) == ["+", ["-", "1.0", "2.0"], "3.0"]
        @test vectorial(parse_expr("1 * 2 / 3")) == ["/", ["*", "1.0", "2.0"], "3.0"]
        @test vectorial(parse_expr("1 / 2 * 3")) == ["*", ["/", "1.0", "2.0"], "3.0"]
        @test vectorial(parse_expr("1 > 2 < 3")) == ["<", [">", "1.0", "2.0"], "3.0"]

        # N-ary eval: left-associative reduce
        @test eval_expr(parse_expr("1 + 2 + 3 + 4 + 5")) == 15.0
        @test eval_expr(parse_expr("2 * 3 * 4")) == 24.0
        @test eval_expr(parse_expr("1 - 2 - 3")) == -4.0    # ((1-2)-3)
        @test eval_expr(parse_expr("24 / 4 / 3")) == 2.0     # ((24/4)/3)
        @test eval_expr(parse_expr("24 / 4 / 3 / 2")) == 1.0

        # Left-associative exponentiation (unlike standard math)
        @test eval_expr(parse_expr("2 ^ 3 ^ 2")) == 64.0     # (2^3)^2, not 2^(3^2)=512
        @test eval_expr(parse_expr("2 ^ (3 ^ 2)")) == 512.0  # right-assoc with parens

        # Mixed chains with eval verification
        @test eval_expr(parse_expr("10 - 3 - 2 - 1")) == 4.0
        @test eval_expr(parse_expr("100 / 5 / 4 / 5")) == 1.0
        @test eval_expr(parse_expr("1 + 2 - 3 + 4")) == 4.0
    end

    #__ Unary operators ──────────────────────────────────────────────

    @testset verbose = true "Unary operators comprehensive" begin
        # Basic unary parse
        @test vectorial(parse_expr("+a")) == ["+", "a"]
        @test vectorial(parse_expr("-(1)")) == ["-", "1.0"]
        @test vectorial(parse_expr("+(1)")) == ["+", "1.0"]

        # Double and triple unary
        @test vectorial(parse_expr("-(-1)")) == ["-", ["-", "1.0"]]
        @test vectorial(parse_expr("-(-(1))")) == ["-", ["-", "1.0"]]
        @test vectorial(parse_expr("+(+1)")) == ["+", ["+", "1.0"]]
        @test vectorial(parse_expr("-(-(-1))")) == ["-", ["-", ["-", "1.0"]]]

        # Unary in binary expressions
        @test vectorial(parse_expr("1 + (-2)")) == ["+", "1.0", ["-", "2.0"]]
        @test vectorial(parse_expr("1 * (-2)")) == ["*", "1.0", ["-", "2.0"]]
        @test vectorial(parse_expr("-1 + -2")) == ["+", ["-", "1.0"], ["-", "2.0"]]
        @test vectorial(parse_expr("-1 * -2")) == ["*", ["-", "1.0"], ["-", "2.0"]]

        # Unary minus binds tighter than ^ (handled at atomic level)
        @test vectorial(parse_expr("-3 ^ 2")) == ["^", ["-", "3.0"], "2.0"]

        # Eval
        @test eval_expr(parse_expr("+1")) == 1.0
        @test eval_expr(parse_expr("-(-1)")) == 1.0
        @test eval_expr(parse_expr("-(-(1))")) == 1.0
        @test eval_expr(parse_expr("-(-(-1))")) == -1.0
        @test eval_expr(parse_expr("1 + (-2)")) == -1.0
        @test eval_expr(parse_expr("-1 + -2")) == -3.0
        @test eval_expr(parse_expr("-1 * -2")) == 2.0
        @test eval_expr(parse_expr("-3 ^ 2")) == 9.0  # (-3)^2
        @test eval_expr(parse_expr("-(3 ^ 2)")) == -9.0
        @test eval_expr(parse_expr("-0")) == 0.0
        @test eval_expr(parse_expr("+0")) == 0.0
    end

    #__ Eval: comparisons ────────────────────────────────────────────

    @testset verbose = true "Eval comparisons" begin
        # All 6 comparison operators
        @test eval_expr(parse_expr("1 > 0")) == true
        @test eval_expr(parse_expr("0 > 1")) == false
        @test eval_expr(parse_expr("1 > 1")) == false
        @test eval_expr(parse_expr("1 < 2")) == true
        @test eval_expr(parse_expr("2 < 1")) == false
        @test eval_expr(parse_expr("1 < 1")) == false
        @test eval_expr(parse_expr("1 == 1")) == true
        @test eval_expr(parse_expr("1 == 2")) == false
        @test eval_expr(parse_expr("1 != 2")) == true
        @test eval_expr(parse_expr("1 != 1")) == false
        @test eval_expr(parse_expr("1 >= 1")) == true
        @test eval_expr(parse_expr("1 >= 2")) == false
        @test eval_expr(parse_expr("2 >= 1")) == true
        @test eval_expr(parse_expr("1 <= 1")) == true
        @test eval_expr(parse_expr("2 <= 1")) == false
        @test eval_expr(parse_expr("1 <= 2")) == true

        # Comparisons with arithmetic subexpressions
        @test eval_expr(parse_expr("1 + 1 > 1")) == true
        @test eval_expr(parse_expr("2 * 3 == 6")) == true
        @test eval_expr(parse_expr("10 / 2 != 3")) == true
        @test eval_expr(parse_expr("2 ^ 3 >= 8")) == true
        @test eval_expr(parse_expr("2 ^ 3 <= 8")) == true
        @test eval_expr(parse_expr("2 ^ 3 > 8")) == false
        @test eval_expr(parse_expr("2 ^ 3 < 8")) == false
        @test eval_expr(parse_expr("3 + 4 == 2 + 5")) == true
        @test eval_expr(parse_expr("10 - 3 > 2 * 3")) == true
        @test eval_expr(parse_expr("10 - 3 > 2 * 4")) == false
    end

    #__ Eval: booleans ───────────────────────────────────────────────

    @testset verbose = true "Eval booleans" begin
        @test eval_expr(parse_expr("true")) === true
        @test eval_expr(parse_expr("false")) === false
        @test eval_expr(parse_expr("true == true")) == true
        @test eval_expr(parse_expr("true == false")) == false
        @test eval_expr(parse_expr("false == false")) == true
        @test eval_expr(parse_expr("true != false")) == true
        @test eval_expr(parse_expr("true != true")) == false

        # Bool <: Number in Julia → boolean arithmetic works
        @test eval_expr(parse_expr("1 + true")) == 2.0
        @test eval_expr(parse_expr("1 + false")) == 1.0
        @test eval_expr(parse_expr("1 - true")) == 0.0
        @test eval_expr(parse_expr("true + true")) == 2
        @test eval_expr(parse_expr("true - false")) == 1
        @test eval_expr(parse_expr("true * 5")) == 5.0
        @test eval_expr(parse_expr("false * 100")) == 0.0

        # Boolean from comparison used in arithmetic
        @test eval_expr(parse_expr("(1 > 0) + (2 > 1)")) == 2
        @test eval_expr(parse_expr("(1 > 0) + (2 < 1)")) == 1
        @test eval_expr(parse_expr("(1 < 0) + (2 < 1)")) == 0
    end

    #__ Eval: NaN and Inf ────────────────────────────────────────────

    @testset verbose = true "Eval NaN and Inf" begin
        # NaN propagation
        @test isnan(eval_expr(parse_expr("NaN")))
        @test isnan(eval_expr(parse_expr("NaN + 1")))
        @test isnan(eval_expr(parse_expr("NaN - 1")))
        @test isnan(eval_expr(parse_expr("NaN * 2")))
        @test isnan(eval_expr(parse_expr("NaN / 2")))
        @test isnan(eval_expr(parse_expr("NaN * 0")))
        @test isnan(eval_expr(parse_expr("NaN + NaN")))
        @test isnan(eval_expr(parse_expr("0 / 0")))

        # NaN comparisons (IEEE 754)
        @test eval_expr(parse_expr("NaN == NaN")) == false
        @test eval_expr(parse_expr("NaN != NaN")) == true
        @test eval_expr(parse_expr("NaN > 0")) == false
        @test eval_expr(parse_expr("NaN < 0")) == false
        @test eval_expr(parse_expr("NaN >= 0")) == false
        @test eval_expr(parse_expr("NaN <= 0")) == false
        @test eval_expr(parse_expr("NaN > NaN")) == false
        @test eval_expr(parse_expr("NaN == 0")) == false

        # Inf
        @test eval_expr(parse_expr("1 / 0")) == Inf
        @test eval_expr(parse_expr("-1 / 0")) == -Inf
        @test eval_expr(parse_expr("1 / 0 + 1")) == Inf
        @test eval_expr(parse_expr("1 / 0 + 1 / 0")) == Inf
        @test eval_expr(parse_expr("1 / 0 > 1000000")) == true
        @test isnan(eval_expr(parse_expr("1 / 0 - 1 / 0")))
        @test isnan(eval_expr(parse_expr("1 / 0 * 0")))
    end

    #__ Eval: functions ──────────────────────────────────────────────

    @testset verbose = true "Eval functions comprehensive" begin
        # sqrt
        @test eval_expr(parse_expr("sqrt(4)")) == 2.0
        @test eval_expr(parse_expr("sqrt(0)")) == 0.0
        @test eval_expr(parse_expr("sqrt(1)")) == 1.0
        @test eval_expr(parse_expr("sqrt(0.25)")) == 0.5

        # abs
        @test eval_expr(parse_expr("abs(-5)")) == 5.0
        @test eval_expr(parse_expr("abs(5)")) == 5.0
        @test eval_expr(parse_expr("abs(0)")) == 0.0
        @test eval_expr(parse_expr("abs(-0.001)")) == 0.001

        # exp / log
        @test eval_expr(parse_expr("exp(0)")) == 1.0
        @test eval_expr(parse_expr("log(1)")) == 0.0
        @test eval_expr(parse_expr("exp(log(5))")) ≈ 5.0
        @test eval_expr(parse_expr("log(exp(3))")) ≈ 3.0
        @test eval_expr(parse_expr("exp(1)")) ≈ ℯ

        # sin / cos / atan
        @test eval_expr(parse_expr("sin(0)")) == 0.0
        @test eval_expr(parse_expr("cos(0)")) == 1.0
        @test eval_expr(parse_expr("atan(0)")) == 0.0
        @test eval_expr(parse_expr("atan(1)")) ≈ atan(1)

        # Trigonometric identity: sin²(x) + cos²(x) = 1
        @test eval_expr(parse_expr("sin(0) ^ 2 + cos(0) ^ 2")) ≈ 1.0
        @test eval_expr(parse_expr("sin(1) ^ 2 + cos(1) ^ 2")) ≈ 1.0
        @test eval_expr(parse_expr("sin(2) ^ 2 + cos(2) ^ 2")) ≈ 1.0
        @test eval_expr(parse_expr("sin(42) ^ 2 + cos(42) ^ 2")) ≈ 1.0
        @test eval_expr(parse_expr("sin(100) ^ 2 + cos(100) ^ 2")) ≈ 1.0

        # Nested functions
        @test eval_expr(parse_expr("sqrt(abs(-16))")) == 4.0
        @test eval_expr(parse_expr("abs(sin(0))")) == 0.0
        @test eval_expr(parse_expr("abs(-sqrt(2))")) ≈ sqrt(2)
        @test eval_expr(parse_expr("sqrt(sqrt(16))")) == 2.0
        @test eval_expr(parse_expr("log(sqrt(exp(2)))")) ≈ 1.0

        # Functions in expressions
        @test eval_expr(parse_expr("sin(0) + cos(0)")) == 1.0
        @test eval_expr(parse_expr("2 * sqrt(4)")) == 4.0
        @test eval_expr(parse_expr("sqrt(4) + sqrt(9)")) == 5.0
        @test eval_expr(parse_expr("sqrt(3 ^ 2 + 4 ^ 2)")) == 5.0
        @test eval_expr(parse_expr("sqrt(5 ^ 2 + 12 ^ 2)")) == 13.0
    end

    #__ Eval: string operations ──────────────────────────────────────

    @testset verbose = true "Eval string operations" begin
        # Concatenation
        @test eval_expr(parse_expr("'a' * 'b'")) == "ab"
        @test eval_expr(parse_expr("'hello' * ' ' * 'world'")) == "hello world"
        @test eval_expr(parse_expr("'a' * 'b' * 'c' * 'd'")) == "abcd"

        # Repetition
        @test eval_expr(parse_expr("'a' ^ 5")) == "aaaaa"
        @test eval_expr(parse_expr("'ab' ^ 3")) == "ababab"
        @test eval_expr(parse_expr("'x' ^ 1")) == "x"

        # Comparisons
        @test eval_expr(parse_expr("'abc' == 'abc'")) == true
        @test eval_expr(parse_expr("'abc' == 'def'")) == false
        @test eval_expr(parse_expr("'abc' != 'def'")) == true
        @test eval_expr(parse_expr("'abc' != 'abc'")) == false
        @test eval_expr(parse_expr("'abc' < 'def'")) == true
        @test eval_expr(parse_expr("'def' > 'abc'")) == true
        @test eval_expr(parse_expr("'abc' <= 'abc'")) == true
        @test eval_expr(parse_expr("'abc' >= 'abc'")) == true
        @test eval_expr(parse_expr("'a' < 'b'")) == true
        @test eval_expr(parse_expr("'z' > 'a'")) == true
    end

    #__ Complex mathematical expressions ─────────────────────────────

    @testset verbose = true "Complex mathematical expressions" begin
        # Pythagorean theorem
        @test eval_expr(parse_expr("sqrt(3 ^ 2 + 4 ^ 2)")) == 5.0
        @test eval_expr(parse_expr("sqrt(5 ^ 2 + 12 ^ 2)")) == 13.0
        @test eval_expr(parse_expr("sqrt(8 ^ 2 + 15 ^ 2)")) == 17.0

        # Golden ratio
        @test eval_expr(parse_expr("(1 + sqrt(5)) / 2")) ≈ (1 + sqrt(5)) / 2

        # Logarithm/exponent identities
        @test eval_expr(parse_expr("log(exp(1))")) ≈ 1.0
        @test eval_expr(parse_expr("exp(log(42))")) ≈ 42.0

        # Power rules
        @test eval_expr(parse_expr("2 ^ 10")) == 1024.0
        @test eval_expr(parse_expr("2 ^ (-1)")) == 0.5
        @test eval_expr(parse_expr("4 ^ 0.5")) == 2.0
        @test eval_expr(parse_expr("8 ^ (1 / 3)")) ≈ 2.0
        @test eval_expr(parse_expr("27 ^ (1 / 3)")) ≈ 3.0

        # Deeply nested parentheses
        @test eval_expr(parse_expr("((((1 + 2))))")) == 3.0
        @test eval_expr(parse_expr("((((((42))))))")) == 42.0
        @test eval_expr(parse_expr("(((1 + 2) * 3) - 4) / 5")) == 1.0

        # Verification against Julia's eval
        for expr_str in [
            "1 + 2 * 3",
            "2 ^ 10 - 1",
            "abs(-42)",
            "(1 + 1) ^ 10",
            "(3 + 4) * (5 - 2)",
            "100 / (2 + 3) / 4",
            "2 * (3 + 4 * (5 - 1))",
            "((2 + 3) * (4 - 1)) ^ 2",
        ]
            @test eval_expr(parse_expr(expr_str)) ≈ Meta.eval(Meta.parse(expr_str))
        end
    end

    #__ Scientific notation edge cases ───────────────────────────────

    @testset verbose = true "Scientific notation comprehensive" begin
        # Various formats
        @test eval_expr(parse_expr("1e0")) == 1.0
        @test eval_expr(parse_expr("1e1")) == 10.0
        @test eval_expr(parse_expr("1e-1")) == 0.1
        @test eval_expr(parse_expr("1e+1")) == 10.0
        @test eval_expr(parse_expr("1E0")) == 1.0
        @test eval_expr(parse_expr("1E1")) == 10.0
        @test eval_expr(parse_expr("1E-1")) == 0.1
        @test eval_expr(parse_expr("1E+1")) == 10.0
        @test eval_expr(parse_expr("1.5e2")) == 150.0
        @test eval_expr(parse_expr("2.5e-3")) == 0.0025
        @test eval_expr(parse_expr("9.99e0")) == 9.99

        # In arithmetic expressions
        @test eval_expr(parse_expr("1e3 + 1e2")) == 1100.0
        @test eval_expr(parse_expr("1e3 * 2")) == 2000.0
        @test eval_expr(parse_expr("1e3 - 1e3")) == 0.0
        @test eval_expr(parse_expr("1e10 / 1e10")) == 1.0
        @test eval_expr(parse_expr("2.5e2 + 7.5e2")) == 1000.0

        # In comparisons
        @test eval_expr(parse_expr("1e3 > 999")) == true
        @test eval_expr(parse_expr("1e3 == 1000")) == true
        @test eval_expr(parse_expr("1e-1 < 1")) == true

        # Errors
        @test_throws NumExpr.SyntaxError parse_expr("1e")
        @test_throws NumExpr.SyntaxError parse_expr("1e+")
        @test_throws NumExpr.SyntaxError parse_expr("1e-")
        @test_throws NumExpr.SyntaxError parse_expr("1E")
        @test_throws NumExpr.SyntaxError parse_expr("1E+")
        @test_throws NumExpr.SyntaxError parse_expr("1E-")
        @test_throws NumExpr.SyntaxError parse_expr("1.5e")
        @test_throws NumExpr.SyntaxError parse_expr("2.5E+")
    end

    #__ Parse errors ─────────────────────────────────────────────────

    @testset verbose = true "Parse errors additional" begin
        # Invalid ASCII characters
        @test_throws NumExpr.SyntaxError parse_expr("@x")
        @test_throws NumExpr.SyntaxError parse_expr("#1")
        @test_throws NumExpr.SyntaxError parse_expr("~a")
        @test_throws NumExpr.SyntaxError parse_expr("\\x")

        # Broadcasting prohibited
        @test_throws NumExpr.SyntaxError parse_expr("f.(x)")
        @test_throws NumExpr.SyntaxError parse_expr("cos.(1)")
        @test_throws NumExpr.SyntaxError parse_expr("abs.(x)")

        # Dot edge cases
        @test_throws NumExpr.SyntaxError parse_expr(".1")
        @test_throws NumExpr.SyntaxError parse_expr("1..2")
        @test_throws NumExpr.SyntaxError parse_expr(".abc")

        # Whitespace variants
        @test_throws NumExpr.SyntaxError parse_expr("\t")
        @test_throws NumExpr.SyntaxError parse_expr("\n")

        # Unclosed brackets
        @test_throws NumExpr.SyntaxError parse_expr("[abc")
        @test_throws NumExpr.SyntaxError parse_expr("{abc")
    end

    #__ Eval: precision and edge cases ───────────────────────────────

    @testset verbose = true "Eval precision and edge cases" begin
        # Float64 precision matches Julia
        @test eval_expr(parse_expr("0.1 + 0.2")) == 0.1 + 0.2
        @test eval_expr(parse_expr("1.0 - 1.0")) == 0.0
        @test eval_expr(parse_expr("2.0 * 0.5")) == 1.0
        @test eval_expr(parse_expr("1.0 / 3.0")) == 1.0 / 3.0

        # Large numbers
        @test eval_expr(parse_expr("1e300 * 1e-300")) == 1.0
        @test eval_expr(parse_expr("1e308")) == 1e308
        @test eval_expr(parse_expr("1e-308")) == 1e-308

        # Zero arithmetic
        @test eval_expr(parse_expr("0 + 0")) == 0.0
        @test eval_expr(parse_expr("0 * 1000000")) == 0.0
        @test eval_expr(parse_expr("0 ^ 1")) == 0.0
        @test eval_expr(parse_expr("1 ^ 0")) == 1.0
        @test eval_expr(parse_expr("0 ^ 0")) == 1.0  # IEEE 754: 0^0 = 1

        # Single value expressions
        @test eval_expr(parse_expr("42")) == 42.0
        @test eval_expr(parse_expr("0")) == 0.0
        @test eval_expr(parse_expr("0.0")) == 0.0
        @test eval_expr(parse_expr("(42)")) == 42.0
        @test eval_expr(parse_expr("((42))")) == 42.0
    end

    #__ Memory / allocation stress ───────────────────────────────────

    @testset verbose = true "Stress tests" begin
        # Long addition chain
        long_sum = join(fill("1", 100), " + ")
        @test eval_expr(parse_expr(long_sum)) == 100.0

        # Long multiplication chain
        long_prod = join(fill("2", 20), " * ")
        @test eval_expr(parse_expr(long_prod)) == 2.0^20

        # Deeply nested parentheses
        deep_paren = "(" ^ 50 * "1" * ")" ^ 50
        @test eval_expr(parse_expr(deep_paren)) == 1.0

        # Nested function calls
        nested_abs = "abs(" ^ 10 * "42" * ")" ^ 10
        @test eval_expr(parse_expr(nested_abs)) == 42.0

        # Long variable name
        long_var = "a" ^ 200
        @test vectorial(parse_expr(long_var)) == [long_var]

        # Complex deeply nested expression
        expr_str = "((1 + 2) * (3 - 4) + (5 * 6)) / ((7 - 8) * (9 + 10) + 11)"
        @test eval_expr(parse_expr(expr_str)) ≈ Meta.eval(Meta.parse(expr_str))
    end

    @testset verbose = true "Bytecode VM" begin
        @testset "VarContext" begin
            ctx = VarContext()
            @test length(ctx) == 0

            idx1 = NumExpr.get_or_create!(ctx, "a")
            @test idx1 == 1
            @test length(ctx) == 1

            idx2 = NumExpr.get_or_create!(ctx, "b")
            @test idx2 == 2
            @test length(ctx) == 2

            # Same name returns same index
            idx1_again = NumExpr.get_or_create!(ctx, "a")
            @test idx1_again == idx1
            @test length(ctx) == 2

            # Indexing by name
            @test ctx["a"] == 1
            @test ctx["b"] == 2

            # Indexing by position
            @test ctx[1] == "a"
            @test ctx[2] == "b"

            # haskey
            @test haskey(ctx, "a")
            @test !haskey(ctx, "z")
        end

        @testset "Compile constants" begin
            ctx = VarContext()

            # Integer constant
            c = compile_expr("42", ctx)
            @test eval_compiled(c, Float64[]) == 42.0

            # Float constant
            c = compile_expr("3.14", ctx)
            @test eval_compiled(c, Float64[]) ≈ 3.14

            # NaN
            c = compile_expr("NaN", ctx)
            @test isnan(eval_compiled(c, Float64[]))

            # Boolean true
            c = compile_expr("true", ctx)
            @test eval_compiled(c, Float64[]) == 1.0

            # Boolean false
            c = compile_expr("false", ctx)
            @test eval_compiled(c, Float64[]) == 0.0
        end

        @testset "Compile variables" begin
            ctx = VarContext()
            c = compile_expr("a + b", ctx)
            @test length(ctx) == 2
            values = [3.0, 7.0]
            @test eval_compiled(c, values) == 10.0
        end

        @testset "Arithmetic operations" begin
            ctx = VarContext()
            values = Float64[]

            @test eval_compiled(compile_expr("2 + 3", ctx), values) == 5.0
            @test eval_compiled(compile_expr("10 - 4", ctx), values) == 6.0
            @test eval_compiled(compile_expr("3 * 7", ctx), values) == 21.0
            @test eval_compiled(compile_expr("15 / 3", ctx), values) == 5.0
            @test eval_compiled(compile_expr("2 ^ 10", ctx), values) == 1024.0
            @test eval_compiled(compile_expr("17 % 5", ctx), values) == 2.0
            @test eval_compiled(compile_expr("-5", ctx), values) == -5.0
            @test eval_compiled(compile_expr("+5", ctx), values) == 5.0
        end

        @testset "N-ary flattening" begin
            ctx = VarContext()
            values = Float64[]

            @test eval_compiled(compile_expr("1 + 2 + 3 + 4", ctx), values) == 10.0
            @test eval_compiled(compile_expr("2 * 3 * 4", ctx), values) == 24.0
            @test eval_compiled(compile_expr("100 - 10 - 20 - 30", ctx), values) == 40.0
        end

        @testset "Comparison operations" begin
            ctx = VarContext()
            values = Float64[]

            @test eval_compiled(compile_expr("3 > 2", ctx), values) == 1.0
            @test eval_compiled(compile_expr("2 > 3", ctx), values) == 0.0
            @test eval_compiled(compile_expr("2 < 3", ctx), values) == 1.0
            @test eval_compiled(compile_expr("3 < 2", ctx), values) == 0.0
            @test eval_compiled(compile_expr("3 >= 3", ctx), values) == 1.0
            @test eval_compiled(compile_expr("2 >= 3", ctx), values) == 0.0
            @test eval_compiled(compile_expr("3 <= 3", ctx), values) == 1.0
            @test eval_compiled(compile_expr("4 <= 3", ctx), values) == 0.0
            @test eval_compiled(compile_expr("5 == 5", ctx), values) == 1.0
            @test eval_compiled(compile_expr("5 == 6", ctx), values) == 0.0
            @test eval_compiled(compile_expr("5 != 6", ctx), values) == 1.0
            @test eval_compiled(compile_expr("5 != 5", ctx), values) == 0.0
        end

        @testset "Logical operations" begin
            ctx = VarContext()
            values = Float64[]

            @test eval_compiled(compile_expr("1 && 1", ctx), values) == 1.0
            @test eval_compiled(compile_expr("1 && 0", ctx), values) == 0.0
            @test eval_compiled(compile_expr("0 && 1", ctx), values) == 0.0
            @test eval_compiled(compile_expr("0 || 1", ctx), values) == 1.0
            @test eval_compiled(compile_expr("0 || 0", ctx), values) == 0.0
            @test eval_compiled(compile_expr("1 || 0", ctx), values) == 1.0
        end

        @testset "Math functions" begin
            ctx = VarContext()
            values = Float64[]

            @test eval_compiled(compile_expr("sqrt(4)", ctx), values) == 2.0
            @test eval_compiled(compile_expr("abs(-7)", ctx), values) == 7.0
            @test eval_compiled(compile_expr("sin(0)", ctx), values) == 0.0
            @test eval_compiled(compile_expr("cos(0)", ctx), values) == 1.0
            @test eval_compiled(compile_expr("atan(0)", ctx), values) == 0.0
            @test eval_compiled(compile_expr("exp(0)", ctx), values) == 1.0
            @test eval_compiled(compile_expr("log(1)", ctx), values) == 0.0
        end

        @testset "Complex expressions" begin
            ctx = VarContext()

            # sin^2 + cos^2 = 1
            c = compile_expr("sin(10) ^ 2 + cos(10) ^ 2", ctx)
            @test eval_compiled(c, Float64[]) ≈ 1.0

            # Nested functions
            c = compile_expr("sqrt(abs(-16))", ctx)
            @test eval_compiled(c, Float64[]) == 4.0

            # Mixed arithmetic with functions
            ctx2 = VarContext()
            c = compile_expr("a + b * sin(c)", ctx2)
            values = zeros(Float64, length(ctx2))
            values[1] = 1.0  # a
            values[2] = 2.0  # b
            values[3] = 0.0  # c (sin(0) = 0)
            @test eval_compiled(c, values) == 1.0

            values[3] = pi / 2  # sin(pi/2) = 1
            @test eval_compiled(c, values) ≈ 3.0

            # Deeply nested
            c = compile_expr("((1 + 2) * (3 - 4) + (5 * 6)) / ((7 - 8) * (9 + 10) + 11)", ctx)
            @test eval_compiled(c, Float64[]) ≈ eval_expr(parse_expr("((1 + 2) * (3 - 4) + (5 * 6)) / ((7 - 8) * (9 + 10) + 11)"))
        end

        @testset "Correctness vs tree eval" begin
            numeric_exprs = [
                "1 + 2",
                "3 * 4 + 5",
                "10 - 3 * 2",
                "2 ^ 3 ^ 2",
                "(1 + 2) * 3",
                "1 + 2 + 3 + 4 + 5",
                "10 / 2 / 5",
                "sin(1)",
                "cos(0)",
                "sqrt(16)",
                "abs(-42)",
                "exp(1)",
                "log(1)",
                "atan(1)",
                "sin(1) ^ 2 + cos(1) ^ 2",
                "-5 + 3",
                "-(1 + 2)",
                "1 + 2 * 3 + 4",
                "2 ^ 10",
                "1.5 + 2.5",
                "1e2 + 1",
                "sqrt(abs(-9))",
                "3 > 2",
                "2 < 3",
                "5 == 5",
                "5 != 6",
                "3 >= 3",
                "2 <= 3",
                "true",
                "false",
                "1 + 2 + 3 + 4 + 5 + 6 + 7 + 8 + 9 + 10",
                "2 * 3 * 4 * 5",
            ]

            for expr_str in numeric_exprs
                tree_result = eval_expr(parse_expr(expr_str))
                ctx = VarContext()
                compiled = compile_expr(expr_str, ctx)
                vm_result = eval_compiled(compiled, Float64[])
                if isnan(tree_result)
                    @test isnan(vm_result)
                elseif tree_result isa Bool
                    @test vm_result == Float64(tree_result)
                else
                    @test vm_result ≈ Float64(tree_result) atol = 1e-10
                end
            end
        end

        @testset "Resolver function" begin
            ctx = VarContext()
            c = compile_expr("a + b * 2", ctx)
            result = eval_compiled(c, idx -> idx == 1 ? 10.0 : 20.0)
            @test result == 50.0
        end

        @testset "Shared VarContext" begin
            ctx = VarContext()
            c1 = compile_expr("a + b", ctx)
            c2 = compile_expr("b * c", ctx)
            c3 = compile_expr("a + c", ctx)
            @test length(ctx) == 3  # a, b, c

            values = [1.0, 2.0, 3.0]
            @test eval_compiled(c1, values) == 3.0   # 1 + 2
            @test eval_compiled(c2, values) == 6.0   # 2 * 3
            @test eval_compiled(c3, values) == 4.0   # 1 + 3
        end

        @testset "Pre-allocated stack" begin
            ctx = VarContext()
            c = compile_expr("1 + 2 * 3", ctx)
            stack = Vector{Float64}(undef, c.max_stack)
            @test eval_compiled(c, Float64[], stack) == 7.0
            # Reuse stack
            @test eval_compiled(c, Float64[], stack) == 7.0
        end

        @testset "String operations rejected" begin
            ctx = VarContext()
            @test_throws ErrorException compile_expr("'hello' * 'world'", ctx)
        end

        @testset "Memory compactness" begin
            ctx = VarContext()
            compiled = compile_expr("a + b * sin(c)", ctx)
            @test sizeof(compiled.code) + sizeof(compiled.constants) < 100
        end

        @testset "Zero allocations" begin
            ctx = VarContext()
            c = compile_expr("a + b * c", ctx)
            values = [1.0, 2.0, 3.0]
            stack = Vector{Float64}(undef, c.max_stack)
            function measure_allocs(c, values, stack)
                for _ in 1:5
                    eval_compiled(c, values, stack)
                end
                return @allocated eval_compiled(c, values, stack)
            end
            allocs = measure_allocs(c, values, stack)
            @test allocs == 0
        end

        @testset "Tagged variables" begin
            ctx = VarContext()
            c = compile_expr("price{store='ny'} + tax[state='nys']", ctx)
            @test length(ctx) == 2
            values = [100.0, 8.0]
            @test eval_compiled(c, values) == 108.0
        end

        @testset "Bytecode structure" begin
            ctx = VarContext()

            # Simple constant
            c = compile_expr("42", ctx)
            @test c.code[1] == NumExpr.OP_LOAD_CONST
            @test c.max_stack == 1
            @test length(c.constants) == 1
            @test c.constants[1] == 42.0

            # Simple addition
            c = compile_expr("1 + 2", ctx)
            @test c.max_stack == 2

            # NaN
            c = compile_expr("NaN", ctx)
            @test c.code[1] == NumExpr.OP_LOAD_NAN

            # true / false
            c = compile_expr("true", ctx)
            @test c.code[1] == NumExpr.OP_LOAD_TRUE

            c = compile_expr("false", ctx)
            @test c.code[1] == NumExpr.OP_LOAD_FALSE
        end

        @testset "Compile from ExprNode" begin
            ctx = VarContext()
            node = parse_expr("1 + 2 * 3")
            c = compile_expr(node, ctx)
            @test eval_compiled(c, Float64[]) == 7.0
        end

        @testset "Stress: many formulas" begin
            ctx = VarContext()
            formulas = NumExpr.CompiledExpr[]
            for i in 1:1000
                a = rand()
                b = rand()
                push!(formulas, compile_expr("$a + $b", ctx))
            end
            @test length(formulas) == 1000
            for (i, f) in enumerate(formulas)
                result = eval_compiled(f, Float64[])
                @test isfinite(result)
            end
        end

        @testset "Named values convenience" begin
            ctx = VarContext()
            c = compile_expr("price + tax * quantity", ctx)
            @test eval_compiled(c, ctx, "price" => 100.0, "tax" => 8.0, "quantity" => 5.0) == 140.0
        end

        @testset "VarContext indexing workflow" begin
            ctx = VarContext()
            f = compile_expr("bid * qty + ask * qty", ctx)
            values = zeros(Float64, length(ctx))
            values[ctx["bid"]] = 10.0
            values[ctx["qty"]] = 5.0
            values[ctx["ask"]] = 12.0
            @test eval_compiled(f, values) == 110.0
        end

        @testset "Edge cases" begin
            ctx = VarContext()
            values = Float64[]

            # Division by zero
            c = compile_expr("1 / 0", ctx)
            @test eval_compiled(c, values) == Inf

            # Negative division by zero
            c = compile_expr("-1 / 0", ctx)
            @test eval_compiled(c, values) == -Inf

            # 0/0 = NaN
            c = compile_expr("0 / 0", ctx)
            @test isnan(eval_compiled(c, values))

            # Large exponent
            c = compile_expr("2 ^ 100", ctx)
            @test eval_compiled(c, values) == 2.0^100

            # Scientific notation
            c = compile_expr("1e10 + 1e10", ctx)
            @test eval_compiled(c, values) == 2e10
        end

        @testset "Extended unary opcodes" begin
            ctx = VarContext()
            values = Float64[]

            # isnan
            c = compile_expr("isnan(NaN)", ctx)
            @test eval_compiled(c, values) == 1.0
            c = compile_expr("isnan(42)", ctx)
            @test eval_compiled(c, values) == 0.0

            # not
            c = compile_expr("not(true)", ctx)
            @test eval_compiled(c, values) == 0.0
            c = compile_expr("not(false)", ctx)
            @test eval_compiled(c, values) == 1.0
            c = compile_expr("not(NaN)", ctx)
            @test isnan(eval_compiled(c, values))

            # iszero
            c = compile_expr("iszero(0)", ctx)
            @test eval_compiled(c, values) == 1.0
            c = compile_expr("iszero(5)", ctx)
            @test eval_compiled(c, values) == 0.0

            # isone
            c = compile_expr("isone(1)", ctx)
            @test eval_compiled(c, values) == 1.0
            c = compile_expr("isone(0)", ctx)
            @test eval_compiled(c, values) == 0.0

            # floor
            c = compile_expr("floor(3.7)", ctx)
            @test eval_compiled(c, values) == 3.0
            c = compile_expr("floor(-2.3)", ctx)
            @test eval_compiled(c, values) == -3.0

            # ceil
            c = compile_expr("ceil(3.2)", ctx)
            @test eval_compiled(c, values) == 4.0
            c = compile_expr("ceil(-2.8)", ctx)
            @test eval_compiled(c, values) == -2.0
        end

        @testset "Extended binary/ternary opcodes" begin
            ctx = VarContext()
            values = Float64[]

            # max (binary)
            c = compile_expr("max(3, 7)", ctx)
            @test eval_compiled(c, values) == 7.0
            c = compile_expr("max(10, 2)", ctx)
            @test eval_compiled(c, values) == 10.0

            # min (binary)
            c = compile_expr("min(3, 7)", ctx)
            @test eval_compiled(c, values) == 3.0
            c = compile_expr("min(10, 2)", ctx)
            @test eval_compiled(c, values) == 2.0

            # ifelse (ternary)
            c = compile_expr("ifelse(true, 10, 20)", ctx)
            @test eval_compiled(c, values) == 10.0
            c = compile_expr("ifelse(false, 10, 20)", ctx)
            @test eval_compiled(c, values) == 20.0

            # get (binary: isnan(a) ? b : a)
            c = compile_expr("get(NaN, 42)", ctx)
            @test eval_compiled(c, values) == 42.0
            c = compile_expr("get(7, 42)", ctx)
            @test eval_compiled(c, values) == 7.0

            # round (binary)
            c = compile_expr("round(3.456, 2)", ctx)
            @test eval_compiled(c, values) ≈ 3.46
            c = compile_expr("round(3.456, 0)", ctx)
            @test eval_compiled(c, values) == 3.0

            # isless (binary)
            c = compile_expr("isless(2, 3)", ctx)
            @test eval_compiled(c, values) == 1.0
            c = compile_expr("isless(3, 2)", ctx)
            @test eval_compiled(c, values) == 0.0
            c = compile_expr("isless(NaN, 1)", ctx)
            @test eval_compiled(c, values) == 0.0

            # div (binary: integer division)
            c = compile_expr("div(17, 5)", ctx)
            @test eval_compiled(c, values) == 3.0
            c = compile_expr("div(10, 3)", ctx)
            @test eval_compiled(c, values) == 3.0
        end

        @testset "Extended opcodes with variables" begin
            ctx = VarContext()
            c = compile_expr("ifelse(a > 0, a * 2, get(a, b))", ctx)
            @test length(ctx) == 2

            # a=5, b=10 → a>0 → a*2 = 10
            vals = [5.0, 10.0]
            @test eval_compiled(c, vals) == 10.0

            # a=NaN, b=10 → a>0 is false → get(NaN,10) = 10
            vals = [NaN, 10.0]
            @test eval_compiled(c, vals) == 10.0

            # max/min with vars
            c2 = compile_expr("max(a, b) - min(a, b)", ctx)
            vals = [3.0, 7.0]
            @test eval_compiled(c2, vals) == 4.0
        end

        @testset "Extended opcodes correctness vs tree eval" begin
            test_cases = [
                "isnan(NaN)",
                "isnan(1)",
                "not(true)",
                "not(false)",
                "iszero(0)",
                "iszero(1)",
                "isone(1)",
                "isone(0)",
                "floor(3.7)",
                "ceil(3.2)",
                "max(5, 10)",
                "min(5, 10)",
                "ifelse(true, 1, 2)",
                "ifelse(false, 1, 2)",
                "get(NaN, 42)",
                "get(7, 42)",
                "round(3.456, 2)",
                "div(17, 5)",
                "tg(0)",
                "tg(1)",
                "ctg(1)",
                "mean(2, 4, 6)",
                "mean(10)",
                "mean(1, 2, 3, 4, 5)",
            ]
            for expr_str in test_cases
                tree_result = eval_expr(parse_expr(expr_str))
                ctx = VarContext()
                compiled = compile_expr(expr_str, ctx)
                vm_result = eval_compiled(compiled, Float64[])
                if isnan(tree_result)
                    @test isnan(vm_result)
                else
                    @test vm_result ≈ Float64(tree_result) atol=1e-10
                end
            end
        end

        @testset "tg / ctg opcodes" begin
            ctx = VarContext()
            c = compile_expr("tg(x)", ctx)
            @test eval_compiled(c, [0.0]) == 0.0
            @test eval_compiled(c, [1.0]) ≈ tan(1.0)
            @test eval_compiled(c, [Float64(π)/4]) ≈ 1.0

            c2 = compile_expr("ctg(x)", ctx)
            @test eval_compiled(c2, [Float64(π)/4]) ≈ 1.0
            @test eval_compiled(c2, [1.0]) ≈ cos(1.0) / sin(1.0)
            @test eval_compiled(c2, [Float64(π)/2]) ≈ 0.0 atol=1e-15

            # Combined expression
            c3 = compile_expr("tg(x) * ctg(x)", ctx)
            @test eval_compiled(c3, [1.0]) ≈ 1.0
            @test eval_compiled(c3, [0.5]) ≈ 1.0
        end

        @testset "mean opcode" begin
            ctx = VarContext()

            # Constants only
            c = compile_expr("mean(2, 4, 6)", ctx)
            @test eval_compiled(c, Float64[]) == 4.0

            c2 = compile_expr("mean(10)", ctx)
            @test eval_compiled(c2, Float64[]) == 10.0

            c3 = compile_expr("mean(1, 2, 3, 4, 5)", ctx)
            @test eval_compiled(c3, Float64[]) == 3.0

            # With variables
            c4 = compile_expr("mean(a, b, c)", ctx)
            @test eval_compiled(c4, [2.0, 4.0, 6.0]) == 4.0
            @test eval_compiled(c4, [10.0, 20.0, 30.0]) == 20.0

            # Two args
            c5 = compile_expr("mean(a, b)", ctx)
            @test eval_compiled(c5, [3.0, 7.0, 0.0]) == 5.0

            # In larger expression
            c6 = compile_expr("mean(a, b, c) + 1", ctx)
            @test eval_compiled(c6, [2.0, 4.0, 6.0]) == 5.0
        end

        @testset "calendar opcodes" begin
            ctx = VarContext()
            cms  = compile_expr("millisecond(t)", ctx)
            cs   = compile_expr("second(t)", ctx)
            cmi  = compile_expr("minute(t)", ctx)
            ch   = compile_expr("hour(t)", ctx)
            cd   = compile_expr("dayofmonth(t)", ctx)
            cmo  = compile_expr("month(t)", ctx)
            cy   = compile_expr("year(t)", ctx)

            dts = [
                DateTime(2026, 7, 11, 15, 42, 7, 123),
                DateTime(2024, 2, 29, 23, 59, 59, 999),  # leap day
                DateTime(2000, 3, 1, 0, 0, 0, 1),
                DateTime(1970, 1, 1, 0, 0, 0, 0),
                DateTime(1969, 12, 31, 23, 59, 59, 500), # pre-epoch
                DateTime(1900, 2, 28, 12, 30, 45, 250),  # non-leap century
            ]
            for dt in dts
                # exact ns timestamp with a sub-ms offset: exact ms boundaries
                # fall within Float64 register precision (~hundreds of ns)
                ns = Dates.value(dt - DateTime(1970, 1, 1)) * 1_000_000 + 456_789
                v = [Float64(ns)]
                @test eval_compiled(cy,  v) == Dates.year(dt)
                @test eval_compiled(cmo, v) == Dates.month(dt)
                @test eval_compiled(cd,  v) == Dates.day(dt)
                @test eval_compiled(ch,  v) == Dates.hour(dt)
                @test eval_compiled(cmi, v) == Dates.minute(dt)
                @test eval_compiled(cs,  v) == Dates.second(dt)
                @test eval_compiled(cms, v) == Dates.millisecond(dt)
            end

            # NaN propagates
            for c in (cms, cs, cmi, ch, cd, cmo, cy)
                @test isnan(eval_compiled(c, [NaN]))
            end

            # in a larger expression
            cexpr = compile_expr("year(t) * 100 + month(t)", ctx)
            ns = Dates.value(DateTime(2026, 7, 11) - DateTime(1970, 1, 1)) * 1_000_000
            @test eval_compiled(cexpr, [Float64(ns)]) == 202607.0

            # zero allocations
            stack = Vector{Float64}(undef, cy.max_stack)
            vals = [1.0e18]
            function measure_calendar_allocs(c, values, stack)
                for _ in 1:5
                    eval_compiled(c, values, stack)
                end
                return @allocated eval_compiled(c, values, stack)
            end
            @test measure_calendar_allocs(cy, vals, stack) == 0
        end

        @testset "Callable resolver (functor)" begin
            ctx = VarContext()
            c = compile_expr("a + b * 2", ctx)

            # Functor (callable struct)
            struct TestResolver
                data::Vector{Float64}
            end
            (r::TestResolver)(idx::Int) = r.data[idx]

            resolver = TestResolver([3.0, 4.0])
            @test eval_compiled(c, resolver) == 11.0

            # Regular function still works
            @test eval_compiled(c, idx -> [3.0, 4.0][idx]) == 11.0
        end

        @testset "VarContext sizehint" begin
            ctx = VarContext(; sizehint = 10)
            @test length(ctx) == 0

            c = compile_expr("a + b", ctx)
            @test length(ctx) == 2
            @test ctx["a"] == 1
            @test ctx["b"] == 2
            @test eval_compiled(c, [1.0, 2.0]) == 3.0
        end

        @testset "Constant pool overflow check" begin
            ctx = VarContext()
            # Build an expression with more than 65535 distinct constants.
            # 0.0 and 1.0 are emitted as immediate opcodes and don't consume the pool,
            # so start at 2 to make sure the pool actually overflows.
            parts = [string(Float64(i)) for i in 2:65538]
            huge_expr = join(parts, " + ")
            @test_throws ErrorException compile_expr(huge_expr, ctx)
        end

        @testset "rem opcode" begin
            ctx = VarContext()
            @test eval_compiled(compile_expr("rem(7, 3)", ctx), Float64[]) == rem(7.0, 3.0)
            @test eval_compiled(compile_expr("rem(-7, 3)", ctx), Float64[]) == rem(-7.0, 3.0)
            @test eval_compiled(compile_expr("rem(7.5, 2.0)", ctx), Float64[]) == rem(7.5, 2.0)

            # tree and VM agree
            for s in ("rem(10, 3)", "rem(-10, 3)", "rem(10, -3)", "rem(7.5, 2.0)")
                @test eval_expr(parse_expr(s)) == eval_compiled(compile_expr(s, VarContext()), Float64[])
            end
        end

        @testset "Load-immediate opcodes for 0 and 1" begin
            ctx = VarContext()

            c0 = compile_expr("0", ctx)
            @test c0.code[1] == NumExpr.OP_LOAD_ZERO
            @test isempty(c0.constants)
            @test eval_compiled(c0, Float64[]) == 0.0

            c1 = compile_expr("1", ctx)
            @test c1.code[1] == NumExpr.OP_LOAD_ONE
            @test isempty(c1.constants)
            @test eval_compiled(c1, Float64[]) == 1.0

            # 0.0 and 1.0 stay out of the constant pool when used in larger exprs
            c2 = compile_expr("a + 1 + 0", ctx)
            @test isempty(c2.constants)

            # Other literals still go through the constant pool
            c3 = compile_expr("2", VarContext())
            @test c3.code[1] == NumExpr.OP_LOAD_CONST
            @test c3.constants == [2.0]

            # -0.0 is NOT folded: parser produces unary-minus over 0.0,
            # so we get OP_LOAD_ZERO + OP_NEG → -0.0
            c4 = compile_expr("-0", VarContext())
            @test eval_compiled(c4, Float64[]) === -0.0
        end

        @testset "Unsupported function clean error" begin
            ctx = VarContext()
            err1 = try; compile_expr("foo(1)", ctx); nothing; catch e; e; end
            @test err1 isa ErrorException
            @test occursin("compiled mode does not support", err1.msg)
            @test occursin("foo", err1.msg)

            @test_throws ErrorException compile_expr("mod(7, 3)", VarContext())
            @test_throws ErrorException compile_expr("xor(1, 0)", VarContext())
        end

        @testset "Function arity errors" begin
            ctx = VarContext()
            @test_throws ErrorException compile_expr("max(1, 2, 3)", ctx)
            @test_throws ErrorException compile_expr("min(1, 2, 3)", ctx)
            @test_throws ErrorException compile_expr("ifelse(1)", ctx)
            @test_throws ErrorException compile_expr("ifelse(1, 2)", ctx)
            @test_throws ErrorException compile_expr("ifelse(1, 2, 3, 4)", ctx)
            @test_throws ErrorException compile_expr("get(1)", ctx)
            @test_throws ErrorException compile_expr("rem(1, 2, 3)", ctx)
            @test_throws ErrorException compile_expr("sqrt(1, 2)", ctx)
            @test_throws ErrorException compile_expr("mean()", ctx)
        end

        @testset "ifelse / not truthy semantics" begin
            ctx = VarContext()

            # Any non-zero, non-NaN condition is "true" for ifelse
            @test eval_compiled(compile_expr("ifelse(2, 10, 20)", ctx), Float64[]) == 10.0
            @test eval_compiled(compile_expr("ifelse(-1, 10, 20)", ctx), Float64[]) == 10.0
            @test eval_compiled(compile_expr("ifelse(0.5, 10, 20)", ctx), Float64[]) == 10.0
            @test eval_compiled(compile_expr("ifelse(0, 10, 20)", ctx), Float64[]) == 20.0
            @test isnan(eval_compiled(compile_expr("ifelse(NaN, 10, 20)", ctx), Float64[]))

            # not: any non-zero non-NaN → 0; zero → 1; NaN → NaN
            @test eval_compiled(compile_expr("not(0)", ctx), Float64[]) == 1.0
            @test eval_compiled(compile_expr("not(5)", ctx), Float64[]) == 0.0
            @test eval_compiled(compile_expr("not(-2)", ctx), Float64[]) == 0.0
            @test isnan(eval_compiled(compile_expr("not(NaN)", ctx), Float64[]))

            # Tree-walk and VM agree on the new semantics
            for s in (
                "ifelse(2, 10, 20)", "ifelse(-3, 10, 20)", "ifelse(0, 10, 20)",
                "not(0)", "not(7)", "not(-1)",
            )
                tree = eval_expr(parse_expr(s))
                vm   = eval_compiled(compile_expr(s, VarContext()), Float64[])
                @test tree == vm
            end
            for s in ("ifelse(NaN, 10, 20)", "not(NaN)")
                @test isnan(eval_expr(parse_expr(s)))
                @test isnan(eval_compiled(compile_expr(s, VarContext()), Float64[]))
            end
        end
    end

    @testset verbose = true "Variable tags" begin
        # Tag-less variable (format1) has nothing tags
        v = parse_expr("abc")
        @test v.tags === nothing
        @test !var_has_tags(v)
        @test NumExpr.var_tags(v) == Dict{String,String}()

        # Tagged variable (format2) has real tags
        v2 = parse_expr("abc{key='val'}")
        @test v2.tags !== nothing
        @test var_has_tags(v2)
        @test NumExpr.var_tags(v2) == Dict("key" => "val")

        # Global tag-less
        v3 = parse_expr("[myvar]")
        @test v3.tags === nothing
        @test !var_has_tags(v3)
    end
end
