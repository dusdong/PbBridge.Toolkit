# 附录：声明速查

来源：从权威 PDF 中定位表格标题并截取表体文本，并尽量结构化为 Markdown 表格。

## Table 3-2: Variable declaration parameters

PDF 页：63

| Parameter | Description |
| --- | --- |
| access | (For instance variables only) Keywords specifying the access |
| (optional) | for the variable. For information, see “Access for instance |
| datatype | The datatype of the variable. You can specify a standard |
| { size } | (For blobs only) A number, enclosed in braces, specifying the |
| (optional) | size in bytes of the blob . If { size } is omitted, the blob has an |
| PowerBuilder truncates the | blob data. |

注：variables” on page 43. datatype, a system object, or a previously defined structure. For blobs and decimals , you can specify the size or precision of the data by including an optional value in brackets. initial size of zero and PowerBuilder adjusts its size each time it is used at runtime. If you enter a size that exceeds the declared length in a script,

## Table 3-4: Instance variable declaration parameters for access rights

PDF 页：69

| Parameter | Description |
| --- | --- |
| access-right | A keyword specifying where the variable’s name will be |
| (optional) | recognized. Values are: |
| readaccess | A keyword restricting the ability of scripts to read the variable’s |
| (optional) | value. Values are: |
| • PROTECTEDREAD | – Only scripts for the object and its |
| PRIVATEREAD . You cannot specify a modifier for | PRIVATE |

注：• PUBLIC – (Default) Any script in the application can refer to the variable. In another object’s script, you use dot notation to qualify the variable name and identify the object it belongs to. • PROTECTED – Scripts for the object for which the variable is declared and its descendants can refer to the variable. • PRIVATE – Scripts for the object for which the variable is declared can refer to the variable. You cannot refer to the variable in descendants of the object. descendants can read the variable. • PRIVATEREAD – Only scripts for the object can read the variable. When access-right is PUBLIC , you can specify either keyword. When access-right is PROTECTED , you can specify only access, because PRIVATE is already fully restricted. If readaccess is omitted, any script can read the variable.

## Table 3-5: Constant variable declaration parameters

PDF 页：73

| Parameter | Description |
| --- | --- |
| CONSTANT | Declares a constant instead of a variable. The CONSTANT |
| keyword can be before or after the | access keywords. |
| access | (For instance variables only) Keywords specifying the access |
| (optional) | for the constant. For information, see “Access for instance |
| datatype | A standard datatype for the constant. For decimals, you can |
| constname | The name of the constant (must be a valid PowerScript |
| value | A literal or expression of the appropriate datatype that will be |

注：variables” on page 43. include an optional value in brackets to specify the precision of the data. Blobs cannot be constants. For information about PowerBuilder datatypes, see “Standard datatypes” on page 21. identifier, as described in “Identifier names” on page 5). the value of the constant. The value is required. For information, see “Initial values for variables” on page 40.

## Table 3-6: Array variable declaration parameters

PDF 页：74

| Parameter | Description |
| --- | --- |
| access | (For instance variables only) Keywords specifying the access |
| (optional) | for the variable. For information, see “Access for instance |
| datatype | The datatype of the variable. You can specify a standard |
| including an optional value in brackets after | datatype (see |
| If you specify a size after | datatype , it is ignored. |
| variablename | The name of the variable (name must be a valid PowerScript |

注：variables” on page 43. datatype, a system object, or a previously defined structure. For decimals, you can specify the precision of the data by “Syntax of a variable declaration” on page 37): decimal {2} variablename [ ] For blobs, fixed-length blobs within an array are not supported. identifier, as described in “Identifier names” on page 5). You can define additional arrays with the same datatype by naming additional variable names with brackets and optional value lists, separated by commas.
