# 附录：表格全集

来源：从权威 PDF 中定位表格标题并截取表体文本，并尽量结构化为 Markdown 表格。

可结构化为 Markdown 表格：46

表格总数（基线识别）：46；成功抽取：46；失败：0

## Table 1-1: Methods for adding comments in scripts

PDF 页：30

| Method Marker Can use to | Note |
| --- | --- |
| Double // Designate all text on the line to | Cannot extend to |
| slash | the right of the marker as a multiple lines |
| Slash and /*...*/ Designate the text between the | • Can extend over |
| asterisk | markers as a comment multiple lines |
| PowerBuilder Users Guide | . |

注：comment (multiline Nest comments comments do not require a continuation character) • Can be nested Adding comment markers In Script views and the Function painter, you can use the Comment Selection button (or select Edit>Comment Selection from the menu bar) to comment out the line containing the cursor or a selected group of lines. For information about adding comments to objects and library entries, see the

## Table 1-2: Using special ASCII characters in strings

PDF 页：33

| In this To specify | Enter |
| --- | --- |
| category this | this More information |
| Common Newline | ~n |
| Tab | ~t |
| Vertical tab | ~v |
| Carriage return | ~r |
| Form feed | ~f |
| Backspace | ~b |
| Double quote | ~ " |
| Single quote | ~ ' |
| Tilde | ~~ |
| Any Decimal | ~### ### = a 3-digit number from 000 to 255 |
| Hexadecimal | ~h## ## = a 2-digit hexadecimal number from |
| Octal | ~o### ### = a 3-digit octal number from 000 to |

注：ASCII characters ASCII character 01 to FF 377

## Table 1-3: PowerScript reserved words

PDF 页：36

| alias | execute | not | step |
| --- | --- | --- | --- |
| and | exit | of | subroutine |
| autoinstantiate | external | on | super |
| call | false | open* | system |
| case | fetch | or | systemread |
| catch | finally | parent | systemwrite |
| choose | first | post* | then |
| close * | for | prepare | this |
| commit | forward | prior | throw |
| connect | from | private | throws |
| constant | function | privateread | to |
| continue | global | privatewrite | trigger |
| create * goto | procedure | true |  |
| cursor | halt | protected | try |
| declare | if | protectedread | type |
| delete | immediate | protectedwrite | until |
| describe * indirect | prototypes | update* |  |
| descriptor | insert | public | updateblob |
| destroy | into | readonly | using |
| disconnect | intrinsic | ref | variables |
| do | is | return | while |
| dynamic | last | rollback | with |
| else | library | rpcfunc | within |
| elseif | loop | select | xor |
| end | namespace | selectblob | _debug |
| enumerated | native | shared |  |
| event | next | static |  |
| reserved words is available on the | Sun Microsystems Web site. at |  |  |
| http://docs.sun.com/source/816-6410-10/keywords.htm | . |  |  |

注：The PowerBuilder system class also includes private variables that you cannot use as identifiers. If you use a private variable as an identifier, you get an informational message and should rename your identifier. If you are deploying a DataWindow® to the Web, you cannot use JavaScript reserved words to name fields or bands in the DataWindow object. The list of

## Table 1-4: PowerScript pronouns

PDF 页：37

| Control in a custom user | Custom user object containing the |
| --- | --- |
| object | control |
| Menu | Item in the menu on the level |
| Super | Descendent object or control Parent |
| Descendent window or user | Immediate ancestor of the window |
| object | or user object |
| Control in a descendent | Immediate ancestor of the |
| window or user object | control’s parent window or user |
| ParentWindow property | You can use the ParentWindow property of the |
| see the PowerBuilder | Users Guide . |

注：This pronoun In a script for a Refers to the This Window, custom user object, Object or control itself menu, application object, or control Parent Control in a window Window containing the control above the current menu object Menu object like a pronoun in Menu scripts. It identifies the window that the menu is associated with when your program is running. For more information, The rest of this section describes the individual pronouns in detail.

## Table 1-5: Predefined symbols for conditional compilation

PDF 页：44

| symbols | Target type | Code in this processing block |
| --- | --- | --- |
| PBNATIVE | Standard PowerBuilder | Fully parsed for the standard |
| client-server or | application and converted to blank |  |
| distributed applications | lines for .NET targets. |  |
| PBWEBFORM | .NET Web Forms | Fully parsed for .NET Web Forms |
| applications | targets and converted to blank lines |  |
| PBWINFORM | .NET Windows Forms | Fully parsed for .NET Windows |
| applications | Forms targets and converted to |  |

