# 附录：运算符

来源：从权威 PDF 中定位表格标题并截取表体文本，并尽量结构化为 Markdown 表格。

## Table 4-1: PowerBuilder arithmetic operators

PDF 页：96

| Operator Meaning | Example |
| --- | --- |
| + Addition | Total=SubTotal+Tax |
| - Subtraction | Price=Price–Discount |
| * Multiplication | Total=Quantity*Price |
| / Division | Factor=Discount/Price |
| ^ Exponentiation | Rank=Rating^2.5 |

注：Unless you have prohibited the use of dashes in identifier names, you must surround the minus sign with spaces.

## Table 4-2: PowerBuilder relational and logical operators

PDF 页：98

| Operator Meaning | Example |
| --- | --- |
| = Equals | if Price=100 then Rate=.05 |
| > Greater than | if Price>100 then Rate=.05 |
| < Less than | if Price<100 then Rate=.05 |
| <> Not equal | if Price<>100 then Rate=.05 |
| >= Greater than or equal | if Price>=100 then Rate=.05 |
| <= Less than or equal | if Price<=100 then Rate=.05 |
| NOT Logical negation | if NOT Price=100 then Rate=.05 |
| AND Logical and | if Tax>3 AND Ship <5 then |
| OR Logical or | if Tax>3 OR Ship<5 then Rate=.05 |

注：Rate=.05

## Table 4-4: Order of precedence of operators

PDF 页：100

| Operator | Purpose |
| --- | --- |
| ( ) | Grouping (see note below on overriding) |
| + , - | Unary plus and unary minus (indicates positive or negative |
| ^ | Exponentiation |
| * , / | Multiplication and division |
| + , - | Addition and subtraction; string concatenation |
| NOT | Negation |
| AND | Logical and |
| OR | Logical or |
| How to override | To override the order, enclose expressions in parentheses. This identifies the |
| For example, in the expression | (x+(y*(a+b))) , a+b is evaluated first. The |
| sum of a and b is then multiplied by | y , and this product is added to x . |

注：number) = , > , < , <= , >= , <> Relational operators group and order in which PowerBuilder will evaluate the expressions. When there are nested groups, the groups are evaluated from the inside out.
