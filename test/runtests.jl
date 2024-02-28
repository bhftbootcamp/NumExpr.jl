using Test
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
        @test isempty(parsed_local.tags)
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
end