注：Predefined for all other targets. blank lines for all other targets.

## Table 1-6: Types of error messages returned by the preprocessor

PDF 页：46

| Error message | Description |
| --- | --- |
| Invalid if statement | #if statement without a defined symbol, with an |
| incorrectly defined symbol, or without a | then |
| #end if directive expected | #if statement without an #end if statement |
| Unexpected preprocessor | Caused by an #else , #elseif , or #end if statement |
| directive | when not preceded by an #if statement |
| Preprocessor syntax error | Caused by including text after an #else or #end if |
| comment characters ( | // ) |

注：clause statement when the text is not preceded by

## Table 2-1: PowerBuilder datatypes in EAServer

PDF 页：57

| EAServer Manager | CORBA IDL | PowerBuilder |
| --- | --- | --- |
| Integer (16-bit) | Short | Integer |
| Integer (32-bit) | Long | Long |
| Integer (64-bit) | Long long | LongLong |
| Boolean | Boolean | Boolean |
| Float | Float | Real |
| Double | Double | Double |
| String | String | String |
| Binary | BCD::Binary | Blob |
| Decimal | BCD::Decimal | Decimal |
| Money | BCD::Money | Decimal |
| Date | MJD::Date | Date |
| Time | MJD::Time | Time |
| Timestamp | MJD::Timestamp | DateTime |
| ResultSet | TabularResults::ResultSet | ResultSet |
| ResultSets | TabularResults::ResultSets | ResultSets |
| Void | Void | None |

## Table 3-1: PowerScript variable scopes

PDF 页：60

| Global, instance, and | Global, instance, and shared variables can be defined in the Script view of the |
| --- | --- |
| Local declarations | You declare local variables for an object or control in the script for that object |
| Declaring SQL | You can also declare SQL cursors that are global, shared, instance, or local. |

注：Scope Description Global Accessible anywhere in the application. It is independent of any object definition. Instance Belongs to an object and is associated with an instance of that object (you can think of it as a property of the object). Instance variables have access keywords that determine whether scripts of other objects can access them. They can belong to the application object, a window, a user object, or a menu. Shared Belongs to an object definition and exists across all instances of the object. Shared variables retain their value when an object is closed and opened again. Shared variables are always private. They are accessible only in scripts for the object and for controls associated with the object. They can belong to the application object, a window, a user object, or a menu. Local A temporary variable that is accessible only in the script in which you define it. When the script has finished executing, the variable constant ceases to exist. shared declarations Application, Window, User Object, or Menu painters. Global variables can also be defined in the Function painter: 1 Select Declare from the first drop-down list in the Script view. 2 Select the type of variable you want to declare in the second drop-down list of the Script view. 3 Type the declaration in the scripting area of the Script view. or control. cursors Open a specific script or select a variable declaration scope in the Script view and type the DECLARE SQL statement or select Paste SQL from the PainterBar or pop-up menu.

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

## Table 3-3: Default initial values for variables

PDF 页：66

| For this variable datatype | PowerBuilder sets this default value |
| --- | --- |
| Blob | A blob of 0 length; an empty blob |
| Char (or character ) | ASCII value 0 |
| Boolean | false |
| Date | 1900-01-01 (January 1, 1900) |
| DateTime | 1900-01-01 00:00:00 |
| String | Empty string ("") |
| Time | 00:00:00 (midnight) |
| Specifying a literal as | To initialize a variable when you declare it, place an equal sign (=) and a literal |
| This example declares | li_count as an integer whose value is 5: |
| This example declares | li_a and li_b as integers and initializes li_a to 5 and li_b |

注：Numeric ( byte , integer , long , longlong , 0 decimal , real , double , UnsignedInteger , and UnsignedLong ) a initial value appropriate for that variable datatype after the variable. For information about literals for specific datatypes, see “Standard datatypes” on page 21. Do not use a function’s return value You should not initialize a variable by assigning it the return value of a global user defined function, because it might not compile correctly, or because it could lead to confusion about the value assigned. For example, do not use: integer i = f_return_one() Although you can use global system functions or expressions to initialize variables with compile time values in a variable declaration statement, for runtime value assignments, you must also declare variables and assign their values in separate statements. integer li_count=5 to 10: integer li_a=5, li_b=10

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

## Table 3-7: External function or subroutine declaration parameters

PDF 页：84

| Parameter | Description |
| --- | --- |
| access | (Local external functions only) Public , Protected , or Private |
| (optional) | specifies the access level of a local external function. The |

注：default is Public . For more information, see the section about specifying access of local functions in "Usage" next.

## Table 3-8: Access levels for local external functions

PDF 页：86

| Access level | Where you can use the local external function |
| --- | --- |
| Public | Any script in the application. |
| Private | Scripts for events in the object for which the function is |
| Protected | Scripts for the object for which the function is declared and its |
| Availability of the | To be available to a PowerBuilder application running on any Windows |
| If you are deploying a PowerBuilder custom class user object as an | EAServer |
| LD_LIBRARY_PATH | on Solaris) or the library must be in the lib directory |

