-- Binary Template plugin for REHex
-- Copyright (C) 2021-2022 Daniel Collins <solemnwarning@solemnwarning.net>
--
-- This program is free software; you can redistribute it and/or modify it
-- under the terms of the GNU General Public License version 2 as published by
-- the Free Software Foundation.
--
-- This program is distributed in the hope that it will be useful, but WITHOUT
-- ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
-- FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
-- more details.
--
-- You should have received a copy of the GNU General Public License along with
-- this program; if not, write to the Free Software Foundation, Inc., 51
-- Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

local parser = require 'parser'

describe("parser", function()
	it("parses numbers", function()
		assert.are.same({ { "UNKNOWN FILE", 1, "num", 1 } }, parser.parse_text("1;"));
		assert.are.same({ { "UNKNOWN FILE", 1, "num", 1 } }, parser.parse_text("1.0;"));
		assert.are.same({ { "UNKNOWN FILE", 1, "num", 1.5 } }, parser.parse_text("1.5;"));
		assert.are.same({ { "UNKNOWN FILE", 1, "minus", { "UNKNOWN FILE", 1, "num", 1 } } }, parser.parse_text("-1;"));
		assert.are.same({ { "UNKNOWN FILE", 1, "plus", { "UNKNOWN FILE", 1, "num", 1 } } }, parser.parse_text("+1;"));
	end);
	
	it("parses strings", function()
		local got
		local expect
		
		got = parser.parse_text('"foo";')
		expect = { { "UNKNOWN FILE", 1, "str", "foo" } }
		assert.are.same(expect, got)
		
		got = parser.parse_text("\"string \\r\\n with \\\\ escape \\\"\\\' characters\\0\";")
		expect = { { "UNKNOWN FILE", 1, "str", "string \r\n with \\ escape \"\' characters\0" } }
		assert.are.same(expect, got)
		
		got = parser.parse_text('"\\1111 <-- octal sequence";')
		expect = { { "UNKNOWN FILE", 1, "str", string.char(0x49) .. "1 <-- octal sequence" } }
		assert.are.same(expect, got)
		
		got = parser.parse_text('"\\x00\\x01\\xFF0 <-- hex sequence";')
		expect = { { "UNKNOWN FILE", 1, "str", string.char(0x00) .. string.char(0x01) .. string.char(0xFF) .. "0 <-- hex sequence" } }
		assert.are.same(expect, got)
	end)
	
	it("parses a function call", function()
		assert.are.same({ { "UNKNOWN FILE", 1, "call", "testfunc", {} } }, parser.parse_text("testfunc();"));
		assert.are.same({ { "UNKNOWN FILE", 1, "call", "testfunc", { { "UNKNOWN FILE", 1, "num", 1 } } } }, parser.parse_text("testfunc(1);"));
		assert.are.same({ { "UNKNOWN FILE", 1, "call", "testfunc", { { "UNKNOWN FILE", 1, "ref", { "i" } } } } }, parser.parse_text("testfunc(i);"));
	end);
	
	it("parses variable refs", function()
		local got
		local expect
		
		got = parser.parse_text("foo;")
		expect = { { "UNKNOWN FILE", 1, "ref", { "foo" } } }
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("foo[0];")
		expect = { { "UNKNOWN FILE", 1, "ref", {
			"foo",
			{ "UNKNOWN FILE", 1, "num", 0 },
		} } }
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("foo.bar;")
		expect = { { "UNKNOWN FILE", 1, "ref", {
			"foo",
			"bar",
		} } }
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("foo[0].bar;")
		expect = { { "UNKNOWN FILE", 1, "ref", {
			"foo",
			{ "UNKNOWN FILE", 1, "num", 0 },
			"bar",
		} } }
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("foo[0].bar[10];")
		expect = { { "UNKNOWN FILE", 1, "ref", {
			"foo",
			{ "UNKNOWN FILE", 1, "num", 0 },
			"bar",
			{ "UNKNOWN FILE", 1, "num", 10 },
		} } }
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("foo[0].bar[10].baz;")
		expect = { { "UNKNOWN FILE", 1, "ref", {
			"foo",
			{ "UNKNOWN FILE", 1, "num", 0 },
			"bar",
			{ "UNKNOWN FILE", 1, "num", 10 },
			"baz",
		} } }
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("foo[0].bar[baz];")
		expect = { { "UNKNOWN FILE", 1, "ref", {
			"foo",
			{ "UNKNOWN FILE", 1, "num", 0 },
			"bar",
			{ "UNKNOWN FILE", 1, "ref", { "baz" } },
		} } }
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("foo[1+1];")
		expect = { { "UNKNOWN FILE", 1, "ref", {
			"foo",
			{ "UNKNOWN FILE", 1, "add",
				{ "UNKNOWN FILE", 1, "num", 1 },
				{ "UNKNOWN FILE", 1, "num", 1 } },
		} } }
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("foo[bar.baz];")
		expect = { { "UNKNOWN FILE", 1, "ref", {
			"foo",
			{ "UNKNOWN FILE", 1, "ref", {
				"bar",
				"baz" } },
		} } }
		
		assert.are.same(expect, got)
	end);
	
	it("parses arithmetic expressions", function()
		local got
		local expect
		
		got = parser.parse_text("1 + 2 * 3 - 4 / 5 + 6;")
		
		-- (((1 + (2 * 3)) - (4 / 5)) + 6)
		expect = {
			{ "UNKNOWN FILE", 1, "add",
				{ "UNKNOWN FILE", 1, "subtract",
					{ "UNKNOWN FILE", 1, "add",
						{ "UNKNOWN FILE", 1, "num", 1 },
						{ "UNKNOWN FILE", 1, "multiply",
							{ "UNKNOWN FILE", 1, "num", 2 },
							{ "UNKNOWN FILE", 1, "num", 3 },
						},
					},
					{ "UNKNOWN FILE", 1, "divide",
						{ "UNKNOWN FILE", 1, "num", 4 },
						{ "UNKNOWN FILE", 1, "num", 5 },
					},
				},
				{ "UNKNOWN FILE", 1, "num", 6 }
			},
		}
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("(1 + 2) * (3 - 4) / (5 + 6);")
		
		-- (((1 + 2) * (3 - 4)) / (5 + 6))
		expect = {
			{ "UNKNOWN FILE", 1, "divide",
				{ "UNKNOWN FILE", 1, "multiply",
					{ "UNKNOWN FILE", 1, "add",
						{ "UNKNOWN FILE", 1, "num", 1 },
						{ "UNKNOWN FILE", 1, "num", 2 },
					},
					{ "UNKNOWN FILE", 1, "subtract",
						{ "UNKNOWN FILE", 1, "num", 3 },
						{ "UNKNOWN FILE", 1, "num", 4 },
					},
				},
				{ "UNKNOWN FILE", 1, "add",
					{ "UNKNOWN FILE", 1, "num", 5 },
					{ "UNKNOWN FILE", 1, "num", 6 },
				},
			},
		};
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("((1 + 2) * ((3 - 4) / (5 + 6)));");
		expect = {
			{ "UNKNOWN FILE", 1, "multiply",
				{ "UNKNOWN FILE", 1, "add",
					{ "UNKNOWN FILE", 1, "num", 1 },
					{ "UNKNOWN FILE", 1, "num", 2 },
				},
				{ "UNKNOWN FILE", 1, "divide",
					{ "UNKNOWN FILE", 1, "subtract",
						{ "UNKNOWN FILE", 1, "num", 3 },
						{ "UNKNOWN FILE", 1, "num", 4 },
					},
					{ "UNKNOWN FILE", 1, "add",
						{ "UNKNOWN FILE", 1, "num", 5 },
						{ "UNKNOWN FILE", 1, "num", 6 },
					},
				},
			},
		}
		
		assert.are.same(expect, got)
	end);
	
	it("parses prefix increment", function()
		local got
		local expect
		
		got = parser.parse_text("++i;")
		expect = {
			{ "UNKNOWN FILE", 1, "assign",
				{ "UNKNOWN FILE", 1, "ref", { "i" } },
				{ "UNKNOWN FILE", 1, "add",
					{ "UNKNOWN FILE", 1, "ref", { "i" } },
					{ "UNKNOWN FILE", 1, "num", 1 } } },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses prefix decrement", function()
		local got
		local expect
		
		got = parser.parse_text("--i;")
		expect = {
			{ "UNKNOWN FILE", 1, "assign",
				{ "UNKNOWN FILE", 1, "ref", { "i" } },
				{ "UNKNOWN FILE", 1, "subtract",
					{ "UNKNOWN FILE", 1, "ref", { "i" } },
					{ "UNKNOWN FILE", 1, "num", 1 } } },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses postfix increment", function()
		local got
		local expect
		
		got = parser.parse_text("i++;")
		expect = {
			{ "UNKNOWN FILE", 1, "postfix-increment",
				{ "UNKNOWN FILE", 1, "ref", { "i" } } },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses postfix decrement", function()
		local got
		local expect
		
		got = parser.parse_text("i--;")
		expect = {
			{ "UNKNOWN FILE", 1, "postfix-decrement",
				{ "UNKNOWN FILE", 1, "ref", { "i" } } },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses variable definitions", function()
		assert.are.same({ { "UNKNOWN FILE", 1, "variable", "int", "var", nil, nil } }, parser.parse_text("int var;"));
		assert.are.same({ { "UNKNOWN FILE", 1, "variable", "int", "array", nil, { "UNKNOWN FILE", 1, "num", 10 } } }, parser.parse_text("int array[10];"));
		
		assert.are.same({ { "UNKNOWN FILE", 1, "variable", "struct foo", "bar", nil, nil } }, parser.parse_text("struct foo bar;"));
		assert.are.same({ { "UNKNOWN FILE", 1, "variable", "struct baz", "qux", nil, { "UNKNOWN FILE", 1, "num", 10 } } }, parser.parse_text("struct baz qux[10];"));
	end);
	
	it("parses struct variable definitions with parameters", function()
		local got
		local expect
		
		got = parser.parse_text("struct foo bar(1);")
		expect = {
			{ "UNKNOWN FILE", 1, "variable", "struct foo", "bar", { { "UNKNOWN FILE", 1, "num", 1 } }, nil, nil },
		}
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("struct foo bar(1, 2, 3);")
		expect = {
			{ "UNKNOWN FILE", 1, "variable", "struct foo", "bar", { { "UNKNOWN FILE", 1, "num", 1 }, { "UNKNOWN FILE", 1, "num", 2 }, { "UNKNOWN FILE", 1, "num", 3 } }, nil, nil },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses local variable definitions", function()
		local got;
		local expect;
		
		got = parser.parse_text("local int var;");
		expect = {
			{ "UNKNOWN FILE", 1, "local-variable", "int", "var", nil, nil, nil },
		};
		
		assert.are.same(expect, got);
		
		got = parser.parse_text("local int array[10];");
		expect = {
			{ "UNKNOWN FILE", 1, "local-variable", "int", "array", nil, { "UNKNOWN FILE", 1, "num", 10 }, nil },
		};
		
		assert.are.same(expect, got);
		
		got = parser.parse_text("local int foo = 0;");
		expect = {
			{ "UNKNOWN FILE", 1, "local-variable", "int", "foo", nil, nil, { "UNKNOWN FILE", 1, "num", 0 } },
		};
		
		assert.are.same(expect, got);
		
		got = parser.parse_text("local int &foo = bar;");
		expect = {
			{ "UNKNOWN FILE", 1, "local-variable", "int &", "foo", nil, nil, { "UNKNOWN FILE", 1, "ref", { "bar" } } },
		};
		
		assert.are.same(expect, got);
		
		got = parser.parse_text("local const   int& foo = bar;");
		expect = {
			{ "UNKNOWN FILE", 1, "local-variable", "const int &", "foo", nil, nil, { "UNKNOWN FILE", 1, "ref", { "bar" } } },
		};
		
		assert.are.same(expect, got);
	end);
	
	it("parses local struct variable definitions with parameters", function()
		local got
		local expect
		
		got = parser.parse_text("local struct foo bar(1);")
		expect = {
			{ "UNKNOWN FILE", 1, "local-variable", "struct foo", "bar", { { "UNKNOWN FILE", 1, "num", 1 } }, nil, nil },
		}
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("local struct foo bar(1, 2, 3);")
		expect = {
			{ "UNKNOWN FILE", 1, "local-variable", "struct foo", "bar", { { "UNKNOWN FILE", 1, "num", 1 }, { "UNKNOWN FILE", 1, "num", 2 }, { "UNKNOWN FILE", 1, "num", 3 } }, nil, nil },
		}
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("local struct foo bar(1) = 1;")
		expect = {
			{ "UNKNOWN FILE", 1, "local-variable", "struct foo", "bar", { { "UNKNOWN FILE", 1, "num", 1 } }, nil, { "UNKNOWN FILE", 1, "num", 1 } },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses an empty struct", function()
		local got = parser.parse_text("struct mystruct{};")
		
		local expect = {
			{ "UNKNOWN FILE", 1, "struct", "mystruct", {}, {}, nil },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses a struct with some members", function()
		local got = parser.parse_text("struct mystruct {\nint x;\nint y;\nint xyz[3];\n};")
		
		local expect = {
			{ "UNKNOWN FILE", 1, "struct", "mystruct", {},
			{
				{ "UNKNOWN FILE", 2, "variable", "int", "x", nil, nil },
				{ "UNKNOWN FILE", 3, "variable", "int", "y", nil, nil },
				{ "UNKNOWN FILE", 4, "variable", "int", "xyz", nil, { "UNKNOWN FILE", 4, "num", 3 } },
			}, nil },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses a struct with an empty argument list", function()
		local got = parser.parse_text("struct mystruct() {\nint x;\nint y;\n};")
		
		local expect = {
			{ "UNKNOWN FILE", 1, "struct", "mystruct", {},
			{
				{ "UNKNOWN FILE", 2, "variable", "int", "x", nil, nil },
				{ "UNKNOWN FILE", 3, "variable", "int", "y", nil, nil },
			}, nil },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses a struct with an argument list", function()
		local got = parser.parse_text("struct mystruct(int a, int b) {\nint x;\nint y;\n};")
		
		local expect = {
			{ "UNKNOWN FILE", 1, "struct", "mystruct",
			{
				{ "int", "a" },
				{ "int", "b" },
			},
			{
				{ "UNKNOWN FILE", 2, "variable", "int", "x", nil, nil },
				{ "UNKNOWN FILE", 3, "variable", "int", "y", nil, nil },
			}, nil },
		};
		
		assert.are.same(expect, got)
	end)
	
	it("parses a combined typedef and struct definition", function()
		local got = parser.parse_text("typedef struct mystruct {\nint x;\nint y;\n} mystruct_t;")
		
		local expect = {
			{ "UNKNOWN FILE", 1, "struct", "mystruct", {},
			{
				{ "UNKNOWN FILE", 2, "variable", "int", "x", nil, nil },
				{ "UNKNOWN FILE", 3, "variable", "int", "y", nil, nil },
			}, "mystruct_t" },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses a combined typedef and anonymous struct definition", function()
		local got = parser.parse_text("typedef struct {\nint x;\nint y;\n} mystruct_t;")
		
		local expect = {
			{ "UNKNOWN FILE", 1, "struct", nil, {},
			{
				{ "UNKNOWN FILE", 2, "variable", "int", "x", nil, nil },
				{ "UNKNOWN FILE", 3, "variable", "int", "y", nil, nil },
			}, "mystruct_t" },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses typedefs", function()
		local got = parser.parse_text("typedef struct mystruct mystruct_t;\ntypedef int int_t;\ntypedef int aint_t[4];")
		
		local expect = {
			{ "UNKNOWN FILE", 1, "typedef", "struct mystruct", "mystruct_t", nil },
			{ "UNKNOWN FILE", 2, "typedef", "int", "int_t", nil },
			{ "UNKNOWN FILE", 3, "typedef", "int", "aint_t", { "UNKNOWN FILE", 3, "num", 4 } },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses a function with no arguments or body", function()
		local got = parser.parse_text("int myfunc(){}");
		
		local expect = {
			{ "UNKNOWN FILE", 1, "function", "int", "myfunc", {}, {} },
		};
		
		assert.are.same(expect, got);
	end);
	
	it("parses a function with a body", function()
		local got = parser.parse_text("void myfunc () {\nlocal int i = 0;\notherfunc(1234);\n}\n");
		
		local expect = {
			{ "UNKNOWN FILE", 1, "function", "void", "myfunc", {},
			{
				{ "UNKNOWN FILE", 2, "local-variable", "int", "i", nil, nil, { "UNKNOWN FILE", 2, "num", 0 } },
				{ "UNKNOWN FILE", 3, "call", "otherfunc", { { "UNKNOWN FILE", 3, "num", 1234 } } },
			} },
		};
		
		assert.are.same(expect, got);
	end);
	
	it("parses function definitions with arguments", function()
		local got
		local expect
		
		got = parser.parse_text("void myfunc(int x, int y, int z) {}\n")
		expect = {
			{ "UNKNOWN FILE", 1, "function", "void", "myfunc",
			{
				{ "int", "x" },
				{ "int", "y" },
				{ "int", "z" }
			},
			{} },
		}
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("void myfunc(int &x, int& y, int & z) {}\n")
		expect = {
			{ "UNKNOWN FILE", 1, "function", "void", "myfunc",
			{
				{ "int &", "x" },
				{ "int &", "y" },
				{ "int &", "z" }
			},
			{} },
		}
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("void myfunc(int []x, int[] y, int [] z) {}\n")
		expect = {
			{ "UNKNOWN FILE", 1, "function", "void", "myfunc",
			{
				{ "int []", "x" },
				{ "int []", "y" },
				{ "int []", "z" }
			},
			{} },
		}
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("void myfunc(const  int &x, int[] &y) {}\n")
		expect = {
			{ "UNKNOWN FILE", 1, "function", "void", "myfunc",
			{
				{ "const int &", "x" },
				{ "int [] &", "y" },
			},
			{} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses #file directives", function()
		local got = parser.parse_text("#file foo.bt 10\nint x;\nint y;\n#file bar.bt 1\nint z;\n");
		
		local expect = {
			{ "foo.bt", 10, "variable", "int", "x", nil, nil },
			{ "foo.bt", 11, "variable", "int", "y", nil, nil },
			{ "bar.bt",  1, "variable", "int", "z", nil, nil },
		};
		
		assert.are.same(expect, got);
	end);
	
	it("parses && and || operators", function()
		local got
		local expect
		
		-- 1 && 2 && 3
		
		got = parser.parse_text("1 && 2 && 3;")
		expect = {
			{ "UNKNOWN FILE", 1, "logical-and",
				{ "UNKNOWN FILE", 1, "logical-and",
					{ "UNKNOWN FILE", 1, "num", 1 },
					{ "UNKNOWN FILE", 1, "num", 2 } },
				{ "UNKNOWN FILE", 1, "num", 3 } },
		}
		
		assert.are.same(expect, got)
		
		-- 1 || 2 || 3
		
		got = parser.parse_text("1 || 2 || 3;")
		expect = {
			{ "UNKNOWN FILE", 1, "logical-or",
				{ "UNKNOWN FILE", 1, "logical-or",
					{ "UNKNOWN FILE", 1, "num", 1 },
					{ "UNKNOWN FILE", 1, "num", 2 } },
				{ "UNKNOWN FILE", 1, "num", 3 } },
		}
		
		assert.are.same(expect, got)
		
		-- 1 && 2 || 3
		
		got = parser.parse_text("1 && 2 || 3;")
		expect = {
			{ "UNKNOWN FILE", 1, "logical-or",
				{ "UNKNOWN FILE", 1, "logical-and",
					{ "UNKNOWN FILE", 1, "num", 1 },
					{ "UNKNOWN FILE", 1, "num", 2 } },
				{ "UNKNOWN FILE", 1, "num", 3 } },
		}
		
		assert.are.same(expect, got)
		
		-- 1 || 2 && 3
		
		got = parser.parse_text("1 || 2 && 3;")
		expect = {
			{ "UNKNOWN FILE", 1, "logical-or",
				{ "UNKNOWN FILE", 1, "num", 1 },
				{ "UNKNOWN FILE", 1, "logical-and",
					{ "UNKNOWN FILE", 1, "num", 2 },
					{ "UNKNOWN FILE", 1, "num", 3 } } },
		}
		
		assert.are.same(expect, got)
		
		-- 1 && (2 || 3)
		
		got = parser.parse_text("1 && (2 || 3);")
		expect = {
			{ "UNKNOWN FILE", 1, "logical-and",
				{ "UNKNOWN FILE", 1, "num", 1 },
				{ "UNKNOWN FILE", 1, "logical-or",
					{ "UNKNOWN FILE", 1, "num", 2 },
					{ "UNKNOWN FILE", 1, "num", 3 } } },
		}
		
		assert.are.same(expect, got)
		
		-- (1 || 2) && 3
		
		got = parser.parse_text("(1 || 2) && 3;")
		expect = {
			{ "UNKNOWN FILE", 1, "logical-and",
				{ "UNKNOWN FILE", 1, "logical-or",
					{ "UNKNOWN FILE", 1, "num", 1 },
					{ "UNKNOWN FILE", 1, "num", 2 } },
				{ "UNKNOWN FILE", 1, "num", 3 } },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses ! operator", function()
		local got
		local expect
		
		got = parser.parse_text("!x;")
		expect = {
			{ "UNKNOWN FILE", 1, "logical-not",
				{ "UNKNOWN FILE", 1, "ref", { "x" } } },
		}
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("!(x);")
		expect = {
			{ "UNKNOWN FILE", 1, "logical-not",
				{ "UNKNOWN FILE", 1, "ref", { "x" } } },
		}
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("!!x;")
		expect = {
			{ "UNKNOWN FILE", 1, "logical-not",
				{ "UNKNOWN FILE", 1, "logical-not",
					{ "UNKNOWN FILE", 1, "ref", { "x" } } } },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses assignment operator", function()
		local got
		local expect
		
		-- a = b = 1
		
		got = parser.parse_text("a = b = 1;")
		expect = {
			{ "UNKNOWN FILE", 1, "assign",
				{ "UNKNOWN FILE", 1, "ref", { "a" } },
				{ "UNKNOWN FILE", 1, "assign",
					{ "UNKNOWN FILE", 1, "ref", { "b" } },
					{ "UNKNOWN FILE", 1, "num", 1 } } },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses += operator", function()
		local got
		local expect
		
		got = parser.parse_text("a += b;")
		expect = {
			{ "UNKNOWN FILE", 1, "assign",
				{ "UNKNOWN FILE", 1, "ref", { "a" } },
				{ "UNKNOWN FILE", 1, "add",
					{ "UNKNOWN FILE", 1, "ref", { "a" } },
					{ "UNKNOWN FILE", 1, "ref", { "b" } } } },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses -= operator", function()
		local got
		local expect
		
		got = parser.parse_text("a -= 10;")
		expect = {
			{ "UNKNOWN FILE", 1, "assign",
				{ "UNKNOWN FILE", 1, "ref", { "a" } },
				{ "UNKNOWN FILE", 1, "subtract",
					{ "UNKNOWN FILE", 1, "ref", { "a" } },
					{ "UNKNOWN FILE", 1, "num", 10 } } },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses *= operator", function()
		local got
		local expect
		
		got = parser.parse_text("a.b[0] *= (10);")
		expect = {
			{ "UNKNOWN FILE", 1, "assign",
				{ "UNKNOWN FILE", 1, "ref", { "a", "b", { "UNKNOWN FILE", 1, "num", 0 } } },
				{ "UNKNOWN FILE", 1, "multiply",
					{ "UNKNOWN FILE", 1, "ref", { "a", "b", { "UNKNOWN FILE", 1, "num", 0 } } },
					{ "UNKNOWN FILE", 1, "num", 10 } } },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses <<= operator", function()
		local got
		local expect
		
		got = parser.parse_text("a <<= 4;")
		expect = {
			{ "UNKNOWN FILE", 1, "assign",
				{ "UNKNOWN FILE", 1, "ref", { "a" } },
				{ "UNKNOWN FILE", 1, "left-shift",
					{ "UNKNOWN FILE", 1, "ref", { "a" } },
					{ "UNKNOWN FILE", 1, "num", 4 } } },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses enum definition", function()
		local got
		local expect
		
		got = parser.parse_text("enum myenum { FOO, BAR, BAZ };")
		expect = {
			{ "UNKNOWN FILE", 1, "enum", "int", "myenum", {
				{ "FOO" },
				{ "BAR" },
				{ "BAZ" },
			}, nil },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses enum definition with data type", function()
		local got
		local expect
		
		got = parser.parse_text("enum <short> myenum { FOO, BAR, BAZ };")
		expect = {
			{ "UNKNOWN FILE", 1, "enum", "short", "myenum", {
				{ "FOO" },
				{ "BAR" },
				{ "BAZ" },
			}, nil },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses enum definition with typedef", function()
		local got
		local expect
		
		got = parser.parse_text("typedef enum myenum { FOO, BAR, BAZ } myenum_t;")
		expect = {
			{ "UNKNOWN FILE", 1, "enum", "int", "myenum", {
				{ "FOO" },
				{ "BAR" },
				{ "BAZ" },
			}, "myenum_t" },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses anonymous enum definition with typedef", function()
		local got
		local expect
		
		got = parser.parse_text("typedef enum { FOO, BAR, BAZ } myenum_t;")
		expect = {
			{ "UNKNOWN FILE", 1, "enum", "int", nil, {
				{ "FOO" },
				{ "BAR" },
				{ "BAZ" },
			}, "myenum_t" },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses enum definition with explicit values", function()
		local got
		local expect
		
		got = parser.parse_text("enum myenum { FOO = 1, BAR = 2, BAZ };")
		expect = {
			{ "UNKNOWN FILE", 1, "enum", "int", "myenum", {
				{ "FOO", { "UNKNOWN FILE", 1, "num", 1 } },
				{ "BAR", { "UNKNOWN FILE", 1, "num", 2 } },
				{ "BAZ" },
			}, nil },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses for loop", function()
		local got
		local expect
		
		got = parser.parse_text("for(;;) {}")
		expect = {
			{ "UNKNOWN FILE", 1, "for", nil, nil, nil, {} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses for loop with init expression", function()
		local got
		local expect
		
		got = parser.parse_text("for(i = 0 ;;) {}")
		expect = {
			{ "UNKNOWN FILE", 1, "for",
				{ "UNKNOWN FILE", 1, "assign", { "UNKNOWN FILE", 1, "ref", { "i" } }, { "UNKNOWN FILE", 1, "num", 0 } },
				nil, nil, {} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses for loop with condition", function()
		local got
		local expect
		
		got = parser.parse_text("for(; i < 10;) {}")
		expect = {
			{ "UNKNOWN FILE", 1, "for",
				nil,
				{ "UNKNOWN FILE", 1, "less-than", { "UNKNOWN FILE", 1, "ref", { "i" } }, { "UNKNOWN FILE", 1, "num", 10 } },
				nil, {} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses for loop with iteration expression", function()
		local got
		local expect
		
		got = parser.parse_text("for(;; do_thing()) {}")
		expect = {
			{ "UNKNOWN FILE", 1, "for",
				nil, nil,
				{ "UNKNOWN FILE", 1, "call", "do_thing", {} },
				{} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses for loop with multiple statements in block", function()
		local got
		local expect
		
		got = parser.parse_text("for(;;) {\nthing1();\nthing2();\n}\nthing_not_in_loop();")
		expect = {
			{ "UNKNOWN FILE", 1, "for",
				nil, nil, nil,
				{
					{ "UNKNOWN FILE", 2, "call", "thing1", {} },
					{ "UNKNOWN FILE", 3, "call", "thing2", {} },
				} },
			{ "UNKNOWN FILE", 5, "call", "thing_not_in_loop", {} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses for loop with a statement not in a block", function()
		local got
		local expect
		
		got = parser.parse_text("for(;;) thing_in_loop();\nthing_not_in_loop();\n}")
		expect = {
			{ "UNKNOWN FILE", 1, "for",
				nil, nil, nil,
				{
					{ "UNKNOWN FILE", 1, "call", "thing_in_loop", {} },
				} },
			{ "UNKNOWN FILE", 2, "call", "thing_not_in_loop", {} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("errors on for loop with no trailing statements", function()
		assert.has_error(
			function()
				parser.parse_text("for(;;)")
			end, "Parse error at UNKNOWN FILE:1 (at 'for(;;)')")
	end)
	
	it("parses for loop with a trailing semicolon", function()
		local got
		local expect
		
		got = parser.parse_text("for(;;);\nthing_not_in_loop();\n}")
		expect = {
			{ "UNKNOWN FILE", 1, "for", nil, nil, nil, {} },
			{ "UNKNOWN FILE", 2, "call", "thing_not_in_loop", {} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses for loop local variable definition in initialiser", function()
		local got
		local expect
		
		got = parser.parse_text("for(local int x = 0;;) {}")
		expect = {
			{ "UNKNOWN FILE", 1, "for",
				{ "UNKNOWN FILE", 1, "local-variable", "int", "x", nil, nil, { "UNKNOWN FILE", 1, "num", 0 } },
				nil, nil, {} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("errors on for loop with no non-local variable definition ini initialiser", function()
		assert.has_error(
			function()
				parser.parse_text("for(int x;;)")
			end, "Parse error at UNKNOWN FILE:1 (at 'for(int x;;')")
	end)
	
	it("parses while loop", function()
		local got
		local expect
		
		got = parser.parse_text("while(i < 10) {}")
		expect = {
			{ "UNKNOWN FILE", 1, "for",
				nil,
				{ "UNKNOWN FILE", 1, "less-than", { "UNKNOWN FILE", 1, "ref", { "i" } }, { "UNKNOWN FILE", 1, "num", 10 } },
				nil, {} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses while loop with multiple statements in block", function()
		local got
		local expect
		
		got = parser.parse_text("while(1) {\nthing1();\nthing2();\n}\nthing_not_in_loop();")
		expect = {
			{ "UNKNOWN FILE", 1, "for",
				nil, { "UNKNOWN FILE", 1, "num", 1 }, nil,
				{
					{ "UNKNOWN FILE", 2, "call", "thing1", {} },
					{ "UNKNOWN FILE", 3, "call", "thing2", {} },
				} },
			{ "UNKNOWN FILE", 5, "call", "thing_not_in_loop", {} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses while loop with a statement not in a block", function()
		local got
		local expect
		
		got = parser.parse_text("while(1) thing_in_loop();\nthing_not_in_loop();\n}")
		expect = {
			{ "UNKNOWN FILE", 1, "for",
				nil, { "UNKNOWN FILE", 1, "num", 1 }, nil,
				{
					{ "UNKNOWN FILE", 1, "call", "thing_in_loop", {} },
				} },
			{ "UNKNOWN FILE", 2, "call", "thing_not_in_loop", {} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("errors on while loop with no trailing statements", function()
		assert.has_error(
			function()
				parser.parse_text("while(1)")
			end, "Parse error at UNKNOWN FILE:1 (at 'while(1)')")
	end)
	
	it("parses while loop with a trailing semicolon", function()
		local got
		local expect
		
		got = parser.parse_text("while(1);\nthing_not_in_loop();\n}")
		expect = {
			{ "UNKNOWN FILE", 1, "for", nil, { "UNKNOWN FILE", 1, "num", 1 }, nil, {} },
			{ "UNKNOWN FILE", 2, "call", "thing_not_in_loop", {} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses an if statement with an empty block", function()
		local got
		local expect
		
		got = parser.parse_text("if(1) {}")
		expect = {
			{ "UNKNOWN FILE", 1, "if",
				{ { "UNKNOWN FILE", 1, "num", 1 }, {} },
			},
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses an if statement with a single statement", function()
		local got
		local expect
		
		got = parser.parse_text("if(1) sometimes_thing(); always_thing();")
		expect = {
			{ "UNKNOWN FILE", 1, "if",
				{ { "UNKNOWN FILE", 1, "num", 1 }, {
					{ "UNKNOWN FILE", 1, "call", "sometimes_thing", {} }, } },
			},
			
			{ "UNKNOWN FILE", 1, "call", "always_thing", {} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses an if statement with a multiple statements", function()
		local got
		local expect
		
		got = parser.parse_text("if(1) { sometimes_thing(); other_thing(); } always_thing();")
		expect = {
			{ "UNKNOWN FILE", 1, "if",
				{ { "UNKNOWN FILE", 1, "num", 1 }, {
					{ "UNKNOWN FILE", 1, "call", "sometimes_thing", {} },
					{ "UNKNOWN FILE", 1, "call", "other_thing", {} } } },
			},
			
			{ "UNKNOWN FILE", 1, "call", "always_thing", {} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses an if statement with a trailing semicolon", function()
		local got
		local expect
		
		got = parser.parse_text("if(1); always_thing();")
		expect = {
			{ "UNKNOWN FILE", 1, "if",
				{ { "UNKNOWN FILE", 1, "num", 1 }, {} },
			},
			
			{ "UNKNOWN FILE", 1, "call", "always_thing", {} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("errors on an if with no trailing statements", function()
		assert.has_error(
			function()
				parser.parse_text("if(1)")
			end, "Parse error at UNKNOWN FILE:1 (at 'if(1)')")
	end)
	
	it("parses an if/else statement with a single statement", function()
		local got
		local expect
		
		got = parser.parse_text("if(1) sometimes_thing(); else alternate_thing(); always_thing();")
		expect = {
			{ "UNKNOWN FILE", 1, "if",
				{ { "UNKNOWN FILE", 1, "num", 1 }, {
					{ "UNKNOWN FILE", 1, "call", "sometimes_thing", {} }, } },
				{ {
					{ "UNKNOWN FILE", 1, "call", "alternate_thing", {} }, } },
			},
			
			{ "UNKNOWN FILE", 1, "call", "always_thing", {} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses an if/else statement with multiple statements", function()
		local got
		local expect
		
		got = parser.parse_text("if(1) { sometimes_thing(); other_thing(); } else { alternate_thing(); other_alternate_thing(); } always_thing();")
		expect = {
			{ "UNKNOWN FILE", 1, "if",
				{ { "UNKNOWN FILE", 1, "num", 1 }, {
					{ "UNKNOWN FILE", 1, "call", "sometimes_thing", {} },
					{ "UNKNOWN FILE", 1, "call", "other_thing", {} } } },
				{ {
					{ "UNKNOWN FILE", 1, "call", "alternate_thing", {} },
					{ "UNKNOWN FILE", 1, "call", "other_alternate_thing", {} } } },
			},
			
			{ "UNKNOWN FILE", 1, "call", "always_thing", {} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses an if/else statement with a trailing semicolon", function()
		local got
		local expect
		
		got = parser.parse_text("if(1); else; always_thing();")
		expect = {
			{ "UNKNOWN FILE", 1, "if",
				{ { "UNKNOWN FILE", 1, "num", 1 }, {} },
				{ {} },
			},
			
			{ "UNKNOWN FILE", 1, "call", "always_thing", {} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("errors on an if/else with no trailing statements", function()
		assert.has_error(
			function()
				parser.parse_text("if(1) do_thing(); else")
			end, "Parse error at UNKNOWN FILE:1 (at 'else')")
	end)
	
	it("parses an if/else if statement with a single statement", function()
		local got
		local expect
		
		got = parser.parse_text("if(1) one_thing(); else if(2) two_thing(); always_thing();")
		expect = {
			{ "UNKNOWN FILE", 1, "if",
				{ { "UNKNOWN FILE", 1, "num", 1 }, {
					{ "UNKNOWN FILE", 1, "call", "one_thing", {} }, } },
				{ { "UNKNOWN FILE", 1, "num", 2 }, {
					{ "UNKNOWN FILE", 1, "call", "two_thing", {} }, } },
			},
			
			{ "UNKNOWN FILE", 1, "call", "always_thing", {} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses an if/else if statement with multiple statements", function()
		local got
		local expect
		
		got = parser.parse_text("if(1) { one_thing(); one_thing(); } else if(2) { two_thing(); two_thing(); } always_thing();")
		expect = {
			{ "UNKNOWN FILE", 1, "if",
				{ { "UNKNOWN FILE", 1, "num", 1 }, {
					{ "UNKNOWN FILE", 1, "call", "one_thing", {} },
					{ "UNKNOWN FILE", 1, "call", "one_thing", {} } } },
				{ { "UNKNOWN FILE", 1, "num", 2 }, {
					{ "UNKNOWN FILE", 1, "call", "two_thing", {} },
					{ "UNKNOWN FILE", 1, "call", "two_thing", {} } } },
			},
			
			{ "UNKNOWN FILE", 1, "call", "always_thing", {} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("errors on an if/else if with no trailing statements", function()
		assert.has_error(
			function()
				parser.parse_text("if(1) do_thing(); else if(2)")
			end, "Parse error at UNKNOWN FILE:1 (at 'else if(2)')")
	end)
	
	it("parses an if/else if/else if/else structure", function()
		local got
		local expect
		
		got = parser.parse_text("if(1) one_thing(); else if(2) two_thing(); else if(3) three_thing(); else alternate_thing(); always_thing();")
		expect = {
			{ "UNKNOWN FILE", 1, "if",
				{ { "UNKNOWN FILE", 1, "num", 1 }, {
					{ "UNKNOWN FILE", 1, "call", "one_thing", {} } } },
				{ { "UNKNOWN FILE", 1, "num", 2 }, {
					{ "UNKNOWN FILE", 1, "call", "two_thing", {} } } },
				{ { "UNKNOWN FILE", 1, "num", 3 }, {
					{ "UNKNOWN FILE", 1, "call", "three_thing", {} } } },
				{ {
					{ "UNKNOWN FILE", 1, "call", "alternate_thing", {} } } },
			},
			
			{ "UNKNOWN FILE", 1, "call", "always_thing", {} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses nested ifs", function()
		local got
		local expect
		
		got = parser.parse_text("if(1) if(2) two_thing(); else if(3) three_thing(); else alternate_thing(); always_thing();")
		expect = {
			{ "UNKNOWN FILE", 1, "if",
				{ { "UNKNOWN FILE", 1, "num", 1 }, {
					{ "UNKNOWN FILE", 1, "if",
						{ { "UNKNOWN FILE", 1, "num", 2 }, {
							{ "UNKNOWN FILE", 1, "call", "two_thing", {} } } },
						{ { "UNKNOWN FILE", 1, "num", 3 }, {
							{ "UNKNOWN FILE", 1, "call", "three_thing", {} } } },
						{ {
							{ "UNKNOWN FILE", 1, "call", "alternate_thing", {} } } },
					},
				} },
			},
			
			{ "UNKNOWN FILE", 1, "call", "always_thing", {} },
		}
		
		assert.are.same(expect[1][4][2][1][4], got[1][4][2][1][4])
	end)
	
	it("errors else if with no preceeding if", function()
		assert.has_error(
			function()
				parser.parse_text("else if(1) do_thing(); if(2);")
			end, "Parse error at UNKNOWN FILE:1 (at 'else if(1) ')")
	end)
	
	it("errors else with no preceeding if", function()
		assert.has_error(
			function()
				parser.parse_text("else do_thing(); if(2);")
			end, "Parse error at UNKNOWN FILE:1 (at 'else do_thi')")
	end)
	
	it("parses a struct definition with variable definition", function()
		local got = parser.parse_text("struct mystruct {\nint x;\nint y;\n} myvar;")
		
		local expect = {
			{ "UNKNOWN FILE", 1, "struct", "mystruct", {},
			{
				{ "UNKNOWN FILE", 2, "variable", "int", "x", nil, nil },
				{ "UNKNOWN FILE", 3, "variable", "int", "y", nil, nil },
			}, nil, { "myvar", {}, nil } },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses an anonymous struct definition with variable definition", function()
		local got = parser.parse_text("struct {\nint x;\nint y;\n} myvar;")
		
		local expect = {
			{ "UNKNOWN FILE", 1, "struct", nil, {},
			{
				{ "UNKNOWN FILE", 2, "variable", "int", "x", nil, nil },
				{ "UNKNOWN FILE", 3, "variable", "int", "y", nil, nil },
			}, nil, { "myvar", {}, nil } },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses a struct definition with array variable definition", function()
		local got = parser.parse_text("struct mystruct {\nint x;\nint y;\n} myvar[10];")
		
		local expect = {
			{ "UNKNOWN FILE", 1, "struct", "mystruct", {},
			{
				{ "UNKNOWN FILE", 2, "variable", "int", "x", nil, nil },
				{ "UNKNOWN FILE", 3, "variable", "int", "y", nil, nil },
			}, nil, { "myvar", {}, { "UNKNOWN FILE", 4, "num", 10 } } },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses a struct definition with variable definition using parameters", function()
		local got = parser.parse_text("struct mystruct(int a, int b) {\nint x;\nint y;\n} myvar(1234, 5678);")
		
		local expect = {
			{ "UNKNOWN FILE", 1, "struct", "mystruct", { { "int", "a" }, { "int", "b" } },
			{
				{ "UNKNOWN FILE", 2, "variable", "int", "x", nil, nil },
				{ "UNKNOWN FILE", 3, "variable", "int", "y", nil, nil },
			}, nil, { "myvar", { { "UNKNOWN FILE", 4, "num", 1234 }, { "UNKNOWN FILE", 4, "num", 5678 } }, nil } },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses an anonymous struct definition with variable definition using parameters", function()
		local got = parser.parse_text("struct(int a, int b) {\nint x;\nint y;\n} myvar(1234, 5678);")
		
		local expect = {
			{ "UNKNOWN FILE", 1, "struct", nil, { { "int", "a" }, { "int", "b" } },
			{
				{ "UNKNOWN FILE", 2, "variable", "int", "x", nil, nil },
				{ "UNKNOWN FILE", 3, "variable", "int", "y", nil, nil },
			}, nil, { "myvar", { { "UNKNOWN FILE", 4, "num", 1234 }, { "UNKNOWN FILE", 4, "num", 5678 } }, nil } },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses a switch statement", function()
		local got = parser.parse_text(
			"switch(x) {\n" ..
			"	case 1:\n" ..
			"	case 2:\n" ..
			"		foo();\n" ..
			"		break;\n" ..
			"	default:\n" ..
			"		bar();\n" ..
			"	case 3:\n" ..
			"		baz();\n" ..
			"}")
		
		local expect = {
			{ "UNKNOWN FILE", 1, "switch", { "UNKNOWN FILE", 1, "ref", { "x" } }, {
				{ { "UNKNOWN FILE", 2, "num", 1 }, {} },
				{ { "UNKNOWN FILE", 3, "num", 2 }, {
					{ "UNKNOWN FILE", 4, "call", "foo", {} },
					{ "UNKNOWN FILE", 5, "break" },
				} },
				
				{ nil, {
					{ "UNKNOWN FILE", 7, "call", "bar", {} },
				} },
				
				{ { "UNKNOWN FILE", 8, "num", 3 }, {
					{ "UNKNOWN FILE", 9, "call", "baz", {} },
				} },
			} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses casts", function()
		local got
		local expect
		
		got = parser.parse_text("(int)x;")
		
		expect = {
			{ "UNKNOWN FILE", 1, "cast", "int",
				{ "UNKNOWN FILE", 1, "ref", { "x" } } }
		}
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("(int)(x);")
		
		expect = {
			{ "UNKNOWN FILE", 1, "cast", "int",
				{ "UNKNOWN FILE", 1, "ref", { "x" } } }
		}
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("(int)func(x);")
		
		expect = {
			{ "UNKNOWN FILE", 1, "cast", "int",
				{ "UNKNOWN FILE", 1, "call", "func", {
					{ "UNKNOWN FILE", 1, "ref", { "x" } } } } }
		}
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("(unsigned char)(int)func(x);")
		
		expect = {
			{ "UNKNOWN FILE", 1, "cast", "unsigned char",
				{ "UNKNOWN FILE", 1, "cast", "int",
					{ "UNKNOWN FILE", 1, "call", "func", {
						{ "UNKNOWN FILE", 1, "ref", { "x" } } } } } }
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses return statements", function()
		local got
		local expect
		
		got = parser.parse_text("return;")
		expect = {
			{ "UNKNOWN FILE", 1, "return", nil },
		}
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("return 1;")
		expect = {
			{ "UNKNOWN FILE", 1, "return", { "UNKNOWN FILE", 1, "num", 1 } },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses empty blocks", function()
		local got
		local expect
		
		got = parser.parse_text("{}")
		expect = {
			{ "UNKNOWN FILE", 1, "block", {} },
		}
		
		assert.are.same(expect, got)
		
		got = parser.parse_text(" { } ")
		expect = {
			{ "UNKNOWN FILE", 1, "block", {} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses nested blocks", function()
		local got
		local expect
		
		got = parser.parse_text("{ {} }")
		expect = {
			{ "UNKNOWN FILE", 1, "block", {
				{ "UNKNOWN FILE", 1, "block", {} },
			} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses blocks", function()
		local got
		local expect
		
		got = parser.parse_text("{ foo(); bar(); {baz();} qux(); }")
		expect = {
			{ "UNKNOWN FILE", 1, "block", {
				{ "UNKNOWN FILE", 1, "call", "foo", {} },
				{ "UNKNOWN FILE", 1, "call", "bar", {} },
				{ "UNKNOWN FILE", 1, "block", {
					{ "UNKNOWN FILE", 1, "call", "baz", {} },
				} },
				{ "UNKNOWN FILE", 1, "call", "qux", {} },
			} },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses unary minus as an operand to another operator", function()
		local got
		local expect
		
		got = parser.parse_text("-1;")
		expect = {
			{ "UNKNOWN FILE", 1, "minus",
				{ "UNKNOWN FILE", 1, "num", 1 } },
		}
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("i - 1;")
		expect = {
			{ "UNKNOWN FILE", 1, "subtract",
				{ "UNKNOWN FILE", 1, "ref", { "i" } },
				{ "UNKNOWN FILE", 1, "num", 1 } },
		}
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("i-1;")
		expect = {
			{ "UNKNOWN FILE", 1, "subtract",
				{ "UNKNOWN FILE", 1, "ref", { "i" } },
				{ "UNKNOWN FILE", 1, "num", 1 } },
		}
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("i - -1;")
		expect = {
			{ "UNKNOWN FILE", 1, "subtract",
				{ "UNKNOWN FILE", 1, "ref", { "i" } },
				{ "UNKNOWN FILE", 1, "minus",
					{ "UNKNOWN FILE", 1, "num", 1 } } },
		}
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("i - -j;")
		expect = {
			{ "UNKNOWN FILE", 1, "subtract",
				{ "UNKNOWN FILE", 1, "ref", { "i" } },
				{ "UNKNOWN FILE", 1, "minus",
					{ "UNKNOWN FILE", 1, "ref", { "j" } } } },
		}
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("!-1;")
		expect = {
			{ "UNKNOWN FILE", 1, "logical-not",
				{ "UNKNOWN FILE", 1, "minus",
					{ "UNKNOWN FILE", 1, "num", 1 } } },
		}
		
		assert.are.same(expect, got)
	end)
	
	it("parses unary minus as an operand to another operator", function()
		local got
		local expect
		
		got = parser.parse_text("+1;")
		expect = {
			{ "UNKNOWN FILE", 1, "plus",
				{ "UNKNOWN FILE", 1, "num", 1 } },
		}
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("i + 1;")
		expect = {
			{ "UNKNOWN FILE", 1, "add",
				{ "UNKNOWN FILE", 1, "ref", { "i" } },
				{ "UNKNOWN FILE", 1, "num", 1 } },
		}
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("i+1;")
		expect = {
			{ "UNKNOWN FILE", 1, "add",
				{ "UNKNOWN FILE", 1, "ref", { "i" } },
				{ "UNKNOWN FILE", 1, "num", 1 } },
		}
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("i - +1;")
		expect = {
			{ "UNKNOWN FILE", 1, "subtract",
				{ "UNKNOWN FILE", 1, "ref", { "i" } },
				{ "UNKNOWN FILE", 1, "plus",
					{ "UNKNOWN FILE", 1, "num", 1 } } },
		}
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("i - +j;")
		expect = {
			{ "UNKNOWN FILE", 1, "subtract",
				{ "UNKNOWN FILE", 1, "ref", { "i" } },
				{ "UNKNOWN FILE", 1, "plus",
					{ "UNKNOWN FILE", 1, "ref", { "j" } } } },
		}
		
		assert.are.same(expect, got)
		
		got = parser.parse_text("!+1;")
		expect = {
			{ "UNKNOWN FILE", 1, "logical-not",
				{ "UNKNOWN FILE", 1, "plus",
					{ "UNKNOWN FILE", 1, "num", 1 } } },
		}
		
		assert.are.same(expect, got)
	end)
end);