注：declared. You cannot use the function in descendants of the object. descendants. Use of the access keyword with local external functions works the same as the access-right keywords for instance variables. dynamic library at platform, the DLL must be in one of the following directories: runtime • The current directory • The Windows directory • The Windows System subdirectory • Directories on the DOS path component, you must make sure any dynamic library it references is available on the server. If you do not specify the location of the library when you declare it, make sure it is installed in an accessible location: • On a Windows server, the DLL must be in the application path of the server’s executable file. • On a UNIX server, the location of the shared library must be listed in the server’s library path environment variable (for example, of the EAServer installation.

## Table 3-9: PowerBuilder datatypes for pointers

PDF 页：88

| Datatype in source | PowerBuilder |
| --- | --- |
| code | Size, sign, precision datatype |
| * (any pointer) | 32-bit pointer Long |
| char * | Array of bytes of variable length Blob |
| Windows 32-bit FAR pointers, such as | LPBYTE , LPDWORD , LPINT , LPLONG , |
| LPVOID , and LPWORD, are declared in PowerBuilder as | long datatypes. |
| Near-pointer datatypes (such as | PSTR and NPSTR ) are not supported in |

注：HANDLE is defined as 32 bits unsigned and is declared in PowerBuilder as an UnsignedLong . PowerBuilder.

## Table 3-10: PowerBuilder datatypes for characters and strings

PDF 页：89

| code | Size, sign, precision | datatype |
| --- | --- | --- |
| char | 8 bits, signed | Char |
| string | 32-bit pointer to a null-terminated | String |
| The Windows 32-bit FAR pointer | LPSTR is declared in PowerBuilder as string. |  |
| Fixed-point values | Table 3-11: PowerBuilder datatypes for fixed-point values |  |
| Datatype in source | PowerBuilder |  |
| code | Size, sign, precision | datatype |
| byte | 8 bits, unsigned | Byte |
| short | 16 bits, signed | Integer |
| unsigned short | 16 bits, unsigned | UnsignedInteger |
| int | 32 bits, signed | Long |
| unsigned int | 32 bits, unsigned | UnsignedLong |
| long | 32 bits, signed | Long |
| unsigned long | 32 bits, unsigned | UnsignedLong |
| longlong | 64 bits, signed | LongLong |
| The Windows definition | WORD is declared in PowerBuilder as |  |
| UnsignedInteger | and the Windows definition | DWORD is declared as an |
| arguments of type | short . |  |
| Floating-point values | Table 3-12: PowerBuilder datatypes for floating-point values |  |
| Datatype in source | PowerBuilder |  |
| code | Size, sign, precision | datatype |
| float | 32 bits, single precision | Real |
| double | 64 bits, double precision | Double |
| PowerBuilder does not support 80-bit | doubles on Windows. |  |

注：strings Datatype in source PowerBuilder array of bytes of variable length Reference arguments When you pass a string to an external function by reference, all memory management is done in PowerBuilder. The string variable must be long enough to hold the returned value. To ensure that this is true, first declare the string variable, and then use the Space function to fill the variable with blanks equal to the maximum number of characters that you expect the function to return. UnsignedLong . You cannot call external functions with return values or

## Table 3-11: PowerBuilder datatypes for fixed-point values

PDF 页：89

| code | Size, sign, precision | datatype |
| --- | --- | --- |
| byte | 8 bits, unsigned | Byte |
| short | 16 bits, signed | Integer |
| unsigned short | 16 bits, unsigned | UnsignedInteger |
| int | 32 bits, signed | Long |
| unsigned int | 32 bits, unsigned | UnsignedLong |
| long | 32 bits, signed | Long |
| unsigned long | 32 bits, unsigned | UnsignedLong |
| longlong | 64 bits, signed | LongLong |
| The Windows definition | WORD is declared in PowerBuilder as |  |
| UnsignedInteger | and the Windows definition | DWORD is declared as an |
| arguments of type | short . |  |
| Floating-point values | Table 3-12: PowerBuilder datatypes for floating-point values |  |
| Datatype in source | PowerBuilder |  |
| code | Size, sign, precision | datatype |
| float | 32 bits, single precision | Real |
| double | 64 bits, double precision | Double |
| PowerBuilder does not support 80-bit | doubles on Windows. |  |

注：Datatype in source PowerBuilder UnsignedLong . You cannot call external functions with return values or

## Table 3-12: PowerBuilder datatypes for floating-point values

PDF 页：89

| code | Size, sign, precision | datatype |
| --- | --- | --- |
| float | 32 bits, single precision | Real |
| double | 64 bits, double precision | Double |
| PowerBuilder does not support 80-bit | doubles on Windows. |  |

注：Datatype in source PowerBuilder

## Table 3-13: RPC declaration parameters

PDF 页：91

| Argument | Description |
| --- | --- |
| SUBROUTINE | way return values are handled. If there is a return value, declare |
| it as a FUNCTION . If it returns nothing or returns | VOID , specify |
| rtndatatype | In a FUNCTION declaration, the datatype of the value returned |
| functionname | The name of the database procedure as you will call it in |
| PowerBuilder. If the name in the DBMS is different, use | ALIAS |

注：FUNCTION or A keyword specifying the type of call, which determines the SUBROUTINE . by the function. FOR to associate the DBMS name with the PowerBuilder name.

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

## Table 4-3: PowerBuilder concatenation operator

PDF 页：99

| Operator Meaning | Example |
| --- | --- |
| + Concatenate | "cat " + "dog" |

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

## Table 4-5: Datatypes of literal operands in an expression

PDF 页：102

| Literal | Datatype |
| --- | --- |
| Integer literals (no decimal point or exponent) within the | Long |
| Integer literals beyond the range of | Long and within the UnsignedLong |
| Integer literals beyond the range of | UnsignedLong and LongLong |
| within the range of | LongLong |
| Numeric literals with a decimal point (but no exponent) | Decimal |
| Numeric literals with a decimal point and explicit | Double |
| Integer literals beyond the range of | LongLong cause compiler errors. |

注：range of Long range of UnsignedLong exponent Out of range

## Table 5-1: Visual user object types

PDF 页：108

| Visual user objects | Description |
| --- | --- |
| Standard | Inherited from a specific visual control. You can set |
| Custom | Inherited from the UserObject system class. You can |
| External | A user object that displays a visual control defined in a |
| Class user objects | Class user objects consist of properties, functions, and sometimes events. They |
| Class user objects | Description |
| Standard | Inherits its definition from a nonvisual PowerBuilder |
| Custom | An object of your own design for which you define |

注：properties and write scripts so that the control is ready for use. It has the same events and properties as the control it is inherited from plus any that you add. include many controls in the user object and write scripts for their events. Each control in the user object has the same events and properties as the controls from which they are inherited plus any that you add. DLL. The control is not part of the PowerBuilder object hierarchy. The DLL developer provides information for setting style bits that control its presentation. Its events, functions, and properties are specified by the developer of the DLL. An external user object is not the same as an OCX, which you can put in an OLE control. have no visual component. There are two types—standard and custom. Table 5-2: Class user object types object, such as the Transaction or Error object. You can add instance variables and functions. A few nonvisual objects have events—to write scripts for these events, you have to define a class user object. instance variables, events, and functions in order to encapsulate application-specific programming in an object. For information on defining and using user objects, see the PowerBuilder Users Guide .

## Table 5-2: Class user object types

PDF 页：108

| Class user objects | Description |
| --- | --- |
| Standard | Inherits its definition from a nonvisual PowerBuilder |
| Custom | An object of your own design for which you define |

注：object, such as the Transaction or Error object. You can add instance variables and functions. A few nonvisual objects have events—to write scripts for these events, you have to define a class user object. instance variables, events, and functions in order to encapsulate application-specific programming in an object. For information on defining and using user objects, see the PowerBuilder Users Guide .

## Table 6-1: Types of functions and events

PDF 页：118

| Category Item | Definition |
| --- | --- |
| Events Event | An action in an object or control that can start the |
| User event | An event you define to add functionality to an |
| events, see the PowerBuilder | Users Guide. |
| System or | An event that is part of an object’s PowerBuilder |
| built-in event | definition. System events are usually triggered by |
| event’s script. System events either return a | long or |
| Functions Function | A program or routine that performs specific |
| System function | A built-in PowerScript function that is not |
| Object function | A function that is part of an object’s definition. |
| User-defined | A function you define. You define global functions |
| function | in the Function painter and object functions in |
| Local external | An external function that belongs to an object. You |
| function | declare it in the Window or User Object painter. Its |
| Global external | An external function that you declare in any |
| function | painter, making it globally accessible. Its |
| Remote | A stored procedure in a database that you can call |
| procedure call | from a script. The declaration for an RPC can be |
| (RPC) | global or local (belonging to an object). The |

注：execution of a script. A user can initiate an event by an action such as clicking an object or entering data, or a statement in another script can initiate the event. object. You specify the arguments, return value, and whether the event is mapped to a system message. For information about defining user user actions or system messages. PowerBuilder passes a predefined set of arguments for use in the do not have a return value. processing. associated with an object. PowerBuilder has many predefined object functions and you can define your own. other painters with Script views. Global function A function you define that can be called from any script. PowerScript’s system functions are globally accessible, but they have a different place in the search order. definition is in another library. definition is in another library. definition for the procedure is in the database.

## Table 6-2: How PowerBuilder calls functions and events

PDF 页：124

| functions | function must exist when are called directly. They are not |
| --- | --- |
| the script is compiled. | polymorphic, and no |
| Object functions with | Strongly typed. The The functions are polymorphic. |
| the script is compiled. | compile, but if another class is |
| Object functions with | Weakly typed. The The functions are polymorphic. |
| exist when the script is | determined at execution time. |
| Specifying static or | For object functions and events, you can choose when PowerBuilder looks for |
| lookup using the | STATIC or DYNAMIC keywords. The DYNAMIC keyword |
| Results of static calls | Static calls do not guarantee that the function or event identified at compile |

注：Type of function Compiler typing Comments Global and system Strongly typed. The These functions must exist and substitution is ever made at execution time. STATIC lookup function must exist when They must exist when you instantiated at execution time, its function is called instead. DYNAMIC lookup function does not have to The actual function called is compiled. dynamic lookup them by specifying static or dynamic lookup. You specify static or dynamic applies only to functions that are associated with an object. You cannot call global or system functions dynamically. Static calls By default, PowerBuilder makes static lookups for functions and events. This means that it identifies the function or event by matching the name and argument types when it compiles the code. A matching function or event must exist in the object at compile time. time is the one that is executed. Suppose that you define a variable of an ancestor type and it has a particular function definition. If you assign an instance of a descendent object to the variable and the descendant has a function that overrides the ancestor’s function (the one found at compile time), the function in the descendant is executed.

## Table 6-3: Dynamic function calling errors

PDF 页：127

| not found. | error 65. |
| --- | --- |
| The function is | The code is looking Execution error 63: Statements 2 and |
| found and | for a return value. Function/event with 3 cause error 63. |
| executed but is | no return value used |
| not defined with | in expression. |
| Events | Consider these statements: |
| 2 This example looks for an | integer return value: |

注：Condition 1 Condition 2 Result Example The function None. Execution error 65: All the does not exist. Dynamic function statements cause a return value. 1 This statement calls an event without looking for a return value: object.EVENT DYNAMIC eventname( ) int li_int li_int = object.EVENT DYNAMIC eventname( )

## Table 6-4: Dynamic event calling errors

PDF 页：128

| value. | cause an error. |
| --- | --- |
| for a return value. | datatype is returned. null in statement |
| If the expected | The assignment |
| execution error 19 | execution error |
| occurs: Cannot | 19 in statement |
| The event is | The event has a A null of the defined If eventname is |
| found but is not | defined return datatype is returned. defined to return |
| implemented | value. integer, li_int is |
| (there is no | set to null in |
| script). | statement 2. |
| have a defined | datatype is returned. null in statement |
| return value. | 3. |
| If the expected | The assignment |
| execution error 19 | execution error |
| occurs: Cannot | 19 in statement |
| The event is | The code is looking Execution error 63: Statements 2 and |
| found and | for a return value. Function/event with 3 cause error 63. |
| executed but is | no return value used |
| not defined with | in expression. |

注：Condition 1 Condition 2 Result Example The event does The code is not Nothing; the call fails Statement 1 fails not exist. looking for a return silently. but does not The code is looking A null of the Any La_any is set to 3. datatype is not Any , to li_int causes convert Any in Any 2. variable to datatype. The event does not A null of the Any La_any is set to datatype is not Any , to li_int causes convert Any in Any 2. variable to datatype. a return value.

## Table 6-5: Passing arguments to functions and events

PDF 页：132

| Method of passing | Description |
| --- | --- |
| By value | A copy of the variable is available in the function or event |
| By reference | A pointer to the variable is passed to the function or event |
| Read-only | The variable is available in the function or event. Its value |
| performance advantage are | string , blob , date , time , and |

注：script. Any changes to its value affect the copy only. The original variable in the calling script is not affected. script. Changes affect the original variable in the calling script. is treated as a constant—changes to the variable are not allowed and cause a compiler error. Read-only provides a performance advantage for some datatypes because it does not create a copy of the data, as with by value. Datatypes for which read-only provides a DateTime . For other datatypes, read-only provides documentation for other developers by indicating something about the purpose of the argument.

## Table 6-6: Arguments for calling functions and events

PDF 页：137

| Argument | Description |
| --- | --- |
| objectname | The name of the object where the function or event is defined |
| (optional) | followed by a period or the descendant of that object/the name of |
| For system or global functions, omit | objectname. |
| type | A keyword specifying whether you are calling a function or event. |
| (optional) | Values are: |
| calltype | A keyword specifying when PowerBuilder looks for the function or |
| (optional) | event. Values are: |
| when | A keyword specifying whether the function or event should execute |
| (optional) | immediately or after the current script is finished. Values are: |
| name | The name of the function or event you want to call. |
| argumentlist | The values you want to pass to name . Each value in the list must |
| (optional) | have a datatype that corresponds to the declared datatype in the |

注：the ancestor class followed by two colons. If a function name is not qualified, PowerBuilder uses the rules for finding functions and executes the first matching function it finds. For the rules PowerBuilder uses to find unqualified function names, see “Finding and executing functions and events” on page 94. • FUNCTION (Default) • EVENT • STATIC (Default) • DYNAMIC For more information about static versus dynamic calls, see “Static versus dynamic calls” on page 98. For more information on dynamic calls, see “Dynamic calls” on page 99. • TRIGGER – (Default) Execute it immediately. • POST – Put it in the object’s queue and execute it in its turn, after other pending messages have been handled. For more about triggering and posting, see “Triggering versus posting functions and events” on page 96. function or event definition or declaration.

## Table 6-7: Arguments for calling ancestor functions and events

PDF 页：140

| Argument | Description |
| --- | --- |
| objectname | The name of the object whose ancestor contains the function you |
| (optional) | want to execute. |
| ancestorclass | The name of the ancestor class whose function or event you want to |
| execute. The pronoun | Super provides the appropriate reference |
| type | A keyword specifying whether you are calling a function or event. |
| (optional) | Values are: |

注：when ancestorobject is the immediate ancestor of the current object. • (Default) FUNCTION • EVENT

## Table 7-1: Shortcuts for assigning values

PDF 页：147

| Assignment | Example | Equivalent to |
| --- | --- | --- |
| ++ | i ++ | i = i + 1 |
| -- | i -- | i = i - 1 |
| += | i += 3 | i = i + 3 |
| -= | i -= 3 | i = i -3 |
| *= | i *= 3 | i = i * 3 |
| /= | i /= 3 | i = i / 3 |
| ^= | i ^=3 | i = i ^ 3 |

注：Unless you have prohibited the use of dashes in variable names, you must leave a space before -- and -=. If you do not, PowerScript reads the minus sign as part of a variable name. For more information, see “Identifier names” on page 5.

## Table 9-1: PowerBuilder event types

PDF 页：209

| Type | Occurs in response to |
| --- | --- |
| System events with an ID | User actions or other system messages or a call |
| System events without an ID | PowerBuilder messages or a call in your scripts |
| User-defined events with an | User actions or other system messages or a call |
| ID | in your scripts |
| User-defined events without | A call in your scripts |
| Event IDs | An event ID connects an event to a system message. Events that can be |

注：in your scripts an ID The following information about event IDs, arguments, and return values applies to all types of events. triggered by user actions or other system activity have event IDs. In PowerBuilder’s objects, PowerBuilder defines events for commonly used event IDs. These events are documented in this chapter. You can define your own events for other system messages using the event IDs listed in the Event Declaration dialog box.

## Table 10-1: Message object properties where return values are stored

PDF 页：425

| Return value datatype | Message object property |
| --- | --- |
| Numeric | Message.DoubleParm |
| PowerObject (such as a structure) | Message.PowerObjectParm |
| String | Message.StringParm |
| CloseWithReturn | to return a reference to a control on the closed window |
| script for the CloseQuery event. Use a | RETURN statement. |

注：Returning several values as a structure To return several values, create a user-defined structure to hold the values and access the PowerObjectParm property of the Message object in the script that opened the response window. The structure is passed by value so you can access the information even if the original variable has been destroyed. Referencing controls User objects and controls are passed by reference, not by value. You cannot use (because the control no longer exists after the window is closed). Instead, return the value of one or more properties of that control. Preventing a window from closing You can prevent a window from being closed with a return code of 1 in the

## Table 10-2: FileReadEx and FileWriteEx datatype support by mode

PDF 页：514

| Mode | Blob | String |
| --- | --- | --- |
| Line | Not supported | Supported |
| Stream | Supported | Not supported |
| Text | Supported | Supported |
| When a file has been opened in line mode, each call to the | FileReadEx function |  |
| mark (EOF). Each call to | FileWriteEx adds a CR and LF at the end of each string |  |
| When a file has been opened in stream mode or text mode, | FileReadEx reads |  |
| in an optional parameter. | FileWriteEx writes the full contents of the string or |  |

注：reads until it encounters a carriage return (CR), linefeed (LF), or end-of-file it writes. the whole file until it encounters an EOF or until it reaches a length specified blob or until it reaches a length specified in an optional parameter. The optional length parameter applies only to blob data. If the length parameter is provided when the datatype of the second parameter is string, the code will not compile.

## Table 10-3: Valid values for the navigationcode argument of FindItem

PDF 页：538

| Navigationcode value | What FindItem finds |
| --- | --- |
| RootTreeItem! | The first item at level 1. Returns -1 if no items have been |
| NextTreeItem! | The sibling after itemhandle . A sibling is an item at the |
| PreviousTreeItem! | The sibling before itemhandle . Returns -1 if there are no |
| ParentTreeItem! | The parent of itemhandle . Returns -1 if the item is at |

注：inserted into the control. same level with the same parent. Returns -1 if there are no more siblings. more siblings. level 1.

## Table 10-4: Option values for GetFileOpenName and GetFileSaveName

PDF 页：602

| Index Constant name | Description |
| --- | --- |
| 1 OFN_CREATEPROMPT | If the specified file does not exist, prompt for permission to create |
| 2 OFN_EXPLORER | Use an Explorer-style dialog box. |
| 3 OFN_EXTENSIONDIFFERENT | The file extension entered differed from the extensions specified |
| 4 OFN_FILEMUSTEXIST | Only the names of existing files can be entered. |
| 5 OFN_HIDEREADONLY | Hide the Read Only check box. |
| 6 OFN_LONGNAMES | Use long file names. Ignored for Explorer-style dialog boxes. |
| 7 OFN_NOCHANGEDIR | Restore the current directory to its original value if the user |
| effect for GetFileOpenName | on Windows NT, 2000, and XP. |

注：the file. If the user chooses to create the file, the dialog box closes; otherwise the dialog box remains open. in extension. changed the directory while searching for files. This option has no

## Table 10-5: KeyCode values for keyboard keys

PDF 页：738

| Type of key | KeyCode values and descriptions |
| --- | --- |
| Mouse buttons | KeyLeftButton! Left mouse button |
| KeyMiddleButton! | Middle mouse button |
| KeyRightButton! | Right mouse button |
| Letters | KeyA! - KeyZ! A - Z, uppercase or lowercase |
| Other symbols | KeyQuote! ' and " |
| KeyBackQuote! | ` and ~ |
| KeyLeftBracket! | [ and { |
| KeyBackSlash! | \ and \| |
| KeyRightBracket! | ] and } |
| KeySemiColon! | ; and : |
| Non-printing | KeyBack! Backspace |
| characters | KeyTab! |
| Function keys | KeyF1! - KeyF12! Function keys F1 to F12 |
| Control keys | KeyShift! |
| Navigation keys | KeyPageUp! |

注：KeyEqual! = and + KeyComma! , and < KeyDash! - and _ KeyPeriod! . and > KeySlash! / and ? KeyEnter! KeySpaceBar! KeyControl! KeyAlt! KeyPause! KeyCapsLock! KeyEscape! KeyPrintScreen! KeyInsert! KeyDelete! KeyPageDown! KeyEnd! KeyHome! KeyLeftArrow! KeyUpArrow! KeyRightArrow! KeyDownArrow!

## Table 10-6: Metacharacters used by Match function

PDF 页：795

| Metacharacter | Meaning | Example |
| --- | --- | --- |
| Caret (^) | Matches the beginning of | ^C matches C at the beginning of |
| a string | a string. |  |
| Dollar sign ($) | Matches the end of a | s$ matches s at the end of a |
| string | string. |  |
| Period (.) | Matches any character | . . . matches three consecutive |
| Backslash (\) | Removes the following | \$ matches $. |

注：characters. metacharacter’s special characteristics so that it matches itself

## Table 10-7: Unary operators used as metacharacters by Match function

PDF 页：796

| occurrences | As, A, AA, AAA, and so on) |
| --- | --- |
| + (plus) | Indicates one or more A+ matches one A or more than |
| occurrences | one A (A, AAA, and so on) |
| ? (question mark) | Indicates zero or one A? matches an empty string ("") |
| occurrence | or A |
| Sample patterns | The following table shows various text patterns and sample |
| This pattern | Matches |
| AB | Any string that contains AB; for example, ABA, DEABC, |
| B* | Any string that contains 0 or more Bs; for example, AC, B, |
| AB*C | Any string containing the pattern AC or ABC or ABBC, and |
| AB+C | Any string containing the pattern ABC or ABBC or ABBBC, |
| ABB*C | Any string containing the pattern ABC or ABBC or ABBBC, |
| ^AB | Any string starting with AB |
| AB?C | Any string containing the pattern AC or ABC (0 or 1 B) |
| ^[ABC] | Any string starting with A, B, or C |

注：Metacharacter Meaning Example * (asterisk) Indicates zero or more A* matches zero or more As (no text that matches each pattern: Table 10-8: Text pattern examples for Match function graphAB_one BB, BBB, ABBBC, and so on so on (0 or more Bs) and so on (1 or more Bs) and so on (1 B plus 0 or more Bs)

## Table 10-8: Text pattern examples for Match function

PDF 页：796

| This pattern | Matches |
| --- | --- |
| AB | Any string that contains AB; for example, ABA, DEABC, |
| B* | Any string that contains 0 or more Bs; for example, AC, B, |
| AB*C | Any string containing the pattern AC or ABC or ABBC, and |
| AB+C | Any string containing the pattern ABC or ABBC or ABBBC, |
| ABB*C | Any string containing the pattern ABC or ABBC or ABBBC, |
| ^AB | Any string starting with AB |
| AB?C | Any string containing the pattern AC or ABC (0 or 1 B) |
| ^[ABC] | Any string starting with A, B, or C |

注：graphAB_one BB, BBB, ABBBC, and so on so on (0 or more Bs) and so on (1 or more Bs) and so on (1 B plus 0 or more Bs)

## Table 10-9: Red, green, and blue color values for use with RGB

PDF 页：976

| Color | Red value | Green value | Blue value |
| --- | --- | --- | --- |
| Black | 0 | 0 | 0 |
| White | 255 | 255 | 255 |
| Light Gray | 192 | 192 | 192 |
| Dark Gray | 128 | 128 | 128 |
| Red | 255 | 0 | 0 |
| Dark Red | 128 | 0 | 0 |
| Green | 0 | 255 | 0 |
| Dark Green | 0 | 128 | 0 |
| Blue | 0 | 0 | 255 |
| Dark Blue | 0 | 0 | 128 |
| Magenta | 255 | 0 | 255 |
| Dark Magenta | 128 | 0 | 128 |
| Cyan | 0 | 255 | 255 |
| Dark Cyan | 0 | 128 | 128 |
| Yellow | 255 | 255 | 0 |
| Brown | 128 | 128 | 0 |

## Table 10-10: Events triggered by DDE requests and DDE functions

PDF 页：1160

| Client action | Event triggered | Functions available | Purpose of function |
| --- | --- | --- | --- |
| Sends a request for a hot | RemoteHotLinkStart | — | — |
| Sends a command to your | RemoteExec | GetCommandDDE | Obtain the command |
| GetCommandDDEOrigin | Find out what client |  |  |
| Sends data | RemoteSend | GetDataDDE | Obtain the data |
| GetDataDDEOrigin | Find out what client |  |  |
| Requests data from your | RemoteRequest | SetDataDDE | Send the requested data |
| RespondRemote | Acknowledge the request |  |  |
| Wants to terminate the hot | RemoteHotLinkStop | — | — |

注：available to each event link application application sent the command application sent the data server application link
